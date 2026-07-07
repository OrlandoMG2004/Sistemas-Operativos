#!/bin/bash

# rescueusb.sh - Menu principal de RescueUSB SO
# Simulador forense de recuperacion de archivos en una USB danada.

EQUIPO="$1"
EQUIPO_REGEX='^LAB-[A-Z][0-9]{2}$'

mostrar_error() {
    echo "ERROR: $1"
}

pausa() {
    echo
    read -p "Presione ENTER para continuar..."
}

validar_equipo() {
    while [[ ! "$EQUIPO" =~ $EQUIPO_REGEX ]]; do
        echo "Codigo de equipo invalido o vacio."
        echo "Formato correcto: LAB-A01, LAB-B12, LAB-C05"
        read -p "Ingrese codigo de equipo: " EQUIPO
    done
}

validar_binario() {
    if [ ! -x "$1" ]; then
        mostrar_error "No existe $1 o no tiene permisos. Primero ejecute ./setup.sh"
        return 1
    fi
    return 0
}

ver_procesos() {
    echo "=== Procesos del usuario actual ==="
    ps -o pid,ppid,uid,gid,cmd -u "$USER" | head -12
    echo
    echo "=== Arbol de procesos desde esta terminal ==="

    if command -v pstree >/dev/null 2>&1; then
        pstree -p $$
    else
        echo "pstree no esta instalado. Mostrando informacion basica con ps:"
        ps -f --forest -p $$
    fi
}

generar_reporte_final() {
    mkdir -p reportes
    REPORTE="reportes/reporte_final_rescueusb.txt"

    echo "REPORTE FINAL - RescueUSB SO" > "$REPORTE"
    echo "Equipo: $EQUIPO" >> "$REPORTE"
    echo "Fecha: $(date)" >> "$REPORTE"
    echo "Usuario Linux: $USER" >> "$REPORTE"
    echo "Directorio: $(pwd)" >> "$REPORTE"
    echo "" >> "$REPORTE"

    echo "=== Estado FAT ===" >> "$REPORTE"

    if [ -f data/fat.txt ]; then
        cat data/fat.txt >> "$REPORTE"
    else
        echo "La USB simulada todavia no fue inicializada." >> "$REPORTE"
    fi

    echo "" >> "$REPORTE"
    echo "=== Procesos activos del usuario ===" >> "$REPORTE"
    ps -o pid,ppid,uid,gid,cmd -u "$USER" | head -15 >> "$REPORTE"

    echo "" >> "$REPORTE"
    echo "=== Recursos IPC activos ===" >> "$REPORTE"
    ipcs -q >> "$REPORTE" 2>/dev/null
    ipcs -m >> "$REPORTE" 2>/dev/null

    echo "Reporte generado en: $REPORTE"
}

mostrar_menu() {
    clear 2>/dev/null
    echo "======================================="
    echo "        RescueUSB SO - $EQUIPO"
    echo "======================================="
    echo "1. Inicializar USB simulada"
    echo "2. Registrar archivo en FAT"
    echo "3. Mostrar tabla FAT"
    echo "4. Simular dano de bloque"
    echo "5. Simular eliminacion de archivo"
    echo "6. Recuperar archivo"
    echo "7. Escanear USB con procesos"
    echo "8. Recuperacion concurrente con hilos"
    echo "9. Ver resumen en memoria compartida"
    echo "10. Ver procesos PID/PPID/pstree"
    echo "11. Abrir monitor de alertas IPC"
    echo "12. Enviar alerta manual"
    echo "13. Generar reporte final"
    echo "0. Salir"
    echo "======================================="
}

validar_equipo

while true; do
    mostrar_menu
    read -p "Seleccione una opcion: " opcion

    if [ -z "$opcion" ]; then
        mostrar_error "Debe ingresar una opcion."
        pausa
        continue
    fi

    if [[ ! "$opcion" =~ ^[0-9]+$ ]]; then
        mostrar_error "La opcion debe ser numerica."
        pausa
        continue
    fi

    case "$opcion" in
        1)
            ./fat_simulada.sh init
            ;;
        2)
            ./fat_simulada.sh registrar
            ;;
        3)
            ./fat_simulada.sh mostrar
            ;;
        4)
            ./fat_simulada.sh daniar
            ;;
        5)
            ./fat_simulada.sh eliminar
            ;;
        6)
            ./fat_simulada.sh recuperar
            ;;
        7)
            validar_binario "bin/scanner" && ./bin/scanner
            ;;
        8)
            validar_binario "bin/recuperador" && ./bin/recuperador
            ;;
        9)
            validar_binario "bin/visor_resumen" && ./bin/visor_resumen
            ;;
        10)
            ver_procesos
            ;;
        11)
            if validar_binario "bin/monitor_alertas"; then
                echo "El monitor quedara esperando mensajes."
                echo "Para cerrarlo desde otra terminal: ./bin/enviar_alerta 1 SALIR"
                ./bin/monitor_alertas
            fi
            ;;
        12)
            if validar_binario "bin/enviar_alerta"; then
                read -p "Tipo de alerta 1=INFO, 2=ADVERTENCIA, 3=CRITICO: " tipo
                read -p "Mensaje: " mensaje

                if [ -z "$tipo" ]; then
                    mostrar_error "Debe ingresar el tipo de alerta."
                elif [[ ! "$tipo" =~ ^[123]$ ]]; then
                    mostrar_error "El tipo debe ser 1, 2 o 3."
                elif [ -z "$mensaje" ]; then
                    mostrar_error "El mensaje no puede estar vacio."
                else
                    ./bin/enviar_alerta "$tipo" "$mensaje"
                fi
            fi
            ;;
        13)
            generar_reporte_final
            ;;
        0)
            echo "Saliendo de RescueUSB SO..."
            exit 0
            ;;
        *)
            mostrar_error "Opcion fuera de rango. Ingrese un numero del menu."
            ;;
    esac

    pausa
done
