#!/bin/bash
# ============================================================================
# Titolo: add_and_crypt.sh
# Descrizione: Decripta, estrae, agginge e cripta il file specificato
# Autore: alfredo
# Data: mer 21 feb 2018, 19.24.21, CET
# Licenza: MIT License
# Versione: 0.0.5
# Note: --/--
# Versione bash: 4.4.12(1)-release
# ============================================================================



##### ##################################
##### Inizio controllo preliminare #####
# $$ --> indica il pid del processo corrente
# il file /proc/pid/cmdline contiene la riga di comando con la quale è stato lanciato il processo identificato da pid.
# cut -c 1-4 restituisce i primi 4 caratteri della stringa presa in input
line_acc1="bash"; line_acc2="/bin/bash"
cmd_line=`cat /proc/$$/cmdline | tr '\0' ' '`
# verifica se tra i primi caratteri della riga di comando c'è la stringa "bash"
cmd_acc=`echo $cmd_line | cut -c 1-${#line_acc1}`
if [ "$line_acc1" != "$cmd_acc" ]; then
    cmd_acc=`echo $cmd_line | cut -c 1-${#line_acc2}`
    if [ "$line_acc2" != "$cmd_acc" ]; then
        printf "\nLo script corrente deve essere eseguito da una shell bash e NON sh!\n"
        exit 1
    fi
fi
##### Fine controllo preliminare #####
######################################


# Colori
declare -r R='\033[0;31m' # red
declare -r Y='\033[1;33m' # yellow
declare -r G='\033[0;32m' # green
declare -r DG='\033[1;30m' # dark gray
declare -r U='\033[4m' # underlined
declare -r NC='\033[0m' # No Color
declare -r BD='\e[1m' # Bold

declare -r EXIT_SUCCESS=0
declare -r EXIT_FAILURE=1
declare -r null_str="--/--"
declare -r NULL="/dev/null"
declare -r script_name=`basename "$0"`
declare -r dir_conf="/home/$USER/.config/${script_name%.*}"
declare -r config_file="$dir_conf/asset"
declare show_dirs=false

declare -A structure=()
declare -A key_of_command=()
declare tmp="/dev/shm"
declare structure_file=""
declare crypted_file=""
declare decrypted_file=""
declare decompressed_file=""
declare ext=""


function manage_signal {
    trap "on_exit" SIGINT SIGKILL SIGTERM SIGUSR1 SIGUSR2
}

function get_asset {
    while IFS='=' read -r key value; do
        case "$key" in
            structure_file )  structure_file="$value" ;;
        esac
    done <<< `sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' "$config_file"`
}

function check_asset {
    if ! [ -f "$config_file" ]; then
        # Primo avvio
        cat <<EOF > "$config_file"
[gerarchia directory]
structure_file=
EOF
    else
        get_asset
    fi
}

function read_structure {
    while IFS='=' read -r key value; do
        structure+=(["$key"]="$value")
    done <<< `sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' "$structure_file"`
}

function validate_new_files {
    for el in ${!key_of_command[@]}; do
        key="$el"
        value="${key_of_command["$key"]}"
        if ! [ -f "$value" ] &&
        ! [ -d "$value" ]; then
            printf "${Y}Attenzione! Il file \'$value\' sarà ignorato perché non esistente.\n${NC}"
            unset key_of_command["$key"]
        else
            key_of_command+=(["$key"]="`realpath "$value"`")
        fi
    done
}

function usage {
    cat <<EOF

`printf "${BD}# Sintassi${NC}"`

    ./`basename "$0"` -[args] FILE

`printf "${BD}# Descrizione${NC}"`

    `basename "$0"` è un tool che serve per aggiornare un archivio compresso specificato da FILE.
    Se verrà passato solo FILE come argomento allora verrà decriptato ed estratto.

`printf "${BD}# Argomenti${NC}"`

    -arg | -ARG :   mostra gli argomenti contenuti nel file di configurazione
    -h | -H     :   visualizza questo aiuto
    -sd | -SD   :   mostra le directory utilizzate
    -structure | -STRUCTURE     :   specifica un file per configurare la gerarchia di directory dell'archivio compresso
    -tmp | -TMP     :   specifica directory per files temporanei
    -val | -VAL     :   mostra flags disponibili per accedere alla directory del file compresso e i corrispondenti valori

`printf "${BD}# File di configurazione${NC}"`

    Il file di configurazione è un tipo di file key-value del tipo: -parametro-da-specificare=path/relativo/archivio/compresso

EOF

    exit $EXIT_SUCCESS
}

