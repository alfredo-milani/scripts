#!/bin/bash
declare -r name_desktop_entry="rambox.desktop"
declare -r name_icon="icon.png"
declare path_rambox=""
declare version_rambox=""

declare -r EXIT_SUCCESS=0
declare -r EXIT_FAILURE=1
declare -r _dev_shm_="/dev/shm"
declare -r null="/dev/null"
declare -r sys_desktop_entry_path="/usr/share/applications"
declare -r relative_hdd_icon_path="./resources/$name_icon"
declare -r response="\n[y=accetta / others=rifiuta]\t"



function usage {
    cat <<EOF

# Sintassi

    ./`basename "$0"` PATH

# Descrizione

    Questo script permette di creare una desktop entry per il tool RamBox

# Argomenti

    PATH
        Rappresenta il path dove è locato la root del tool Rambox

EOF

    exit $EXIT_SUCCESS
}

function parse_input {
    while [ $# -gt 0 ]; do
        case "$1" in
            -[hH] | --[hH] | -[help] | --[HELP] )
                usage
                ;;

            * )
                shift
                ;;
        esac
    done
}

function validate_input {
    if ! [ -d "$1" ]; then
        printf "Attenzione! Bisogna specificare un path di installazione valido per il tool Rambox!\nUsa il flag -h per maggiori informazioni\n"
        exit $EXIT_FAILURE
    else
        path_rambox="`realpath -e "$1"`"
        version_rambox="${path_rambox#*-}"
    fi
}

function check_root {
    if [ `id -u` -ne 0 ]; then
        sudo "$0" $@
        exit $?
    fi
}

function create_desktop_entry {
    printf "Creare una desktop entry del tool di messaggistica Rambox?$response"
    read choise
    if [ "$choise" == "y" ]; then

        tee <<EOF "$sys_desktop_entry_path/$name_desktop_entry" 1> $null
[Desktop Entry]
Version=$version_rambox
Name=Rambox
Exec=$path_rambox/rambox %U
Terminal=false
Icon=$path_rambox/$name_icon
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml_xml;image/webp;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;
EOF

        if [ $? -eq 0 ]; then
            printf "Operazione completata con successo.\n"
            printf "Riavvia il Desktop Environment per vedere i cambiamenti.\n"
        else
            printf "Operazione fallita.\n"
        fi

    else
        printf "Desktop entry non creata.\n"
    fi
}

function create_icon {
    printf "Creare icona per l'applicazione Rambox?$response"
    read choise
    if [ "$choise" == "y" ]; then
        cp "$relative_hdd_icon_path" "$path_rambox"

        if [ $? -eq 0 ]; then
            printf "Operazione completata con successo.\n"
            printf "Riavvia il Desktop Environment per vedere i cambiamenti.\n"
        else
            printf "Operazione fallita.\n"
        fi

        chmod 0777 "$path_rambox/$name_icon"
    else
        printf "Icona non creata.\n"
    fi
}

function main {
    check_root "$@"

    parse_input "$@"

    validate_input "$@"

    create_desktop_entry

    create_icon

    exit ${EXIT_SUCCESS}
}


main "$@"
