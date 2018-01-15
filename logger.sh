#!/bin/bash
# ============================================================================

# Titolo:           logger.sh
# Descrizione:      Semplice logger
# Autore:           Alfredo Milani (alfredo.milani.94@gmail.com)
# Data:             lun 25 set 2017, 22.46.22, CEST
# Licenza:          MIT License
# Versione:         0.2.0
# Note:             --/--
# Versione bash:    4.4.12(1)-release
# ============================================================================



# Semplice logger
declare -r EXIT_SUCCESS=0;
declare -r EXIT_FAILURE=1;

declare -r tmp_path=/tmp;



if [ $# -gt 1 ]; then
    file_name="$1.XXXXXX";
    log_file=`mktemp $tmp_path/$file_name`;

    for i in "${@:2}"; do
        string+=" $i";
    done
    echo `date`" | $1 > $string" >> $log_file;
else
    log_file=`mktemp`;
    echo `date`" > $@" >> $log_file;
fi

exit $EXIT_SUCCESS;
