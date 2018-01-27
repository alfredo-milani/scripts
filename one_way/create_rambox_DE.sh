#!/bin/bash

declare -r EXIT_SUCCESS=0;
declare -r EXIT_FAILURE=1;
declare -r _dev_shm_="/dev/shm";
declare -r null="/dev/null";
declare -r response="\n[y=accetta / others=rifiuta]\t";
declare -r sys_desktop_entry_path="/usr/share/applications";
declare -r relative_hdd_icon_path="./resources/rambox.png";
declare -r name_desktop_entry="rambox.desktop";



# verifica che sia presente il path di installazione del tool Rambox
function preliminar_check {
    if [ $# == 0 ]; then
        printf "Errore! Richiesto path di installazione di Rambox.\n\ncreate_rambox_DE.sh ./path_tool_rambox\n";
        exit ${EXIT_FAILURE};
    elif ! [ -d "$1" ]; then
        printf "Errore! path --> $1 <-- non esistene!\nUscita.\n";
        exit ${EXIT_FAILURE};
    elif ! [ -f "$1/Rambox" ]; then
        printf "Errore! Path --> $1 <-- errato.\nImpossibile trovare il tool rambox nel path specificato\n";
        exit ${EXIT_FAILURE};
    elif ! [ -d "$sys_desktop_entry_path" ]; then
        printf "Errore interno! path --> $sys_desktop_entry_path <-- non esistene!\n";
        exit ${EXIT_FAILURE};
    fi
}



# Questo script crea una desktop entry del tool di messaggistica Rambox
printf "Creare una desktop entry del tool di messaggistica Rambox?$response";
read choise;
if [ "$choise" == "y" ]; then
    preliminar_check $1;

    result=0;
    sudo cp ${relative_hdd_icon_path} $1 &> ${null};
    if [ $? == 1 ]; then
        sudo cp ${relative_hdd_icon_path} $1;
        sudo chmod 0777 "$1/rambox.png";
    fi
    result=$(($result + $?));

    realpath_rambox=`realpath -e $1`;
    rambox_desktop_entry="[Desktop Entry]\nVersion=1.0\nName=Rambox\n\nExec=$realpath_rambox/rambox %U\nTerminal=false\nIcon=$realpath_rambox/rambox.png\nType=Application\nCategories=Network;WebBrowser;\nMimeType=text/html;text/xml;application/xhtml_xml;image/webp;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;";
    echo -e ${rambox_desktop_entry} > ${_dev_shm_}/${name_desktop_entry};
    sudo mv ${_dev_shm_}/${name_desktop_entry} ${sys_desktop_entry_path}/${name_desktop_entry};
    result=$(($result + $?));

    [ ${result} == 0 ] && printf "Operazione effettuata con successo\n";
    [ ${result} != 0 ] && printf "Operazione fallita. C'è stato un errore imprevisto\n";
else
    printf "Nessuna modifica apportata.\nUscita.\n";
fi



# successo
exit ${EXIT_SUCCESS};
