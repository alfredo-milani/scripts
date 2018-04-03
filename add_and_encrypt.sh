#!/bin/bash
# ============================================================================
# Titolo: add_and_encrypt.sh
# Descrizione: Decripta, estrae, agginge e cripta il file specificato
# Autore: alfredo
# Data: mer 21 feb 2018, 19.24.21, CET
# Licenza: MIT License
# Versione: 1.0.0
# Note: --/--
# Versione bash: 4.4.12(1)-release
# ============================================================================



##### ##################################
##### Inizio controllo preliminare #####
bash_shell="/bin/bash"
if [ "$bash_shell" != "${SHELL: -${#bash_shell}}" ]; then
    printf "\nLo script corrente deve essere eseguito da una shell bash e NON sh!\n"
    exit 1
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
declare -r dir_conf="$HOME/.config/${script_name%.*}"
declare -r config_file="$dir_conf/asset"
declare show_dirs=false
declare only_tmp=false
declare same_psw=false

# NOTA: declare, flag -A non saupportato in bash version <= 3.x
declare -A structure=()
declare -A key_of_command=()
declare tmp_base="/dev/shm"
declare tmp_dir=""
declare structure_file=""
declare crypted_file=""
declare decrypted_file=""
declare decompressed_file=""
declare ext=""
declare password=""
declare cipher_type="aes128"


function manage_signal {
    trap "on_exit" SIGINT SIGKILL SIGTERM SIGUSR1 SIGUSR2
}

function get_asset {
    if [ -f "$config_file" ]; then
        while IFS='=' read -r key value; do
            case "$key" in
                structure_file )  structure_file="$value" ;;
            esac
        done <<< `sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' "$config_file"`
    else
        printf "${R}Attenzione il file utilizzato per l'inizializzazione non è stato trovato! (PATH: $config_file)\n${NC}"
        on_exit
        exit $EXIT_FAILURE
    fi
}

function check_asset {
    if ! [ -f "$config_file" ]; then
        # Primo avvio
        mkdir -p "$dir_conf"
        cat <<EOF > "$config_file"
[gerarchia directory]
structure_file=
EOF

        printf "${G}${U}Inizializzazione interna completata.\n${NC}"
    else
        get_asset
    fi
}

function load_structure {
    if [ -f "$structure_file" ]; then
        while IFS='=' read -r key value; do
            structure+=(["$key"]="$value")
        done <<< `sed -e 's/[[:space:]]*#.*// ; /^[[:space:]]*$/d' "$structure_file"`
    else
        printf "${R}Bisogna specificare un file per inizializzare la struttura dell'archivio compresso!\nUtilizzare il flag -h per maggiori informazioni\n${NC}"
        on_exit
        exit $EXIT_FAILURE
    fi
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
            key_of_command+=(["$key"]="`custom_realpath "$value"`")
        fi
    done
}

