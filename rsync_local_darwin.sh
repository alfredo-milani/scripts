#!/usr/local/bin/bash
# ============================================================================
# Titolo: rsync_local_darwin.sh
# Descrizione: --/--
# Autore: alfredo
# Data: Fri Nov  2 23:19:57 CET 2018
# Licenza: MIT License
# Versione: 1.5.0
# Note: --/--
# Versione bash: 4.4.19(1)-release
# ============================================================================

# Colori
declare -r R='\033[0;31m' # red
declare -r Y='\033[1;33m' # yellow
declare -r G='\033[0;32m' # green
declare -r DG='\033[1;30m' # dark gray
declare -r U='\033[4m' # underlined
declare -r BD='\e[1m' # Bold
declare -r NC='\033[0m' # No Color

# Readonly vars
declare -r -i MIN_BASH_V=4
declare -r -i BASH_V=${BASH_VERSION:0:1}
declare -r -i EXIT_SUCCESS=0
declare -r -i EXIT_FAILURE=1
declare -r -i EXIT_MISSING_BACKUP_FILENAMES=2
declare -r DEV_NULL='/dev/null'
declare -r NULL='null'
declare -r script_name="`basename "$0"`"

if [ ${BASH_V} -lt ${MIN_BASH_V} ]; then
	echo "ERRORE: Version bash obsoleta."
	echo "Versione correte: ${BASH_V}"
	echo "Minima versione richiesta: ${MIN_BASH_V}"
	exit ${EXIT_FAILURE}
fi

declare tmp_dir='/tmp'
declare log_file="${NULL}"
declare config_file="/usr/local/scripts/.config/${script_name%.*}/asset"
declare -A source_dest_backup=()
declare -A source_dest_archive=()

declare print_conf=false
declare ask=true
declare log_on_file=false


function msg {
	case "${1}" in
		G ) printf "${G}${2}${NC}\n" ;;
		Y ) printf "${Y}${2}${NC}\n" ;;
		R ) printf "${R}${2}${NC}\n" ;;
		DG ) printf "${DG}${2}${NC}\n" ;;
		U ) printf "${U}${2}${NC}\n" ;;
		BD ) printf "${BD}${2}${NC}\n" ;;
		* ) printf "${NC}${2}\n" ;;
	esac
}

