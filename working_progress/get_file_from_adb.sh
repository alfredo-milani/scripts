#!/bin/bash
# ============================================================================

# Titolo:           get_file_from_adb.sh
# Descrizione:      Questo script permette di copiare, in modo ricorsivo, i files da una directory del device Android collegato (avente pimpostazioni di debug abilitate)
# Autore:           Alfredo Milani
# Data:             mar 18 lug 2017, 15.37.21, CEST
# Licenza:          MIT License
# Versione:         0.0.1
# Note:             --/--
# Versione bash:    4.4.12(1)-release
# ============================================================================



adb='/opt/Sdk/platform-tools/adb';
path_imm='/storage/self/primary/Pictures/Fotocamera';
path_to_store=`mktemp -d -p /dev/shm/`;

# array contenente la lista delle immagini contenute nella directory path_imm secondo la struttura del file system del device
imm=(`$adb shell "ls $path_imm"`);

for el in "${imm[@]}"; do
    # elemento privato degli spazi bianchi
    trimmed_el=`echo $el | tr -d '[:space:]'`;
    $adb pull "$path_imm/$trimmed_el" "$path_to_store";
done
