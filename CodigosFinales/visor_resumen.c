#include <stdio.h>
#include <stdlib.h>
#include <sys/ipc.h>
#include <sys/shm.h>

#define SHM_KEY 6060

struct resumen {
    int total;
    int libres;
    int ocupados;
    int danados;
    int eliminados;
    char fecha[80];
};

int main() {
    int id_shm = shmget(SHM_KEY, sizeof(struct resumen), 0666);

    if (id_shm == -1) {
        printf("ERROR: No existe resumen en memoria compartida.\n");
        printf("Primero ejecute la opcion de recuperacion concurrente.\n");
        return 1;
    }

    struct resumen *res = (struct resumen *)shmat(id_shm, NULL, 0);

    if (res == (void *)-1) {
        perror("shmat");
        return 1;
    }

    printf("=== Resumen leido desde memoria compartida ===\n");
    printf("Fecha del analisis: %s", res->fecha);
    printf("Total de bloques: %d\n", res->total);
    printf("Libres: %d\n", res->libres);
    printf("Ocupados: %d\n", res->ocupados);
    printf("Danados: %d\n", res->danados);
    printf("Eliminados: %d\n", res->eliminados);

    shmdt(res);

    return 0;
}
