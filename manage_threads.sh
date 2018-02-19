#!/bin/bash
# ============================================================================

# Titolo:           manage_threads.sh
# Descrizione:      Gestisce il numero di threads attivi del sistema
# Autore:           Alfredo Milani  (alfredo.milani.94@gmail.com)
# Data:             gio 20 lug 2017, 18.45.46, CEST
# Licenza:          MIT License
# Versione:         1.5.4
# Note:             Utilizzare il flag -h per avere informazioni sulle modalità d'uso
# Versione bash:    4.4.12(1)-release
# ============================================================================



# presenza del tool zenity nel sistema
declare zen;
# dimensioni alert dialog
declare -r dialog_width=600;
declare -r dialog_height=20;
# timeout read
declare -r read_to=45;
# exit status
declare -r EXIT_SUCCESS=0;
declare -r EXIT_FAILURE=5;
# redir trash output
declare -r null=/dev/null;
# path di sistema contenente i files necessari
declare -r path=/sys/devices/system/cpu;
# operazione da performare
declare -i operation;
declare OP='?';
# numero TOTALI di threads presenti nel sistema
# tmp=(`lscpu | egrep 'CPU\(s\):'`);
# threads=${tmp[1]};
# oppure:
declare -r threads=`nproc --all`;
# nproc restituisce il numero di cpu ATTIVE
# 	si potrebbe anche elaborare meglio la stringa ottenuta dal comando lscpu
# varrà sempre metà del valore iniziale
declare -r threads_online=`nproc`;
# numero di threads di default
declare -r threads_default=2;
# numero di threads da gestire; input dell'utente
declare -i threads_to_manage=$threads_default;
# threads utili --> threads attivi
declare -i threads_available=$((threads - threads_online));



# uso
function usage {
	cat << EOF
# Utilizzo

	`realpath -e $0` [threads to manage] [operations]

# Threads to manage

	n :  numero di threads su cui operare (default n=2)

# Operations

	n + :  attiva n threads
	n - :  disattiva n threads
	n / :  disabilita threads_tot/n threads attivi del sistema
	  / :  come sopra ma con n=2
	 // :  porta il sistema al numero di default (n=2) di threads attivi
	n ° :  abilita threads_tot*n threads del sistema
	  ° :  come sopra ma con n=2
	 °° :  attiva tutti threads del sistema


# Esempi

	$ ./`basename $0` + 3	# attiva 3 threads del sistema
	$ ./`basename $0` / 3 	# se ad esempio il sistema ha 12 threads attivi, ne verranno disattivati 4

EOF
	exit $EXIT_SUCCESS;
}

# stampa una stringa con output su CLI e su GUI
# se il primo argomento è 0 --> stampa una scritta di errore
function print_str {
	reason="\t\t*** $2 ***\n";
	if [ "$1" == "0" ]; then
		printf "$reason" 1>&2;

		[ $zen == 0 ] &&
		zenity --width=$dialog_width --height=$dialog_height --error --text="$reason" &> $null;

		return $EXIT_FAILURE;
	fi

	printf "$1" && return $EXIT_SUCCESS;
}

# alert dialog con richiesta interazione utente
function decision {
	question="\t\t $1 \n";
	if [ $zen == 0 ]; then
		zenity --width=$dialog_width --height=$dialog_height --question --timeout $read_to --text="$question" &> $null &&
		return $EXIT_SUCCESS;
		return $EXIT_FAILURE;
	else
		printf "$question";
		printf "[y=procedi / others=annulla]\t";
		read -t $read_to choise || return $EXIT_FAILURE;

		[ "$choise" == "y" ] && return $EXIT_SUCCESS ||
		return $EXIT_FAILURE;
	fi
}

# scelta operazione
function get_op {
	case "$OP" in
		'+' | '°' | '°°' ) return 1 ;;
		'-' | '/' | '//' ) return 0 ;;
		* ) return -1 ;;
	esac
}

# gestione operazioni '+' e '*'
function enable_threads {
	get_op;
	operation=$?;
	[ $operation == -1 ] && return $EXIT_FAILURE;

	# l'indice parte da 1 perché la cpu0 non può essere
	# disabilitata per problemi di stabilità e sicurezza
	for ((j = 1; j < $threads && $threads_to_manage > 0; ++j)); do
		status_file=$path'/cpu'$j'/online';

		! [ -f "$status_file" ] &&
		! print_str 0 "Funzionalità non supportata dalla CPU (cpu$j)" &&
		return $EXIT_FAILURE;

		cpu_status=`cat $status_file`;
		if [ $cpu_status == 0 ]; then
			(echo $operation > $status_file) &> $null;

			[ $? != 0 ] &&
			! print_str 0 "Permessi non sufficienti per eseguire lo script" &&
			return $EXIT_FAILURE;

			threads_to_manage=$((threads_to_manage - 1));
		fi
	done
	return $EXIT_SUCCESS;
}