function get_operation_on_archive {
    for el in ${!structure[@]}; do
        if [ "$el" == "$1" ]; then
            key_of_command+=(["$1"]="$2")
            return $EXIT_SUCCESS
        fi
    done

    return $EXIT_FAILURE
}

function parse_input {
    while [ $# -gt 0 ]; do
        case "$1" in
            -arg | -ARG )
                # mostra file configurazione
                if [ -f "$structure_file" ]; then
                    printf "${BD}Inizio file di configurazione locato in \'$structure_file\':\n${NC}"
                    cat "$structure_file"
                    printf "${BD}Fine file di configurazione.\n\n${NC}"
                    exit $EXIT_SUCCESS
                else
                    printf "${R}File per la configurazione della gerarchia di directory non presente.\nUtilizzare il flag -h per ottenere informazioni su come impostarlo\n${NC}"
                    on_exit
                    exit $EXIT_FAILURE
                fi
                ;;

            -[hH] | --[hH] | -help | -HELP | --help | --HELP )
                usage
                ;;

            -sd | -SD )
                show_dirs=true
                shift
                ;;

            -structure | -STRUCTURE )
                shift
                if [ -f "$1" ]; then
                    # specifica file per configurare la gerarchia di directory all'interno dell'archivio compresso
                    structure_file="`realpath "$1"`"
                    sed -i "s:^structure_file=.*:structure_file=$structure_file:g" "$config_file"
                else
                    printf "${Y}File: $1 non esistente; è necessario specificare un file per configurare la gerarchia di directory dell'archivio compresso\n${NC}"
                    on_exit
                    exit $EXIT_FAILURE
                fi
                shift
                ;;

            -tmp | -TMP )
                shift
                # specifica directory dei files temporanei
                [ -d "$1" ] && tmp="`realpath "$1"`" ||
                printf "${Y}Directory: $1 non esistente; verrà usata quella di default ($tmp)\n${NC}"
                shift
                ;;

            -val | -VAL )
                printf "${BD}\nValori contenuti nel file di configurazione:\n${NC}"
                i=1
                for el in ${!structure[@]}; do
                    printf "${BD}${i}.${NC} $el\t${BD}-->${NC}\t${structure["$el"]}\n"
                    i=$((++i))
                done
                exit $EXIT_SUCCESS
                ;;

            * )
                get_operation_on_archive "$1" "$2" && shift && shift && continue

                if [ ${#crypted_file} != 0 ]; then
                    printf "${Y}Il file criptato è già stato aggiunto ($crypted_file).\nIl file $1 non sarà considerato.\nContinuare comunque? [Yes / No]\n${NC}"

                    read choise
                    [ "$choise" != "Yes" ] &&
                    printf "Uscita.\n" &&
                    exit $EXIT_SUCCESS
                else
                    check_file "$1"
                fi
                shift
                ;;
        esac
    done
}

function check_file {
    if [ $# -eq 0 ]; then
        printf "${R}Devi specificare almento un'opzione\n${NC}"
        usage
    fi

    if [ ${#1} -eq 0 ]; then
        printf "${R}Non è stato specificato alcun file.\n${NC}"
        exit $EXIT_FAILURE
    elif [ -f "$1" ]; then
        crypted_file="`realpath "$1"`"
    else
        printf "${R}Il file \'$1\' non esiste\n${NC}"
        exit $EXIT_FAILURE
    fi
}

function create_tmp_env {
    # creazione directory temporanea
    tmp=`mktemp -d -p "$tmp"`
    cd "$tmp"
}

function remove_tmp {
    rm -rf "$tmp"
}

function on_exit {
    remove_tmp
}

function decrypt_file {
    # decripta
    cp "$crypted_file" "$tmp"
    gpg "`basename "$crypted_file"`" &> $NULL
    [ $? != 0 ] &&
    printf "${R}Errore durante la decodifica.\n${NC}" &&
    on_exit &&
    exit $EXIT_FAILURE
    tmp_crypted_file="`basename "$crypted_file"`"
    decrypted_file="${tmp_crypted_file%.*}"
}

function crypt_file {
    printf "${G}${U}Inserisci la chiave di cifratura per il nuovo archivio\n${NC}"
    gpg --yes -ca --cipher-algo aes128 -o "$crypted_file" "$decrypted_file"
}

function decompress_file {
    ext="${decrypted_file##*.}"
    case "$ext" in
        tar )
            tar -xf "$decrypted_file" -C "$tmp" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            ;;

        xz )
            tar -xvf "$decrypted_file" -C "$tmp" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            decompressed_file="${decompressed_file%.*}"
            ;;

        gz )
            tar -zxvf "$decrypted_file" -C "$tmp" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            decompressed_file="${decompressed_file%.*}"
            ;;

        bz2 )
            tar -jxvf "$decrypted_file" -C "$tmp" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            decompressed_file="${decompressed_file%.*}"
            ;;

        zip )
            unzip "$decrypted_file" -d "$tmp" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            ;;

        7z )
            7z x "$decrypted_file" -o"$tmp" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            ;;

        * )
                printf "${R}Formato sconosciuto: \'$tmp\'. Estrazione non riuscita.\n${NC}"
                return $EXIT_FAILURE
    esac
}

