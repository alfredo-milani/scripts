#!/bin/bash

path=.;
remote=origin;
branch=master;
message;


if [ $# == 1 ]; then
    git commit -a -m $1;
    git push $remote $branch;
    exit 0;
fi

while [ $# -gt 1 ]; do
    case "$1" in
        -[bB] )
            shift;
            branch=$1;
            shift;
            ;;

        -[rR] )
            shift;
            remote=$1;
            shift;
            ;;

        -[mM] )
            shift;
            message=$1;
            shift;
            ;;


######################### TODO ######################


        * )
            echo "Comando non riconosciuto";
            exit 1;
            ;;
    esac
done

# se non ci sono argomenti
echo "Usa il flag -h per ulteriori informazioni";
echo "`basename $0` deve avere in ingresso almeno il messaggio di commit";
exit 1;