# gestione operazioni '-' e '/'
function disable_threads {
	get_op;
	operation=$?;
	[ $operation == -1 ] && return $EXIT_FAILURE;

	# l'indice parte da 1 perché la cpu0 non può essere
	# disabilitata per problemi di stabilità e sicurezza
	for ((j = $((threads - 1)); j > 0 && $threads_to_manage > 0; --j)); do
		status_file=$path'/cpu'$j'/online';

		! [ -f "$status_file" ] &&
		! print_str 0 "Funzionalità non supportata dalla CPU (cpu$j)" &&
		return $EXIT_FAILURE;

		cpu_status=`cat $status_file`;
		if [ $cpu_status == 1 ]; then
			(echo $operation > $status_file) &> $null;

			[ $? != 0 ] &&
			! print_str 0 "Permessi non sufficienti per eseguire lo script" &&
			return $EXIT_FAILURE;

			threads_to_manage=$((threads_to_manage - 1));
		fi
	done
	return $EXIT_SUCCESS;
}



# controllo presenza tools necessari per l'operazione
which egrep nproc 1> $null;
[ $? != 0 ] && ! print_str 0 "Tool egrep o nproc non presenti nel sistema" && exit $EXIT_FAILURE;
which zenity 1> $null;
zen=$?;
# verifica numero argomenti ricevuti
(
([ $# -gt 2 ] && ! print_str 0 "Troppi argomenti ricevuti!") ||
([ $# -lt 1 ] && ! print_str 0 "Argomenti mancanti!")
) && usage;



# parsing input utente
while [ $# -gt 0 ]; do
	case "$1" in
		'+' | '°' | '°°' ) [ "$OP" == "?" ] && OP=$1 && shift && continue ;;

		'-' | '/' | '//' ) [ "$OP" == "?" ] && OP=$1 && shift && continue ;;

		[0-9] ) threads_to_manage=$1 && shift ;;

		-[hH] | --[hH] | -[hH][eE][lL][pP] | --[hH][eE][lL][pP] ) usage ;;

		* )	! print_str 0 "Sintassi errata!" && usage ;;
	esac
done

# verifica presenza operazione
[ "$OP" == "?" ] && ! print_str 0 "Operazione non specificata." && exit $EXIT_FAILURE;

# gestione operazioni
case "$OP" in
	'+' )
		# controllo sul numero di threads da gestire
		[ $threads_to_manage -gt $threads_available ] &&
		! print_str 0 "Errore! Non è possibile attivare più di $threads_available threads." &&
		exit $EXIT_FAILURE;

		enable_threads || exit $EXIT_FAILURE;
		;;

	'°' )
		# controllo sul numero di threads da gestire
		threads_to_manage=$((threads_online * threads_to_manage));
		[ $threads_to_manage -gt $threads_available ] &&
		! print_str 0 "Errore! Non è possibile attivare più di $threads_available threads." &&
		exit $EXIT_FAILURE;

		enable_threads || exit $EXIT_FAILURE;
		;;

	'°°' )
		# numero di threads da gestire
		threads_to_manage=$threads_available;

		enable_threads || exit $EXIT_FAILURE;
		;;

	'-' )
		# controllo sul numero di threads da gestire
		[ $threads_to_manage -ge $threads_online ] &&
		! print_str 0 "Errore! Non è possibile disattivare più di $threads_online threads." &&
		exit $EXIT_FAILURE;

		# verifica che ci sia un numero sufficiente di threads da poter gestire
		if [ $((threads_online - threads_to_manage)) -lt 2 ]; then
			decision "Attenzione: numero di threads online=$threads_online;
			            numero di threads da disattivare=$threads_to_manage.\n\t\t Procedere comunque?" ||
			exit $EXIT_FAILURE;
		fi


		disable_threads || exit $EXIT_FAILURE;
		;;

	'/' )
		# controllo sul numero di threads da gestire
		threads_to_manage=$((threads_online / threads_to_manage));
		[ $threads_to_manage -ge $threads_online ] &&
		! print_str 0 "Errore! Non è possibile disattivare più di $threads_online threads." &&
		exit $EXIT_FAILURE;

		# verifica che ci sia un numero sufficiente di threads da poter gestire
		threads_to_use=$((threads_online - threads_to_manage));
		if [ $threads_to_use -ge 0 ] && [ $threads_to_use -lt 2 ]; then
			decision "Attenzione: numero di threads online=$threads_online;
			            numero di threads da disattivare=$threads_to_manage.\n\t\t Procedere comunque?" ||
			exit $EXIT_FAILURE;
		fi

		disable_threads || exit $EXIT_FAILURE;
		;;

	'//' )
		# numero di threads da gestire
		threads_to_manage=$((threads_online - threads_default));

		# verifica che ci sia un numero sufficiente di threads da poter gestire
		if [ $threads_to_manage -lt 0 ]; then
			if decision "Attenzione: numero di threads online=$threads_online.\n\t\t Vuoi portare il numero di threads attivi a $threads_default?"; then
				threads_to_manage=1; OP='+';
				enable_threads && exit $EXIT_SUCCESS ||
				exit $EXIT_FAILURE;
			fi
		fi

		disable_threads || exit $EXIT_FAILURE;
		;;
esac

# successo
exit $EXIT_SUCCESS;
