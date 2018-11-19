#!/bin/bash
# ============================================================================
# Titolo: execute_recursively.sh
# Descrizione: Esegue, in modo ricorsivo, la stringa ricevuta in input interpretandola come un comando bash
# Autore: alfredo.milani.94@gmail.com
# Data: mar  8 mag 2018, 21.42.45, CEST
# Licenza: MIT License
# Versione: 0.0.1
# Note: --/--
# Versione bash: 4.4.12(1)-release
# ============================================================================


function execute_recursively {
    current_path="`realpath "${1}"`"
    command="${2}"

    cd "${current_path}"
    eval "${command}"

    for file in "${current_path}/"*; do
        if [ -d "${file}" ]; then
            basename_file=`basename "${file}"`
            execute_recursively "${current_path}/${basename_file}" "${command}"
        fi
    done
}

execute_recursively "${1}" "${2}"
