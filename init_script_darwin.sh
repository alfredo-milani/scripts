#!/usr/local/bin/bash
# ============================================================================
# Titolo:           init_script.sh
# Descrizione:      Inizializza uno script inserendo un header
# Autore:           Alfredo Milani  (alfredo.milani.94@gmail.com)
# Data:             gio 20 lug 2017, 01.41.23, CEST
# Licenza:          MIT License
# Versione:         1.5.0
# Note:             Usage: ./init_script.sh  [ -h | ../path_salavataggio/ ]
# Versione bash:    4.4.12(1)-release
# ============================================================================



declare -r data="`date`"
declare -r clear='/usr/bin/clear'
declare -r EXIT_SUCCESS=0
declare -r EXIT_FAILURE=1
declare -r null='/dev/null'
declare shell='/usr/local/bin/bash'
declare description='--/--'
declare name="$USER"
# versione secondo le sintassi: version.revision.release
declare version='0.0.1'
declare notes='--/--'
declare editor
declare title
declare extension='.sh'
declare license='MIT License'

# file a cui aggiungere / rimuovere l'header
declare file=''
# path di salvataggio dell'header file
declare rescue_path='.'
# header da completare
declare header='null'
# array contenente le funzioni da eseguire
declare operations=()



# selezione titolo
function select_title {
    # se file esiste --> l'operazione selezionata è -i (con l'opzione -f file)
    [ ${#file} != 0 ] &&
    title="`basename $file`" && return $EXIT_SUCCESS

    # titolo script
    [ "$1" != $EXIT_FAILURE ] && printf "Inserisci un titolo:\t"
    read -r title
    printf "\n"

    [ ${#title} == 0 ] && select_title && return

    # sostituisci gli spazi bianchi con _
    title="${title// /_}"

    # conversione uppercase to lowercase.
    title="${title,,}"

    printf "Inserisci l'estensione dello script (default: $extension):\t"
    read -r tmp
    [ ${#tmp} != 0 ] && extension="$tmp" && add_ext=0

    # aggiungi l'estensione se non presente
    ( [[ "$title" != *.* ]] || [ "$add_ext" == 0 ] ) && title="$title$extension"

    # controlla l'esistenza di un file con lo stesso nome nella directory corrente
    if [ -e "$rescue_path/$title" ] ; then
        printf "File \"$title\" già esistente in \"$rescue_path\".
Inserisci un nome diverso per continuare.\t"

        select_title $EXIT_FAILURE && return
    fi
}

# controllo esistenza editor
function check_editor {
    command -v "$1" &> "$null"
    [ $? == 0 ] && return $EXIT_SUCCESS
    return $EXIT_FAILURE
}

# selezione editor
function select_editor {
    # seleziona l'editor preferito
    printf "Seleziona un editor per aprire lo script appena creato:\n
    0 - ESCI
    1 - vi
    2 - vim
    3 - emacs
    4 - nano
    5 - atom
    6 - gedit
    7 - Sublime Text\n"
    read -r editor

    case $editor in
        0 ) return $EXIT_SUCCESS ;;

        1 )
            ed="vi"
            ( check_editor $ed && $ed +15 `realpath -e "$file"` ) ||
            ( $clear && printf "$ed non installato nel sistema.\nRiprovare.\n" && select_editor )
            ;;

        2 )
            ed="vim"
            ( check_editor $ed && $ed +15 `realpath -e "$file"` ) ||
            ( $clear && printf "$ed non installato nel sistema.\nRiprovare.\n" && select_editor )
            ;;

        3 )
            ed="emacs"
            ( check_editor $ed && $ed +15 `realpath -e "$file"` ) ||
            ( $clear && printf "$ed non installato nel sistema.\nRiprovare.\n" && select_editor )
            ;;

        4 )
            ed="nano"
            ( check_editor $ed && $ed +15 `realpath -e "$file"` ) ||
            ( $clear && printf "$ed non installato nel sistema.\nRiprovare.\n" && select_editor )
            ;;

        5 )
            ed="atom"
            ( check_editor $ed && $ed `realpath -e "$file"` ) ||
            ( $clear && printf "$ed non installato nel sistema.\nRiprovare.\n" && select_editor )
            ;;

        6 )
            ed="gedit"
            ( check_editor $ed && $ed +15 `realpath -e "$file"` ) ||
            ( $clear && printf "$ed non installato nel sistema.\nRiprovare.\n" && select_editor )
            ;;

        7 )
            ed="/Applications/Sublime Text.app/Contents/MacOS/Sublime Text"
            ( check_editor "$ed" && "$ed" `realpath -e "$file"` & ) ||
            ( $clear && printf "$ed non installato nel sistema.\nRiprovare.\n" && select_editor )
            ;;

        * )
            $clear
            printf "Comando non riconosciuto.\nRiprocare.\n\n"
            select_editor
            ;;
    esac
}