function compress_file {
    case "$ext" in
        tar )   tar -cvf "$decrypted_file" "$decompressed_file" &> $NULL ;;

        xz )    # tar cf - "$decompressed_file" | xz -z - > "$decrypted_file"
                tar -cJf "$decrypted_file" "$decompressed_file" &> $NULL ;;

        gz )    tar -czf "$decrypted_file" "$decompressed_file" &> $NULL ;;

        bz2 )   tar -cjvf "$decrypted_file" "$decompressed_file" &> $NULL ;;

        zip )   zip -r "$decrypted_file" "$decompressed_file" &> $NULL ;;

        7z )    7z a "$decrypted_file" "$decompressed_file" &> $NULL ;;

        * )
            printf "${R}Formato sconosciuto: \'$tmp\'. Estrazione non riuscita.\n${NC}"
            return $EXIT_FAILURE
    esac
}

function add_new_file {
    cd "$decompressed_file"

    for el in ${!key_of_command[@]}; do
        if [ -d "${key_of_command["$el"]}" ]; then
            cp "${key_of_command["$el"]}"/* "./${structure["$el"]}"
        else
            cp "${key_of_command["$el"]}" "./${structure["$el"]}"
        fi
    done

    cd ..
}

function save_file_main_dir {
    base_dir="${crypted_file%/*}"
    cp -r "$decompressed_file" "$base_dir/$decompressed_file"
    # rm "$crypted_file"
}

function print_dirs {
    printf "${BD}Posizioni:\n${NC}"

    cat <<EOF
    -Directory per file temporanei  : '${tmp:-$null_str}'
    -File criptato                  : '${crypted_file:-$null_str}'
    -File struttura                 : '${structure_file:-$null_str}'
EOF
}

function print_commands {
    printf "${BD}Files da aggiungere all'archivio:\n${NC}"

    if [ ${#key_of_command[@]} -eq 0 ]; then
        printf "\t${U}Nessun file da aggiungere. Il file verrà decriptato e decompresso.${NC}\n"
    else
        i=1
        for el in ${!key_of_command[@]}; do
            printf "\t${BD}${i}.${NC} $el\t${BD}-->${NC}\t${structure["$el"]}\n"
            i=$((++i))
        done
    fi
}

function print_vars {
    cat <<EOF
`[ "$show_dirs" == true ] && print_dirs`

`print_commands`

EOF
}


check_asset
read_structure

n_args=$#
if [ $n_args -gt 1 ]; then
    parse_input "$@"
    validate_new_files
else
    check_file "$@"
fi

check_file "$crypted_file"

create_tmp_env
manage_signal
print_vars

decrypt_file
decompress_file

if [ $n_args -gt 1 ]; then
    add_new_file

    compress_file
    crypt_file
else
    save_file_main_dir
fi

on_exit

exit $EXIT_SUCCESS
