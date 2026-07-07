#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/msg.h>

#define MSG_KEY 7777

struct mensaje {
    long mtype;
    char texto[150];
};

const char *etiqueta(long tipo) {
    if (tipo == 1) return "INFO";
    if (tipo == 2) return "ADVERTENCIA";
    if (tipo == 3) return "CRITICO";
    return "DESCONOCIDO";
}

int main() {
    int id_cola = msgget(MSG_KEY, 0666 | IPC_CREAT);

    if (id_cola == -1) {
        perror("msgget");
        return 1;
    }

    struct mensaje msg;

    printf("=== Monitor de alertas RescueUSB SO ===\n");
    printf("Esperando mensajes de la cola IPC...\n");
    printf("Para cerrar: ./bin/enviar_alerta 1 SALIR\n\n");

    while (1) {
        if (msgrcv(id_cola, &msg, sizeof(msg.texto), 0, 0) == -1) {
            perror("msgrcv");
            return 1;
        }

        if (strncmp(msg.texto, "SALIR", 5) == 0) {
            printf("Monitor finalizado por mensaje SALIR.\n");
            break;
        }

        printf("[%s] %s\n", etiqueta(msg.mtype), msg.texto);
        fflush(stdout);
    }

    return 0;
}