function select_shell {
    printf "\nInserisci il path della shell da utilizzare (default: $shell):\t"
    read -r tmp_shell
    printf "\n"
    if [ ${#tmp_shell} != 0 ]; then
        cmd_path=`which $tmp_shell`
        if [ $? == 0 ]; then
            shell=$cmd_path
        else
            printf "Shell \"$tmp_shell\" non esistente.\nInserire una shell valida oppure clicca invio per la shell di default ($shell).\n"
            select_shell
        fi
    fi

    return $EXIT_SUCCESS
}

# controllo consistenza risorse
function check_res {
    for el in "${operations[@]}"; do
        case "$el" in
            create_header_file )
                ! [ -d "$rescue_path" ] &&
                printf "Directory \"$rescue_path\" non valida.\n" &&
                return $EXIT_FAILURE
                ;;

            push_header | remove_header )
                ! [ -f "$file" ] &&
                printf "Non è stato specificato alcun file per l'operazione specificata.\nUtilizza il flag -f per specificare il file.\n" &&
                return $EXIT_FAILURE
                ;;
        esac
    done

    return $EXIT_SUCCESS
}

# uso
function usage {
    cat << EOF

# Utilizzo

    $0  -[args]

# Args

    -h :                mostra questo aiuto
    -p ../path/ :       path di salvataggio del file
    -f ../path/file :   file a cui aggiungere/rimuovere l'header
    -rm n1-n2 :         rimuove da n1 a n2 righe nel file specificato con il flag -f
    -i :                inserisce un header nel file specificato dal flag -f
    -header :           utilizza il contenuto del file specificato dopo questo flag come header

    Nota: se non vine specificato alcun argomento lo script provvederà a creare un file ed a inserire l'header specificato

EOF

    exit $EXIT_FAILURE
}

# controllo operazioni duplicate nell'array operations
function check_from_array {
    for el in "${operations[@]}"; do
        [ "$el" == "$1" ] &&
        return $EXIT_SUCCESS
    done
    return $EXIT_FAILURE
}

# elimina un elemnto dall'array operations
function remove_el_from_array {
    operations=("${operations[@]/$1}")
}

# controllo preliminare sull'input dell'utente
function preliminar_input_check {
    for arg in "$@"; do
        case "$arg" in
            -[hH] | --[hH] | -help | -HELP | --help | --HELP ) usage ;;
        esac
    done
    return $EXIT_SUCCESS
}