function check_tools {
	local tools_missing=false

	while [ ${#} -gt 0 ]; do
		command -v "${1}" &> ${DEV_NULL}
		if [ ${?} != 0 ]; then
			msg 'R' "* Il tool ${1}, necessario per l'esecuzione di questo script, non è presente nel sistema.\nInstallarlo per poter continuare."
			tools_missing=true
		fi
		shift
	done

	[ "${tools_missing}" == true ] && return ${EXIT_FAILURE} || return ${EXIT_SUCCESS}
}

function read_filename_to_backup {
	if ! [ -s "${config_file}" ]; then
		msg 'R' "ERRORE: Il file \"${config_file}\" sembra non contenere informazioni utili."
		return ${EXIT_FAILURE}
    elif [ -f "${config_file}" ]; then
    	local path
        while IFS='' read -r path; do
        	# bug: se legge riga del tipo ":/Volumes" considera chiave:"Volumes", value:"null"
        	# invece dovrebbe considerare il contrario
        	IFS=':'
        	local tmp=(${path}) # crea un array considerando che gli elementi siano separati da IFS
        	unset IFS
        	[ -z "${tmp[0]}" ] && tmp[0]="${NULL}"
        	[ -z "${tmp[1]}" ] && tmp[1]="${NULL}"

    		source_dest_backup+=(["${tmp[0]}"]="${tmp[1]}")
		done <<< `sed -e 's/[[:space:]]*\[.*]//; s/[[:space:]]*#.*//; /^[[:space:]]*$/d;' "${config_file}"`
		unset IFS
    else
        msg 'R' "ERRORE: il file utilizzato per l'inizializzazione non è stato trovato! (PATH: ${config_file})"
        return ${EXIT_FAILURE}
    fi
}

function get_response {
	msg "${1}" "${2}\t[ S / N ]"

	local choose
	read -e choose
	if [ "${choose}" == "s" ] || [ "${choose}" == "S" ]; then
		return ${EXIT_SUCCESS}
	else
		return ${EXIT_FAILURE}
	fi
}

function execute_rsync {
	if [ "${log_on_file}" == true ]; then
		echo "SINCRONIZZAZIONE ${1} IN ${2}" >> "${log_file}"
		rsync --delete --progress -avu --no-links 						\
			--exclude=".fseventsd" --exclude=".TemporaryItems" 			\
			--exclude=".Trashes" --exclude=".Spotlight-V100"  			\
			--exclude=".DocumentRevisions-V100" --exclude=".DS_Store" 	\
			--exclude=".PKInstallSandboxManager" "${1}" "${2}" &>> "${log_file}"
		echo -e "\n\n" >> "${log_file}"
	else
		rsync --delete --progress -avu --no-links 						\
			--exclude=".fseventsd" --exclude=".TemporaryItems" 			\
			--exclude=".Trashes" --exclude=".Spotlight-V100"  			\
			--exclude=".DocumentRevisions-V100" --exclude=".DS_Store" 	\
			--exclude=".PKInstallSandboxManager" "${1}" "${2}"
	fi
	
	return ${?}
}

function usage {
	cat <<EOF
# Utilizzo

	$script_name -[options]

# Options

	-a filename | --archive filename
		Archivia il file (o directory) filename nella directory appropriata.
		Il file verrà eliminato dalla sorgente.

	-nask | --not-ask-permission
		Non chiede il permesso dell'utente prima di eseguire un'operazione.

	-c | --print-conf
		Visulizza la configurazione corrente del tool.

	-f filename | --conf-file filename
		Utilizzo del file filename per la lettura delle directory su cui operare.
		Il file può contenere commenti e deve avere il seguente formato:

		/directory/sorgente_uno:/directory/destinazione_uno
		/directory/sorgente_due:/directory/destinazione_due

	-l | --log-on-file
		Salva l'output del comando rsync su un file nella directory /tmp.

	-t directory | -set-tmp-dir directory
		Imposta la directory per i files temporanei.

EOF
}

function parse_input {
	while [ ${#} -gt 0 ]; do
		case "${1}" in
			-a | --archive )
				shift
				IFS=':'
				local tmp=(${1})
				unset IFS
	        	[ -z "${tmp[0]}" ] && tmp[0]="${NULL}"
	        	[ -z "${tmp[1]}" ] && tmp[1]="${NULL}"

	        	source_dest_archive+=(["${tmp[0]}"]="${tmp[1]}")
	        	shift
				;;

			-nask | --ask-permission )
				ask=false
				shift
				;;

			-c | --print-conf )
				print_conf=true
				shift
				;;

			-f | --conf-file )
				shift
				if [ -f "${1}" ]; then
					config_file="${1}"
				else
					echo "Non è possibile utilizzare il file \"${1}\". Verrà utilizzato quello di default: ${config_file}"
				fi
				shift
				;;

			-[hH] | --help | --HELP )
				usage
				return ${EXIT_FAILURE}
				;;

			-l | --log-on-file )
				log_on_file=true
				shift
				;;

			-t | --set-tmp-dir )
				shift
				if [ -d "${1}" ]; then
					tmp_dir="${1}"
				else
					echo "Directory \"${1}\" non esistente. Verrà utilizzata quella di default: ${tmp_dir}"
				fi				
				shift
				;;

			* )
				echo "Opzione \"$1\" sconosciuta"
				return ${EXIT_FAILURE}
				;;
		esac
	done
}

function sync_operation {
	if [ "${1:(-1)}" == '/' ]; then
		msg 'NC' "\nSincronizzazione CONTENUTI direcotry \"${1}\" nella directory \"${2}\""
	else
		msg 'NC' "\nSincronizzazione INTERA direcotry \"${1}\" nella directory \"${2}\""
	fi

	if [ "${ask}" == true ] && ! get_response 'Y' "Continuare?"; then
		msg 'Y' "La sincronizzazione di \"${1}\" in \"${2}\" è stata interrotta"
		return ${EXIT_FAILURE}
	fi

	execute_rsync "${1}" "${2}"
	if [ ${?} == ${EXIT_SUCCESS} ]; then
		msg 'G' "La sincronizzazione ha avuto esito positivo"
	else
		msg 'R' "Qualcosa è andato storto durante la sincronizzazione"
	fi
}

