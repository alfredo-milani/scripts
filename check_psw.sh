#!/bin/bash
# ============================================================================

# Titolo:           check_psw.sh
# Descrizione:      GUI per richiedere maggiori privilegi
# Autore:           Alfredo Milani  (alfredo.milani@gmail.com)
# Data:             sab 22 lug 2017, 00.21.59, CEST
# Licenza:          MIT License
# Versione:         1.0.0
# Note:             --/--
# Versione bash:    4.4.12(1)-release
# ============================================================================



gksudo $@;

if [ $? == 1 ]; then
    err_str="Password sbagliata";
    echo $err_str;
    zenity --error --text="$err_str" &> /dev/null;
    exit 1;
fi

exit 0;
