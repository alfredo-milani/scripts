#!/bin/bash
# ============================================================================

# Titolo:           redshift_regolator.sh
# Descrizione:      Regola la temperatura del colore (in gradi K) dello schermo
# Autore:           Alfredo Milani  (alfredo.milani.94@gmail.com)
# Data:             dom 23 lug 2017, 00.19.22, CEST
# Licenza:          MIT License
# Versione:         1.0.0
# Note:             --/--
# Versione bash:    4.4.12(1)-release
# ============================================================================



declare -r icon_path="/usr/share/icons/Adwaita/48x48/status/display-brightness-symbolic.symbolic.png";
declare -r tool="redshift";

declare -r lat=41.6;
declare -r long=13.4;
declare -i daytime=5500;
declare -i nighttime=4000;

declare -r tool_is_on=(`ps -A | grep -w $tool`);
declare -r pid="${tool_is_on[0]}";



for arg in $@; do
    case "$arg" in
        -[hH] | --[hH] | -help | -HELP | --help | --HELP )
            echo -e "./`basename $0`  [options]";
            echo -e "";
            echo -e "\tOptions:";
            echo -e "\t\t-d=value )  valore intero che indica la temperatura (in gradi K) dello schermo durante il giorno";
            echo -e "\t\t-n=value )  valore intero che indica la temperatura (in gradi K) dello schermo durante la notte";
            echo -e "\t\t   1 | 2 )  indicano i sets di default per la temeratura di giorno e di notte:";
            echo -e "\t\t                1  -->  daytime=5000 / nighttime=3000";
            echo -e "\t\t                2  -->  daytime=5500 / nighttime=4000";
            echo -e "";
            echo -e "Nota: Se il seguente script è già stato avviato in precedenza una successiva esecuzione causerà la chiusura del processo precedente";
            exit 1;
            ;;
    esac
done

while [ $# -gt 0 ]; do
    case "$1" in
        -d )
            shift;
            daytime=$1;
            break;
            ;;

        -n )
            shift;
            nighttime=$2;
            break;
            ;;

        1 )
            daytime=5000;
            nighttime=3000;
            break;
            ;;

        2 )
            daytime=5500;
            nighttime=4000;
            break;
            ;;

        * )
            echo "Utilizza il flag -h per ottenere maggiori informazioni" &&
            exit 1;
            ;;
    esac
done



if [ ${#pid} != 0 ]; then
    # str="Chiusura $tool";
    # zenity --notification --window-icon="$icon_path" --text="$str";
    kill -15 $pid;
else
    # str="Avvio $tool";
    # zenity --notification --window-icon="$icon_path" --text="$str";
    $tool -l $lat:$long -t $daytime:$nighttime;
fi