function archive {
	msg 'NC' "\nArchiviazione directory \"${1}\" nella directory \"${2}\"\nAl termine verrà eliminata la directory sorgente"
	if [ "${ask}" == true ] && ! get_response 'Y' "Continuare?"; then
		msg 'Y' "L'archiviazione di \"${1}\" in \"${2}\" è stata interrotta"
		return ${EXIT_FAILURE}
	fi

	mv "${1}" "${2}"
	if [ ${?} == ${EXIT_SUCCESS} ]; then
		msg 'G' "L'archivizione ha avuto esito positivo"
	else
		msg 'R' "Qualcosa è andato storto durante l'archiviazione"
	fi
}

function print_configuration {
	msg 'BD' "##### Configurazione ${NC}- ${config_file}"

	printf "${BD}* Directory files temporanei:${NC} ${tmp_dir}\n"

    if [ "${log_on_file}" == true ] && [ -n "${log_file}" ]; then
    	printf "${BD}* File di log:${NC} ${log_file}\n"
    fi

	if [ ${#source_dest_archive[@]} -eq 0 ]; then
		msg 'BD' "* Filenames considerati per l'archiviazione: ${NC}${NULL}"
	else
		msg 'BD' "* Filenames considerati per l'archiviazione:"
		msg 'BD' "\t\tSorgente\t\t\tDestinazione"
		i=1
		for k in "${!source_dest_archive[@]}"; do
			printf "\t${BD}${i}.${NC} ${k} -> ${source_dest_archive["${k}"]}\n"
			i=$((++i))
		done
	fi

    if [ ${#source_dest_backup[@]} -eq 0 ]; then
    	msg 'BD' "* Filenames considerati per il backup: ${NC}${R}${NULL}"
		msg 'BD' "#####"
    	return ${EXIT_MISSING_BACKUP_FILENAMES}
	else
		msg 'BD' "* Filenames considerati per il backup:"
		msg 'BD' "\t\tSorgente\t\t\tDestinazione"
		i=1
		for k in "${!source_dest_backup[@]}"; do
			printf "\t${BD}${i}.${NC} ${k} -> ${source_dest_backup["${k}"]}\n"
			i=$((++i))
		done
	fi

    msg 'BD' "#####\n"
}

function perform_backup {
	for k in "${!source_dest_backup[@]}"; do
		sync_operation "${k}" "${source_dest_backup["${k}"]}"
	done
}

function perform_archive {
	for k in "${!source_dest_archive[@]}"; do
		archive "${k}" "${source_dest_archive["${k}"]}"
	done
}

function lazy_init_vars {
	[ "${log_on_file}" == true ] && log_file="`mktemp "${tmp_dir}/${script_name%.*}.XXXXXX"`"
}

function validation_check {
	local file_error=false;

	for k in "${!source_dest_backup[@]}"; do
		! [ -d "${k}" ] && msg 'Y' "Attenzione: il file \"${k}\" non esiste." && file_error=true
		! [ -d "${source_dest_backup["${k}"]}" ] && msg 'Y' "Attenzione: il file \"${source_dest_backup["${k}"]}\" non esiste." && file_error=true
	done

	for k in "${!source_dest_archive[@]}"; do
		! [ -d "${k}" ] && msg 'Y' "Attenzione: il file \"${k}\" non esiste." && file_error=true
		! [ -d "${source_dest_archive["${k}"]}" ] && msg 'Y' "Attenzione: il file \"${source_dest_archive["${k}"]}\" non esiste." && file_error=true
	done

	[ "${file_error}" == true ] && return ${EXIT_FAILURE} || return ${EXIT_SUCCESS}
}

function main {

	check_tools rsync read printf [

	parse_input "${@}" || return ${EXIT_FAILURE}

	lazy_init_vars

	read_filename_to_backup || return ${EXIT_FAILURE}

	if [ "${print_conf}" == true ]; then
		print_configuration || return ${?}
	fi

	if ! validation_check; then
		msg 'R' "Non è possibile continuare perché alcuni dei path specificati non esistono."
		return ${EXIT_FAILURE}
	fi

	perform_archive
	perform_backup

	# Flush buffers in scrittura
	sync

	return ${EXIT_SUCCESS}

}

main "${@}"
exit ${?}