# parsing input
function parse_input {
    while [ $# -gt 0 ]; do
        case $1 in
            -f )
                shift
                file=`realpath $1`
                shift
                ;;

            -header )
                shift
                check_from_array "fill_header" && remove_el_from_array "fill_header"
                ! check_from_array "push_header" && operations+=("push_header")
                ! [ -f "$1" ] && printf "File \"$1\" non valido.\n" && return $EXIT_FAILURE
                header=`cat $1`
                shift
                ;;

            -i )
                ! check_from_array "fill_header" && operations+=("fill_header")
                ! check_from_array "push_header" && operations+=("push_header")
                shift
                ;;

            -p )
                shift
                warning="Flag -p ignorato.\n"
                (
                check_from_array "push_header" ||
                check_from_array "remove_header"
                ) && printf "$warning"
                rescue_path="$1"
                printf "Directory selezionata: `realpath "$rescue_path"`\n\n"
                shift
                ;;

            -rm )
                shift
                # controllo sintattico argomento -rm
                ! [[ $1 == *'-'* ]] && printf "Sintassi errata per l'argomento -rm.\n" && usage
                # parse input
                tmp=`cut -d'-' -f1 <<< $1`
                [ "$tmp" == "" ] && n=1 || n=$tmp
                m=`cut -d'-' -f2 <<< $1`
                # controllo semantico argomneto -rm
                [ $n -gt $m ] && printf "Argomento -rm: n1-n2 --> n1 deve essere minore di n2.\nSe si omette n1 si assumerà uguale a 0.\n"

                # se l'operazione push_header è presente nell'elenco delle operazioni
                # inserisco l'operazione remove_header prima di push_header
                if check_from_array "push_header"; then
                    remove_el_from_array "push_header"
                    operations+=("remove_header $n $m" "push_header")
                else
                    operations+=("remove_header $n $m")
                fi
                shift
                ;;

            * )
                printf "Operazione \"$1\" non riconosciuta.\nUtilizza il flag \"-h\" per ottenere maggiori informazioni sulle operazioni supportate.\n"
                shift
                ;;
        esac
    done

    if [ ${#operations} == 0 ]; then
        # comportamento di default
        operations+=("fill_header" "create_header_file")
    fi
    operations+=("select_editor")

    return $EXIT_SUCCESS
}

# funzione deputata a riempire l'header con le informazioni inserite dall'utente
function fill_header {
    # se è stato già passato un header come argomento dall'utente uscire
    [ "$header" != "null" ] && return

    select_shell

    select_title

    printf "Inserisci una descrizione:\t"
    read -r tmp
    [ ${#tmp} != 0 ] && description="$tmp"

    printf "Inserisci il tuo nome (default: $USER):\t"
    read -r tmp
    [ ${#tmp} != 0 ] && name=$tmp

    printf "Inserisci il numero di versione (default: 0.0.1):\t"
    read -r tmp
    [ ${#tmp} != 0 ] && version="$tmp"

    printf "Inserisci la licenza di rilascio (default: MIT License):\t"
    read -r tmp
    [ ${#tmp} != 0 ] && license="$tmp"

    printf "Inserisci le note:\t"
    read -r tmp
    [ ${#tmp} != 0 ] && notes="$tmp"

    # al posto di cat << è possibile usare printf -v var_name
    # nota: %-Xs --> lascia un segnaposto lungo X caratteri per una stringa
    #       -v var --> stampa dentro la variabile var

    header=`cat << EOF
#!$shell
# ============================================================================
# Titolo: $title
# Descrizione: $description
# Autore: $name
# Data: $data
# Licenza: $license
# Versione: $version
# Note: $notes
# Versione bash: $BASH_VERSION
# ============================================================================
EOF`
}

# crea un file, inserisce l'header e lo apre con un edito di testo
function create_header_file {
    file=$rescue_path/$title

    tee <<< "$header" "$file" 1> $null

    # rendi eseguibile lo script
    chmod +x "$file"

    return $?
}

# inserisce l'header all'inizio del file
function push_header {
    tmp_file='/dev/shm/tmp'
    echo "$header" | cat - "$file" > "$tmp_file" &&
    mv "$tmp_file" "$file"

    return $?
}

# rimuovi vecchio header
# arg1-arg2 --> intervallo di strinche commentate da rimuovere
# sed 'n,md' $file --> rimuovere da n a m righe del file
function remove_header {
    # controllo sul numero di argomenti ricevuti
    ([ ${#1} == 0 ] || [ ${#2} == 0 ]) &&
    printf "Errore interno nella funzione \"${FUNCNAME[0]}\".\n" &&
    return $EXIT_FAILURE

    sed -i ''$1','$2'd' "$file"

    return $?
}



function main {
    # controllo preliminare sull'input dell'utente
    preliminar_input_check "$@"
    # parsing input
    ! parse_input "$@" && return $EXIT_FAILURE
    # controllo risorse
    check_res || return $EXIT_FAILURE

    # esecuzione operazioni
    for ((i = 0; i < ${#operations}; ++i)); do
        if [ "${operations[$i]}" == "remove_header" ]; then
            # passaggio argomenti operazione remove_header
            ${operations[$i]} ${operations[++i]} ${operations[++i]}
        else
            ${operations[$i]}
        fi

        [ $? != $EXIT_SUCCESS ] && return $EXIT_FAILURE
    done
}

main "$@"
exit $?