#!/bin/bash
# ============================================================================

# Titolo:           crypt_script.sh
# Descrizione:      Script che esegue comandi criptati che si autoelimina al termine
# Autore:           Alfredo Milani
# Data:             mer 19 lug 2017, 01.03.06, CEST
# Licenza:          MIT License
# Versione:         0.0.1
# Note:             --/--
# Versione bash:    4.4.12(1)-release
# ============================================================================



echo "Password di prova: \"4444\"";
echo "";


printf "Digita la password:\t";
read -s psw;
printf "\n\n";


cmd_encoded='-----BEGIN PGP MESSAGE-----

jA0EBwMC9x2XY0rzwXvh0qQBztLf4y2+acFCcM41dnIy/NMrWLp81Uh844Nk8BC8
Jukt0Wn3Yh2xlDM+lHpDSdmRAamwLTOo+ib1S0FkqTKXfZCuwkPciU3T+QgTjRP/
dei1bfsyfTIjqH7TVzv7eE6P7frC6sKnglTpquRap8X0nvtSiRltS4hvAFsWs6CZ
0sz5E32ureaF9bvX3tKWoP9Lpo7DrXrkctJxry+sJeJ/i9dOgA==
=sc3i
-----END PGP MESSAGE-----';

: <<'COMM'
chiede automaticamente all'utente di inserire la password ma fallisce se viene
invocato con sudo o se nel testo criptato c'è un comando che richiede particolari privilegi
# cmd_decoded="`gpg 2> /dev/null <<< $cmd_encoded`";
COMM

# il flag --batch e --passphrase sono utilizzati per passare la passphrase direttamente da riga di comando
cmd_decoded=`gpg --batch --passphrase "$psw" 2> /dev/null <<< $cmd_encoded`;

[ $? != 0 ] && printf "Errore durante la decodifica\n" && exit 1;

# se remove viene impostata su vero (0) allora lo script sarà cancellato alla fine dell'esecuzione
# le variabili devono essere passate all'interno del comando perché all'esecuzione di bash viene lanciato
#   un nuovo processo bash con un environ diverso
bash -c "declare -r remove=1;
declare -r script_name=`realpath $0`;
$cmd_decoded";
