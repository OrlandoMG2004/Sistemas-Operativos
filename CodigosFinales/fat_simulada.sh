#!/bin/bash

# fat_simulada.sh - Simulacion de una tabla FAT para RescueUSB SO
# Estados: LIBRE, OCUPADO, DANADO, ELIMINADO

FAT="data/fat.txt"
BLOQUES_DIR="bloques"
REPORTES_DIR="reportes"
TOTAL_BLOQUES=30

mkdir -p data "$BLOQUES_DIR" "$REPORTES_DIR" logs

mostrar_error() {
    echo "ERROR: $1"
}

validar_usb_inicializada() {
    if [ ! -f "$FAT" ]; then
        mostrar_error "Primero debe inicializar la USB simulada. Use la opcion 1 del menu."
        return 1
    fi
    return 0
}

validar_entero() {
    local valor="$1"
    local nombre="$2"

    if [ -z "$valor" ]; then
        mostrar_error "$nombre no puede estar vacio."
        return 1
    fi

    if [[ ! "$valor" =~ ^[0-9]+$ ]]; then
        mostrar_error "$nombre debe ser un numero entero."
        return 1
    fi

    return 0
}

validar_nombre_archivo() {
    local nombre_archivo="$1"

    if [ -z "$nombre_archivo" ]; then
        mostrar_error "El nombre del archivo no puede estar vacio."
        return 1
    fi

    if [[ ! "$nombre_archivo" =~ ^[a-zA-Z][a-zA-Z0-9_]*\.[a-zA-Z]{2,5}$ ]]; then
        mostrar_error "Nombre invalido. Ejemplos validos: informe.pdf, tarea1.txt, backup.zip"
        return 1
    fi

    return 0
}

inicializar_usb() {
    > "$FAT"
    rm -f "$BLOQUES_DIR"/bloque_*.txt 2>/dev/null

    for i in $(seq 0 $((TOTAL_BLOQUES - 1))); do
        echo "$i|LIBRE|-|-" >> "$FAT"
    done

    echo "USB simulada inicializada correctamente con $TOTAL_BLOQUES bloques."
}

mostrar_fat() {
    validar_usb_inicializada || return

    echo
    echo "BLOQUE | ESTADO     | ARCHIVO          | SIGUIENTE"
    echo "---------------------------------------------------"

    local b e a s
    while IFS="|" read -r b e a s; do
        printf "%-6s | %-10s | %-16s | %-9s\n" "$b" "$e" "$a" "$s"
    done < "$FAT"
}

actualizar_bloque() {
    local bloque_buscar="$1"
    local nuevo_estado="$2"
    local nuevo_archivo="$3"
    local nuevo_siguiente="$4"
    local tmp="data/fat_tmp_$$.txt"
    local b e a s

    > "$tmp"

    while IFS="|" read -r b e a s; do
        if [ "$b" = "$bloque_buscar" ]; then
            echo "$b|$nuevo_estado|$nuevo_archivo|$nuevo_siguiente" >> "$tmp"
        else
            echo "$b|$e|$a|$s" >> "$tmp"
        fi
    done < "$FAT"

    mv "$tmp" "$FAT"
}