function usage {
    cat <<EOF

`printf "${BD}# Sintassi${NC}"`

    ./`basename "$0"` [-args] FILE

`printf "${BD}# Descrizione${NC}"`

    `basename "$0"` è un tool che serve per aggiornare un archivio criptato compresso specificato da FILE.
    Se verrà passato solo FILE come argomento allora verrà decriptato ed estratto.

`printf "${BD}# Argomenti${NC}"`

    -arg | -ARG
        mostra gli argomenti contenuti nel file di configurazione

    -only-tmp | -ONLY-TMP
        salva il file ottenuto nella directory temporanea

    -h | -H
        visualizza questo aiuto

    -same-psw | -SAME-PSW
        utilizza la stessa password usata per decriptare il vecchio archivio

    -sd | -SD
        mostra le directory utilizzate

    -structure file | -STRUCTURE file
        specifica un file per configurare la gerarchia di directory dell'archivio compresso

    -tmp directory | -TMP directory
        specifica directory per files temporanei

    -val | -VAL
        mostra flags disponibili per accedere alla directory del file compresso e i corrispondenti valori

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

            -only-tmp | -ONLY-TMP)
                only_tmp=true
                shift
                ;;

            -same-psw | -SAME-PSW )
                same_psw=true
                shift
                ;;

            -sd | -SD )
                show_dirs=true
                shift
                ;;

            -structure | -STRUCTURE )
                shift
                if [ -f "$1" ]; then
                    # specifica file per configurare la gerarchia di directory all'interno dell'archivio compresso
                    structure_file="`custom_realpath "$1"`"
                    # TODO: on MacOS sed -i flags ritorna un errore
                    sed -i "s:^structure_file=.*:structure_file=$structure_file:g" "$config_file"
                    printf "${G}Il file $structure_file è stato impostato correttamente come file per ottenere la struttura dell'archivio compresso.\nOra è possibile utilizzare i flags specificati in questo file per operare sull'archivio compresso\n${NC}"
                    exit $EXIT_SUCCESS
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
                [ -d "$1" ] && tmp_base="`custom_realpath "$1"`" ||
                printf "${Y}Directory: $1 non esistente; verrà usata quella di default ($tmp_base)\n${NC}"
                shift
                ;;

            -val | -VAL )
                [ "${#structure[@]}" -eq 0 ] && load_structure
                printf "${BD}\nValori contenuti nel file di configurazione:\n${NC}"
                i=1
                for el in ${!structure[@]}; do
                    printf "${BD}${i}.${NC} $el\t${BD}-->${NC}\t${structure["$el"]}\n"
                    i=$((++i))
                done
                exit $EXIT_SUCCESS
                ;;

            * )
                [ "${#structure[@]}" -eq 0 ] && load_structure
                get_operation_on_archive "$1" "$2" && shift && shift && continue

                if [ ${#crypted_file} != 0 ]; then
                    printf "${Y}Il file criptato è già stato aggiunto ($crypted_file).\nIl file $1 non sarà considerato.\nContinuare comunque? [Yes / No]\n${NC}"

                    read choise
                    if [ "$choise" != "Yes" ]; then
                        printf "Uscita.\n"
                        exit $EXIT_SUCCESS
                    fi
                else
                    check_file "$1"
                fi
                shift
                ;;
        esac
    done
}

function check_file {
    if [ ${#1} -eq 0 ]; then
        printf "${R}Non è stato specificato alcun file su cui operare.\n${NC}"
        on_exit
        exit $EXIT_FAILURE
    elif [ -f "$1" ]; then
        crypted_file="`custom_realpath "$1"`"
    else
        printf "${R}Il file \'$1\' non esiste.\n${NC}"
        on_exit
        exit $EXIT_FAILURE
    fi
}

function create_tmp_env {
    # creazione directory temporanea
    tmp_dir=`mktemp -d -p "$tmp_base"`
    cd "$tmp_dir"
}

function remove_tmp {
    rm -rf "$tmp_dir"
}

function on_exit {
    remove_tmp
}

function decrypt_file {
    # decripta
    cp "$crypted_file" "$tmp_dir"

    if [ "$same_psw" == true ]; then
        printf "${G}Digita la password per decriptare il file\nNOTA: questa password verrà usata anche per criptare il nuovo archivio\n${NC}"
        read -s password
        gpg --batch --passphrase "$password" "`basename "$crypted_file"`" &> $NULL
    else
        gpg "`basename "$crypted_file"`" &> $NULL
    fi

    if [ $? != 0 ]; then
        printf "${R}Errore durante la decodifica.\n${NC}"
        on_exit
        exit $EXIT_FAILURE
    fi
    tmp_crypted_file="`basename "$crypted_file"`"
    decrypted_file="${tmp_crypted_file%.*}"
}

function encrypt_file {
    if [ "$same_psw" == true ]; then
        gpg --batch --passphrase "$password" --yes -ca --cipher-algo "$cipher_type" -o "$crypted_file" "$decrypted_file"
    else
        printf "${G}${U}Inserisci la chiave di cifratura per il nuovo archivio\n${NC}"
        gpg --yes -ca --cipher-algo "$cipher_type" -o "$crypted_file" "$decrypted_file"
    fi
}

function decompress_file {
    ext="${decrypted_file##*.}"
    case "$ext" in
        tar )
            tar -xf "$decrypted_file" -C "$tmp_dir" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            ;;

        xz )
            tar -xvf "$decrypted_file" -C "$tmp_dir" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            decompressed_file="${decompressed_file%.*}"
            ;;

        gz )
            tar -zxvf "$decrypted_file" -C "$tmp_dir" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            decompressed_file="${decompressed_file%.*}"
            ;;

        bz2 )
            tar -jxvf "$decrypted_file" -C "$tmp_dir" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            decompressed_file="${decompressed_file%.*}"
            ;;

        zip )
            unzip "$decrypted_file" -d "$tmp_dir" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            ;;

        7z )
            7z x "$decrypted_file" -o"$tmp_dir" &> $NULL
            decompressed_file="${decrypted_file%.*}"
            ;;

        * )
                printf "${R}Formato sconosciuto: \'$ext\'. Estrazione non riuscita.\n${NC}"
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
            printf "${R}Formato sconosciuto: \'$ext\'. Estrazione non riuscita.\n${NC}"
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
    if [ "$only_tmp" == true ]; then
        cp -r "$decompressed_file" "$tmp_base"
    else
        cp -r "$decompressed_file" "${crypted_file%/*}"
        # rm "$crypted_file"
    fi
}

function print_dirs {
    printf "${BD}Posizioni:\n${NC}"

    cat <<EOF
    -Directory per file temporanei  : '${tmp_dir:-$null_str}'
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

# NOTA: in MacOS non c'è il tool realpath
function custom_realpath {
    [[ $1 = /* ]] && echo "$1" || echo "$PWD/${1#./}"
}

function check_tools {
	tools_missing=false

	while [ $# -gt 0 ]; do
		command -v "$1" &> $NULL
		if [ $? != 0 ]; then
			printf "${R}* Il tool $1, necessario per l'esecuzione di qeusto script, non è presente nel sistema.\nInstallarlo per poter continuare.\n\n${NC}"
			tools_missing=true
		fi
		shift
	done

	if [ "$tools_missing" == true ]; then
		return $EXIT_FAILURE
	else
		return $EXIT_SUCCESS
	fi
}


function main {
	! check_tools declare sed read printf exit trap cat exit shift echo gpg cp && exit $EXIT_FAILURE
	(
		check_tools 7z &> $NULL ||
		check_tools zip &> $NULL ||
		check_tools tar &> $NULL ||
		check_tools xz &> $NULL ||
		check_tools gz &> $NULL ||
		check_tools bz2 &> $NULL
	) || (
		printf "${R}Non è stato trovato alcun tool per estrarre i file (7z, zip, tar, xz, gz, bz2).\nUscita...\n\n${NC}" &&
		exit $EXIT_FAILURE
	)

    manage_signal
    check_asset
    parse_input "$@"
    [ "${#structure[@]}" -eq 0 ] && load_structure

    [ $# -gt 1 ] && validate_new_files

    check_file "$crypted_file"

    create_tmp_env
    print_vars

    decrypt_file
    decompress_file

    if [ ${#key_of_command[@]} -gt 0 ]; then
        add_new_file

        compress_file
        encrypt_file
    else
        save_file_main_dir
    fi

    on_exit

    exit $EXIT_SUCCESS
}


main "$@"
