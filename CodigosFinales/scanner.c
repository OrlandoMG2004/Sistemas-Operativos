#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/ipc.h>
#include <sys/msg.h>
#include <signal.h>
#include <string.h>

#define FAT_FILE "data/fat.txt"
#define MSG_KEY 7777
#define TOTAL_BLOQUES 30
#define HIJOS 3

struct mensaje {
    long mtype;
    char texto[150];
};

void enviar_alerta(long tipo, const char *texto) {
    int id_cola = msgget(MSG_KEY, 0666 | IPC_CREAT);
    if (id_cola == -1) return;

    struct mensaje msg;
    msg.mtype = tipo;
    snprintf(msg.texto, sizeof(msg.texto), "%s", texto);
    msgsnd(id_cola, &msg, sizeof(msg.texto), 0);
}

void manejar_senal(int sig) {
    printf("\nScanner recibio una senal de cancelacion. Terminando con seguridad...\n");
    enviar_alerta(2, "Scanner cancelado por senal externa");
    exit(0);
}

void analizar_rango(int inicio, int fin, int fd_pipe) {
    FILE *archivo = fopen(FAT_FILE, "r");

    if (archivo == NULL) {
        dprintf(fd_pipe, "ERROR: No se pudo abrir %s\n", FAT_FILE);
        exit(1);
    }

    char linea[220];
    int bloque;
    char estado[40], nombre[90], siguiente[40];

    while (fgets(linea, sizeof(linea), archivo) != NULL) {
        if (sscanf(linea, "%d|%39[^|]|%89[^|]|%39[^\n]", &bloque, estado, nombre, siguiente) == 4) {
            if (bloque >= inicio && bloque <= fin) {
                if (strcmp(estado, "DANADO") == 0) {
                    dprintf(fd_pipe, "[HIJO %d] Bloque %d DANADO asociado a %s\n", getpid(), bloque, nombre);
                    enviar_alerta(3, "Se detecto un bloque danado durante el escaneo");
                } else if (strcmp(estado, "ELIMINADO") == 0) {
                    dprintf(fd_pipe, "[HIJO %d] Bloque %d ELIMINADO asociado a %s\n", getpid(), bloque, nombre);
                    enviar_alerta(2, "Se detecto un bloque eliminado recuperable");
                } else if (strcmp(estado, "OCUPADO") == 0) {
                    dprintf(fd_pipe, "[HIJO %d] Bloque %d OK asociado a %s\n", getpid(), bloque, nombre);
                }
            }
        }
    }

    fclose(archivo);
    exit(0);
}

int main() {
    signal(SIGUSR1, manejar_senal);
    signal(SIGTERM, manejar_senal);

    if (access(FAT_FILE, F_OK) != 0) {
        printf("ERROR: Primero inicialice la USB simulada desde el menu.\n");
        return 1;
    }

    int tuberia[2];

    if (pipe(tuberia) == -1) {
        perror("pipe");
        return 1;
    }

    printf("=== Scanner forense RescueUSB SO ===\n");
    printf("PID padre: %d\n", getpid());
    printf("Se crearan %d procesos hijos para analizar bloques.\n\n", HIJOS);

    int rango = TOTAL_BLOQUES / HIJOS;

    for (int i = 0; i < HIJOS; i++) {
        int inicio = i * rango;
        int fin = (i == HIJOS - 1) ? TOTAL_BLOQUES - 1 : inicio + rango - 1;

        pid_t pid = fork();

        if (pid < 0) {
            perror("fork");
            return 1;
        }

        if (pid == 0) {
            close(tuberia[0]);
            analizar_rango(inicio, fin, tuberia[1]);
        } else {
            printf("Padre creo hijo PID=%d para analizar bloques %d a %d\n", pid, inicio, fin);
        }
    }

    close(tuberia[1]);

    char buffer[256];
    ssize_t leidos;

    printf("\n=== Resultados recibidos por pipe ===\n");

    while ((leidos = read(tuberia[0], buffer, sizeof(buffer) - 1)) > 0) {
        buffer[leidos] = '\0';
        printf("%s", buffer);
    }

    close(tuberia[0]);

    for (int i = 0; i < HIJOS; i++) {
        wait(NULL);
    }

    enviar_alerta(1, "Escaneo forense finalizado correctamente");

    printf("\nScanner finalizado. El padre espero a todos los hijos con wait().\n");

    return 0;
}