registrar_archivo() {
    validar_usb_inicializada || return

    local nombre_archivo
    local cantidad
    local disponibles=()
    local usados=()
    local i bloque siguiente

    read -p "Nombre del archivo: " nombre_archivo
    validar_nombre_archivo "$nombre_archivo" || return

    if grep -Fq "|$nombre_archivo|" "$FAT"; then
        mostrar_error "Ya existe una referencia a '$nombre_archivo' en la FAT. Use otro nombre."
        return
    fi

    read -p "Cantidad de bloques a usar: " cantidad
    validar_entero "$cantidad" "La cantidad de bloques" || return

    if [ "$cantidad" -le 0 ]; then
        mostrar_error "La cantidad de bloques debe ser mayor que cero."
        return
    fi

    mapfile -t disponibles < <(awk -F"|" '$2=="LIBRE" || $2=="ELIMINADO" {print $1}' "$FAT")

    if [ ${#disponibles[@]} -lt "$cantidad" ]; then
        mostrar_error "No hay bloques disponibles suficientes. Disponibles: ${#disponibles[@]}"
        return
    fi

    for ((i=0; i<cantidad; i++)); do
        usados+=("${disponibles[$i]}")
    done

    for ((i=0; i<cantidad; i++)); do
        bloque="${usados[$i]}"

        if [ "$i" -eq $((cantidad - 1)) ]; then
            siguiente="FIN"
        else
            siguiente="${usados[$((i + 1))]}"
        fi

        actualizar_bloque "$bloque" "OCUPADO" "$nombre_archivo" "$siguiente"
        echo "Contenido nuevo del bloque $bloque perteneciente al archivo $nombre_archivo" > "$BLOQUES_DIR/bloque_$bloque.txt"
    done

    echo "Archivo '$nombre_archivo' registrado correctamente."
    echo "Nota: si se usaron bloques ELIMINADO, la informacion anterior fue sobrescrita."
}

simular_danio() {
    validar_usb_inicializada || return

    local bloque linea estado nombre_archivo siguiente

    read -p "Ingrese numero de bloque a danar: " bloque
    validar_entero "$bloque" "El bloque" || return

    if ! grep -q "^$bloque|" "$FAT"; then
        mostrar_error "El bloque $bloque no existe en la USB simulada."
        return
    fi

    linea=$(grep "^$bloque|" "$FAT")
    estado=$(echo "$linea" | cut -d"|" -f2)
    nombre_archivo=$(echo "$linea" | cut -d"|" -f3)
    siguiente=$(echo "$linea" | cut -d"|" -f4)

    if [ "$estado" = "LIBRE" ]; then
        mostrar_error "No se puede danar un bloque libre."
        return
    fi

    if [ "$estado" = "DANADO" ]; then
        mostrar_error "El bloque ya se encuentra danado."
        return
    fi

    actualizar_bloque "$bloque" "DANADO" "$nombre_archivo" "$siguiente"
    echo "Bloque $bloque marcado como DANADO."
}

eliminar_archivo() {
    validar_usb_inicializada || return

    local nombre_archivo
    local tmp="data/fat_tmp_$$.txt"
    local b e a s
    local bloques_eliminados=0

    read -p "Nombre del archivo a eliminar: " nombre_archivo

    if [ -z "$nombre_archivo" ]; then
        mostrar_error "Debe ingresar el nombre del archivo."
        return
    fi

    if ! grep -Fq "|$nombre_archivo|" "$FAT"; then
        mostrar_error "El archivo '$nombre_archivo' no existe en la FAT."
        return
    fi

    > "$tmp"

    while IFS="|" read -r b e a s; do
        if [ "$a" = "$nombre_archivo" ] && [ "$e" = "OCUPADO" ]; then
            echo "$b|ELIMINADO|$a|$s" >> "$tmp"
            bloques_eliminados=$((bloques_eliminados + 1))
        else
            echo "$b|$e|$a|$s" >> "$tmp"
        fi
    done < "$FAT"

    mv "$tmp" "$FAT"

    if [ "$bloques_eliminados" -eq 0 ]; then
        mostrar_error "El archivo no tiene bloques OCUPADO para eliminar. Tal vez ya fue eliminado o esta danado."
        return
    fi

    echo "Archivo '$nombre_archivo' marcado como ELIMINADO."
    echo "Bloques liberados para posible reutilizacion: $bloques_eliminados"
    echo "Importante: si esos bloques se usan en otro archivo, ya no se podra recuperar el archivo anterior."
}

recuperar_archivo() {
    validar_usb_inicializada || return

    local nombre_archivo
    local bloques_eliminados bloques_danados
    local salida tmp
    local b e a s
    local recuperados=0
    local perdidos=0
    local danados=0

    read -p "Ingrese nombre del archivo a recuperar: " nombre_archivo

    if [ -z "$nombre_archivo" ]; then
        mostrar_error "Debe ingresar el nombre del archivo."
        return
    fi

    if ! grep -Fq "|$nombre_archivo|" "$FAT"; then
        mostrar_error "El archivo '$nombre_archivo' no existe en la FAT. Puede haber sido sobrescrito por otro archivo."
        return
    fi

    bloques_eliminados=$(awk -F"|" -v arch="$nombre_archivo" '$3==arch && $2=="ELIMINADO" {c++} END {print c+0}' "$FAT")
    bloques_danados=$(awk -F"|" -v arch="$nombre_archivo" '$3==arch && $2=="DANADO" {c++} END {print c+0}' "$FAT")

    if [ "$bloques_eliminados" -eq 0 ] && [ "$bloques_danados" -eq 0 ]; then
        mostrar_error "El archivo no esta eliminado ni danado. No necesita recuperacion."
        return
    fi

    salida="$REPORTES_DIR/${nombre_archivo}_recuperado.txt"
    tmp="data/fat_tmp_$$.txt"
    > "$salida"
    > "$tmp"

    while IFS="|" read -r b e a s; do
        if [ "$a" = "$nombre_archivo" ]; then
            if [ "$e" = "ELIMINADO" ]; then
                if [ -f "$BLOQUES_DIR/bloque_$b.txt" ]; then
                    cat "$BLOQUES_DIR/bloque_$b.txt" >> "$salida"
                    echo "" >> "$salida"
                    echo "$b|OCUPADO|$a|$s" >> "$tmp"
                    recuperados=$((recuperados + 1))
                else
                    echo "[BLOQUE $b SIN ARCHIVO FISICO]" >> "$salida"
                    echo "$b|ELIMINADO|$a|$s" >> "$tmp"
                    perdidos=$((perdidos + 1))
                fi
            elif [ "$e" = "DANADO" ]; then
                echo "[BLOQUE $b DANADO - NO RECUPERADO]" >> "$salida"
                echo "$b|$e|$a|$s" >> "$tmp"
                danados=$((danados + 1))
            elif [ "$e" = "OCUPADO" ]; then
                if [ -f "$BLOQUES_DIR/bloque_$b.txt" ]; then
                    cat "$BLOQUES_DIR/bloque_$b.txt" >> "$salida"
                    echo "" >> "$salida"
                fi
                echo "$b|$e|$a|$s" >> "$tmp"
            else
                echo "$b|$e|$a|$s" >> "$tmp"
            fi
        else
            echo "$b|$e|$a|$s" >> "$tmp"
        fi
    done < "$FAT"

    mv "$tmp" "$FAT"

    echo "Recuperacion finalizada."
    echo "Bloques recuperados y cambiados a OCUPADO: $recuperados"
    echo "Bloques danados no recuperados: $danados"
    echo "Bloques perdidos sin archivo fisico: $perdidos"
    echo "Archivo generado: $salida"
}

case "$1" in
    init)
        inicializar_usb
        ;;
    mostrar)
        mostrar_fat
        ;;
    registrar)
        registrar_archivo
        ;;
    daniar)
        simular_danio
        ;;
    eliminar)
        eliminar_archivo
        ;;
    recuperar)
        recuperar_archivo
        ;;
    *)
        echo "Uso correcto:"
        echo "$0 init"
        echo "$0 mostrar"
        echo "$0 registrar"
        echo "$0 daniar"
        echo "$0 eliminar"
        echo "$0 recuperar"
        ;;
esac
