#!/bin/bash

# limpiar_ipc.sh - Limpia recursos IPC usados por RescueUSB SO.
# Cola de mensajes: clave 7777
# Memoria compartida: clave 6060

echo "Limpiando recursos IPC de RescueUSB SO..."

ipcrm -Q 7777 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Cola de mensajes eliminada."
else
    echo "No habia cola de mensajes activa o no se pudo eliminar."
fi

ipcrm -M 6060 2>/dev/null

if [ $? -eq 0 ]; then
    echo "Memoria compartida eliminada."
else
    echo "No habia memoria compartida activa o no se pudo eliminar."
fi

echo "Limpieza finalizada."
