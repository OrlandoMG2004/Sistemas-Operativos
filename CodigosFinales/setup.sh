#!/bin/bash

# setup.sh - Prepara RescueUSB SO
# Crea carpetas, da permisos y compila los programas en C.

mkdir -p data bloques reportes logs bin

chmod +x rescueusb.sh fat_simulada.sh limpiar_ipc.sh 2>/dev/null

echo "Compilando programas en C..."

compilar() {
    archivo="$1"
    salida="$2"
    extra="$3"

    if [ ! -f "$archivo" ]; then
        echo "ERROR: No existe el archivo $archivo"
        exit 1
    fi

    gcc "$archivo" -o "$salida" $extra

    if [ $? -ne 0 ]; then
        echo "ERROR: No se pudo compilar $archivo"
        exit 1
    fi
}

compilar scanner.c bin/scanner ""
compilar recuperador.c bin/recuperador "-pthread"
compilar monitor_alertas.c bin/monitor_alertas ""
compilar enviar_alerta.c bin/enviar_alerta ""
compilar visor_resumen.c bin/visor_resumen ""

echo "Proyecto preparado correctamente."
echo "Ejecuta: ./rescueusb.sh LAB-A01"
