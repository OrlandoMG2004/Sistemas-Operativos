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

int main(int argc, char *argv[]) {
    if (argc < 3) {
        printf("Uso: %s <tipo 1|2|3> <mensaje>\n", argv[0]);
        printf("Ejemplo: %s 2 \"Bloque sospechoso detectado\"\n", argv[0]);
        return 1;
    }

    char *fin;
    long tipo = strtol(argv[1], &fin, 10);

    if (*fin != '\0') {
        printf("ERROR: El tipo de alerta debe ser numerico.\n");
        return 1;
    }

    if (tipo < 1 || tipo > 3) {
        printf("ERROR: El tipo debe ser 1=INFO, 2=ADVERTENCIA o 3=CRITICO.\n");
        return 1;
    }

    int id_cola = msgget(MSG_KEY, 0666 | IPC_CREAT);

    if (id_cola == -1) {
        perror("msgget");
        return 1;
    }

    struct mensaje msg;
    msg.mtype = tipo;
    msg.texto[0] = '\0';

    for (int i = 2; i < argc; i++) {
        strncat(msg.texto, argv[i], sizeof(msg.texto) - strlen(msg.texto) - 1);

        if (i < argc - 1) {
            strncat(msg.texto, " ", sizeof(msg.texto) - strlen(msg.texto) - 1);
        }
    }

    if (strlen(msg.texto) == 0) {
        printf("ERROR: El mensaje no puede estar vacio.\n");
        return 1;
    }

    if (msgsnd(id_cola, &msg, sizeof(msg.texto), 0) == -1) {
        perror("msgsnd");
        return 1;
    }

    printf("Alerta enviada correctamente.\n");

    return 0;
}
