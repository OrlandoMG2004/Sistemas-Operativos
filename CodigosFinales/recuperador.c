#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <sys/shm.h>
#include <time.h>

#define FAT_FILE "data/fat.txt"
#define REPORTE "reportes/reporte_threads.txt"
#define MSG_KEY 7777
#define SHM_KEY 6060
#define MAX_REGISTROS 200
#define NUM_HILOS 4

struct registro_fat {
    int bloque;
    char estado[40];
    char archivo[90];
    char siguiente[40];
};

struct mensaje {
    long mtype;
    char texto[150];
};

struct resumen {
    int total;
    int libres;
    int ocupados;
    int danados;
    int eliminados;
    char fecha[80];
};

struct tarea_hilo {
    int id;
    int inicio;
    int fin;
};

struct registro_fat registros[MAX_REGISTROS];

int total_registros = 0;
int total_libres = 0;
int total_ocupados = 0;
int total_danados = 0;
int total_eliminados = 0;

pthread_mutex_t mutex_contadores;

void enviar_alerta(long tipo, const char *texto) {
    int id_cola = msgget(MSG_KEY, 0666 | IPC_CREAT);
    if (id_cola == -1) return;

    struct mensaje msg;
    msg.mtype = tipo;
    snprintf(msg.texto, sizeof(msg.texto), "%s", texto);
    msgsnd(id_cola, &msg, sizeof(msg.texto), 0);
}

int cargar_fat() {
    FILE *archivo = fopen(FAT_FILE, "r");

    if (archivo == NULL) {
        printf("ERROR: No se pudo abrir %s. Inicialice la USB simulada.\n", FAT_FILE);
        return 0;
    }

    char linea[220];

    while (fgets(linea, sizeof(linea), archivo) != NULL && total_registros < MAX_REGISTROS) {
        if (sscanf(linea, "%d|%39[^|]|%89[^|]|%39[^\n]",
                   &registros[total_registros].bloque,
                   registros[total_registros].estado,
                   registros[total_registros].archivo,
                   registros[total_registros].siguiente) == 4) {
            total_registros++;
        }
    }

    fclose(archivo);

    if (total_registros == 0) {
        printf("ERROR: La tabla FAT esta vacia o tiene formato incorrecto.\n");
        return 0;
    }

    return 1;
}

void *analizar_bloques(void *arg) {
    struct tarea_hilo *tarea = (struct tarea_hilo *)arg;

    int libres = 0;
    int ocupados = 0;
    int danados = 0;
    int eliminados = 0;

    for (int i = tarea->inicio; i <= tarea->fin && i < total_registros; i++) {
        if (strcmp(registros[i].estado, "LIBRE") == 0) {
            libres++;
        } else if (strcmp(registros[i].estado, "OCUPADO") == 0) {
            ocupados++;
        } else if (strcmp(registros[i].estado, "DANADO") == 0) {
            danados++;
        } else if (strcmp(registros[i].estado, "ELIMINADO") == 0) {
            eliminados++;
        }
    }

    pthread_mutex_lock(&mutex_contadores);
    total_libres += libres;
    total_ocupados += ocupados;
    total_danados += danados;
    total_eliminados += eliminados;
    pthread_mutex_unlock(&mutex_contadores);

    printf("Hilo %d analizo registros %d a %d\n", tarea->id, tarea->inicio, tarea->fin);

    return NULL;
}

void guardar_memoria_compartida() {
    int id_shm = shmget(SHM_KEY, sizeof(struct resumen), 0666 | IPC_CREAT);

    if (id_shm == -1) {
        perror("shmget");
        return;
    }

    struct resumen *res = (struct resumen *)shmat(id_shm, NULL, 0);

    if (res == (void *)-1) {
        perror("shmat");
        return;
    }

    res->total = total_registros;
    res->libres = total_libres;
    res->ocupados = total_ocupados;
    res->danados = total_danados;
    res->eliminados = total_eliminados;

    time_t ahora = time(NULL);
    snprintf(res->fecha, sizeof(res->fecha), "%s", ctime(&ahora));

    shmdt(res);
}

void generar_reporte() {
    FILE *reporte = fopen(REPORTE, "w");

    if (reporte == NULL) {
        printf("ERROR: No se pudo crear el reporte. Verifique la carpeta reportes.\n");
        return;
    }

    fprintf(reporte, "REPORTE DE RECUPERACION CONCURRENTE\n");
    fprintf(reporte, "===================================\n");
    fprintf(reporte, "Total de bloques: %d\n", total_registros);
    fprintf(reporte, "Bloques libres: %d\n", total_libres);
    fprintf(reporte, "Bloques ocupados: %d\n", total_ocupados);
    fprintf(reporte, "Bloques danados: %d\n", total_danados);
    fprintf(reporte, "Bloques eliminados: %d\n", total_eliminados);

    fprintf(reporte, "\nDetalle de bloques problematicos:\n");

    for (int i = 0; i < total_registros; i++) {
        if (strcmp(registros[i].estado, "DANADO") == 0 || strcmp(registros[i].estado, "ELIMINADO") == 0) {
            fprintf(reporte, "Bloque %d | Estado: %s | Archivo: %s | Siguiente: %s\n",
                    registros[i].bloque,
                    registros[i].estado,
                    registros[i].archivo,
                    registros[i].siguiente);
        }
    }

    fclose(reporte);
}

int main() {
    if (!cargar_fat()) {
        return 1;
    }

    pthread_t hilos[NUM_HILOS];
    struct tarea_hilo tareas[NUM_HILOS];

    pthread_mutex_init(&mutex_contadores, NULL);

    int hilos_activos = total_registros < NUM_HILOS ? total_registros : NUM_HILOS;
    int tamano = (total_registros + hilos_activos - 1) / hilos_activos;

    printf("=== Recuperador concurrente RescueUSB SO ===\n");
    printf("Total de registros cargados: %d\n", total_registros);

    for (int i = 0; i < hilos_activos; i++) {
        tareas[i].id = i + 1;
        tareas[i].inicio = i * tamano;
        tareas[i].fin = tareas[i].inicio + tamano - 1;

        if (tareas[i].fin >= total_registros) {
            tareas[i].fin = total_registros - 1;
        }

        if (pthread_create(&hilos[i], NULL, analizar_bloques, &tareas[i]) != 0) {
            printf("ERROR: No se pudo crear el hilo %d\n", i + 1);
            return 1;
        }
    }

    for (int i = 0; i < hilos_activos; i++) {
        pthread_join(hilos[i], NULL);
    }

    pthread_mutex_destroy(&mutex_contadores);

    guardar_memoria_compartida();
    generar_reporte();

    if (total_danados > 0) {
        enviar_alerta(3, "Recuperador detecto bloques danados");
    } else if (total_eliminados > 0) {
        enviar_alerta(2, "Recuperador detecto archivos eliminados recuperables");
    } else {
        enviar_alerta(1, "Recuperacion concurrente sin danos criticos");
    }

    printf("\nResumen:\n");
    printf("Libres: %d | Ocupados: %d | Danados: %d | Eliminados: %d\n",
           total_libres,
           total_ocupados,
           total_danados,
           total_eliminados);

    printf("Reporte generado: %s\n", REPORTE);
    printf("Resumen guardado en memoria compartida.\n");

    return 0;
}
