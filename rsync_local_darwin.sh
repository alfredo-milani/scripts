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

# Controllo versione shell Bash
declare -r -i MIN_BASH_V=4
declare -r -i BASH_V=${BASH_VERSION:0:1}
if [[ ${BASH_V} -lt ${MIN_BASH_V} ]]; then
	echo "ERRORE: Version bash obsoleta."
	echo "Versione correte: ${BASH_V}"
	echo "Minima versione richiesta: ${MIN_BASH_V}"
	exit ${EXIT_FAILURE}
fi

# Colori
declare -r R='\033[0;31m' # red
declare -r Y='\033[1;33m' # yellow
declare -r G='\033[0;32m' # green
declare -r DG='\033[1;30m' # dark gray
declare -r U='\033[4m' # underlined
declare -r BD='\e[1m' # Bold
declare -r NC='\033[0m' # No Color

# Readonly vars
declare -r -i EXIT_SUCCESS=0
declare -r -i EXIT_FAILURE=1
declare -r -i EXIT_MISSING_BACKUP_RESTORE_FILENAMES=2
declare -r -i EXIT_HELP_REQUESTED=3
declare -r DEV_NULL='/dev/null'
declare -r NULL_STR='NULL'

declare script_name
declare config_file
declare tmp_dir='/tmp'
declare log_file="${NULL_STR}"
declare -A source_dest_backup_restore=()
declare -A source_dest_archive=()

declare print_conf=false
declare ask=true
declare log_on_file=false

# Actions
declare restore_from_backup_op=false


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

	while [[ ${#} -gt 0 ]]; do
		command -v "${1}" &> ${DEV_NULL}
		if [[ ${?} != 0 ]]; then
			msg 'R' "Il tool \"${1}\", necessario per l'esecuzione di questo script, non è presente nel sistema.\nInstallarlo per poter continuare."
			tools_missing=true
		fi
		shift
	done

	[[ "${tools_missing}" == true ]] && return ${EXIT_FAILURE} || return ${EXIT_SUCCESS}
}

function read_filename_to_backup_restore {
	if ! [[ -s "${config_file}" ]]; then
		msg 'R' "ERRORE: Il file \"${config_file}\" sembra non contenere informazioni utili."
		return ${EXIT_FAILURE}
    elif [[ -f "${config_file}" ]]; then
    	local IFS=''
    	local path
        while read -r path; do
        	# BUG: se legge riga del tipo ":/Volumes" considera chiave:"Volumes", value:"null"
        	# invece dovrebbe considerare il contrario
        	local IFS=':'
        	local tmp=(${path}) # crea un array considerando che gli elementi siano separati da IFS
        	[[ -z "${tmp[0]}" ]] && tmp[0]="${NULL_STR}"
        	[[ -z "${tmp[1]}" ]] && tmp[1]="${NULL_STR}"

        	if [[ "${restore_from_backup_op}" == true ]]; then
        		if [[ "${tmp[0]:(-1)}" != '/' ]]; then
        			local IFS='/'
					local tmpp=(${tmp[0]})

					source_dest_backup_restore+=(["${tmp[1]}${tmpp[-1]}"]="${tmp[0]}")
				else
					source_dest_backup_restore+=(["${tmp[1]}"]="${tmp[0]}")
        		fi
        	else
        		source_dest_backup_restore+=(["${tmp[0]}"]="${tmp[1]}")
        	fi
		done <<< $(sed -e 's/[[:space:]]*\[.*]//; s/[[:space:]]*#.*//; /^[[:space:]]*$/d;' "${config_file}")
    else
        msg 'R' "ERRORE: il file utilizzato per l'inizializzazione non è stato trovato! (PATH: ${config_file})"
        return ${EXIT_FAILURE}
    fi
}

function get_response {
	msg "${1}" "${2}\t[ S / N ]"

	local choose
	read -e choose
	if [[ "${choose}" == [sS] ]]; then
		return ${EXIT_SUCCESS}
	else
		return ${EXIT_FAILURE}
	fi
}

# ${1} -> sorgente
# ${2} -> destinazione
function execute_rsync {
	if [[ "${log_on_file}" == true ]]; then
		cat << EOF >> "${log_file}"
################################################################################
###### SINCRONIZZAZIONE ${1} IN ${2}
################################################################################
EOF
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
	local usage
	read -r -d '' usage << EOF
${BD}# Utilizzo${NC}

	${script_name} -[options]

	Wrapper del tool rsync per effetture il backup, restore o l'archiviazione di files.
	Di default i files su cui operare sono letti dal file ${config_file}.
	L'operazione di default è il backup.

${BD}# Options${NC}

	-a ${U}filename${NC} | --archive ${U}filename${NC}
		Archivia il file (o directory) ${U}filename${NC} nella directory specificata.
		Il file verrà eliminato dalla sorgente.

	-c | --print-conf
		Visulizza la configurazione corrente del tool.

	-f ${U}filename${NC} | --conf-file ${U}filename${NC}
		Utilizzo del file ${U}filename${NC} per la lettura delle directories su cui operare.
		Il file può contenere commenti e deve avere il seguente formato:

		/directory/sorgente_uno:/directory/destinazione_uno
		/directory/sorgente_due:/directory/destinazione_due

		Se non viene specificato alcun file verrà cercato il file situato in ${config_file}.

	-l | --log-on-file
		Salva l'output del comando rsync su un file nella directory /tmp.

	-r | --restore-backup
		Permette di effettuare una copia di tutti i files specificati nel file di configurazione, dal disco di
		backup alle postazioni originali.

		NOTA: i paths di destinazione dovranno essere creati a priori.

	-t ${U}directory${NC} | -set-tmp-dir ${U}directory${NC}
		Imposta ${U}directory${NC} come posizione per i files temporanei.

	-y | --yes
		Non chiede il permesso dell'utente prima di eseguire un'operazione.
\n
EOF

	printf "${usage}"
}

function parse_input {
	while [[ ${#} -gt 0 ]]; do
		case "${1}" in
			-a | --archive )
				shift
				local IFS=':'
				local tmp=(${1})
	        	[[ -z "${tmp[0]}" ]] && tmp[0]="${NULL_STR}"
	        	[[ -z "${tmp[1]}" ]] && tmp[1]="${NULL_STR}"

	        	source_dest_archive+=(["${tmp[0]}"]="${tmp[1]}")
	        	shift
				;;

			-c | --print-conf )
				print_conf=true
				shift
				;;

			-f | --conf-file )
				shift
				if [[ -f "${1}" ]]; then
					config_file="${1}"
				else
					msg 'BD' "Non è possibile utilizzare il file \"${1}\". Verrà utilizzato quello di default: ${config_file}"
				fi
				shift
				;;

			-[hH] | -help | -HELP | --help | --HELP )
				usage
				return ${EXIT_HELP_REQUESTED}
				;;

			-l | --log-on-file )
				log_on_file=true
				shift
				;;

			-r | --restore-from-backup )
				msg 'Y' "Controllare se sono stati ripristinati i files nascosti."
				restore_from_backup_op=true
				shift
				;;

			-t | --set-tmp-dir )
				shift
				if [[ -d "${1}" ]]; then
					tmp_dir="${1}"
				else
					msg 'BD' "Directory \"${1}\" non esistente. Verrà utilizzata quella di default: ${tmp_dir}"
				fi				
				shift
				;;

			-y | --yes )
				ask=false
				shift
				;;

			* )
				msg 'R' "Opzione \"${1}\" sconosciuta"
				return ${EXIT_FAILURE}
				;;
		esac
	done
}

# ${1} -> sorgente
# ${2} -> destinazione
function sync_operation {
	if [[ -d "${1}" ]]; then
		if [[ "${1:(-1)}" == '/' ]]; then
			msg 'NC' "\nSincronizzazione ${U}CONTENUTI${NC} direcotry \"${1}\" nella directory \"${2}\""
		else
			msg 'NC' "\nSincronizzazione ${U}INTERA${NC} direcotry \"${1}\" nella directory \"${2}\""
		fi
	else
		msg 'NC' "\nSincronizzazione ${U}FILE${NC} \"${1}\" nella directory \"${2}\""
	fi

	if [[ "${ask}" == true ]] && ! get_response 'Y' "Continuare?"; then
		msg 'Y' "La sincronizzazione di \"${1}\" in \"${2}\" è stata interrotta"
		return ${EXIT_FAILURE}
	fi

	execute_rsync "${1}" "${2}"
	if [[ ${?} == ${EXIT_SUCCESS} ]]; then
		msg 'G' "La sincronizzazione ha avuto esito positivo"
	else
		msg 'R' "Qualcosa è andato storto durante la sincronizzazione"
	fi
}

# ${1} -> sorgente
# ${2} -> destinazione
function archive {
	local rc
	if [[ -d "${1}" ]]; then
		# Archiviazione di tutti i files contenuti nella direcotry sorgente
		if [[ "${1:(-1)}" == '/' ]]; then
			msg 'NC' "\nArchiviazinoe ${U}CONTENUTI${NC} direcotry \"${1}\" nella directory \"${2}\""
			if [[ "${ask}" == true ]] && ! get_response 'Y' "Continuare?"; then
				msg 'Y' "L'archiviazione di \"${1}\" in \"${2}\" è stata interrotta"
				return ${EXIT_FAILURE}
			fi

			mv "${1}"/* "${2}"
			rc=${?}
		# Archiviazione della cartella sorgente		
		else
			msg 'NC' "\nArchiviazione ${U}INTERA${NC} direcotry \"${1}\" nella directory \"${2}\""
			if [[ "${ask}" == true ]] && ! get_response 'Y' "Continuare?"; then
				msg 'Y' "L'archiviazione di \"${1}\" in \"${2}\" è stata interrotta"
				return ${EXIT_FAILURE}
			fi

			mv "${1}" "${2}"
			rc=${?}
		fi
	else
		# Archiviazione file
		msg 'NC' "\Archiviazione ${U}FILE${NC} \"${1}\" nella directory \"${2}\""
		if [[ "${ask}" == true ]] && ! get_response 'Y' "Continuare?"; then
			msg 'Y' "L'archiviazione di \"${1}\" in \"${2}\" è stata interrotta"
			return ${EXIT_FAILURE}
		fi

		mv "${1}" "${2}"
		rc=${?}
	fi
	
	if [[ ${rc} == ${EXIT_SUCCESS} ]]; then
		msg 'G' "L'archivizione ha avuto esito positivo"
	else
		msg 'R' "Qualcosa è andato storto durante l'archiviazione"
	fi
}

function print_configuration {
	local configuration
	read -r -d '' configuration << EOF
${BD}##### Configurazione${NC}
${BD}* Directory per files temporanei:${NC} ${tmp_dir}
$(
	if [[ "${log_on_file}" == true ]] && [[ -n "${log_file}" ]]; then
    	printf "${BD}* File di log:${NC} ${log_file}\n"
    fi

    if [[ ${#source_dest_archive[@]} -ne 0 ]]; then
		msg 'BD' "* Filenames considerati per l'archiviazione:"
		msg 'BD' "\t\tSorgente\t\t\tDestinazione"
		i=1
		for k in "${!source_dest_archive[@]}"; do
			printf "\t${BD}${i}.${NC} ${k} -> ${source_dest_archive["${k}"]}\n"
			i=$((++i))
		done
	fi

	if [[ ${#source_dest_backup_restore[@]} -eq 0 ]]; then
    	msg 'BD' "* Filenames considerati per il $([[ "${restore_from_backup_op}" == true ]] && printf "restore" || printf "backup"): ${NC}${R}${NULL_STR}"
		msg 'BD' "#########################"
    	return ${EXIT_MISSING_BACKUP_RESTORE_FILENAMES}
	else
		msg 'BD' "* Filenames considerati per il $([[ "${restore_from_backup_op}" == true ]] && printf "restore" || printf "backup"): ${NC}- ${config_file}"
		msg 'BD' "\t\tSorgente\t\t\tDestinazione"
		i=1
		for k in "${!source_dest_backup_restore[@]}"; do
			printf "\t${BD}${i}.${NC} ${k} -> ${source_dest_backup_restore["${k}"]}\n"
			i=$((++i))
		done
	fi
)
${BD}#########################${NC}
\n
EOF

	printf "${configuration}"
}

function perform_backup_restore {
	for k in "${!source_dest_backup_restore[@]}"; do
		sync_operation "${k}" "${source_dest_backup_restore["${k}"]}"
	done
}

function perform_archive {
	for k in "${!source_dest_archive[@]}"; do
		archive "${k}" "${source_dest_archive["${k}"]}"
	done
}

function lazy_init_tool_vars {
	script_name="$(basename "${0}")"
	config_file="/usr/local/scripts/.config/${script_name%.*}/asset"
}

function lazy_init_vars {
	[[ "${log_on_file}" == true ]] && log_file="$(mktemp "${tmp_dir}/${script_name%.*}.XXXXXX")"
}

function is_dir_or_file {
	if [[ -d "${1}" || -f "${1}" ]]; then
		return ${EXIT_SUCCESS}
	else
		return ${EXIT_FAILURE}
	fi
}

function validation_check {
	local file_error=false;

	for k in "${!source_dest_backup_restore[@]}"; do
		if ! is_dir_or_file "${k}"; then
			msg 'Y' "Attenzione: il file \"${k}\" non è una directory o un file regolare." && file_error=true
		fi
		if ! is_dir_or_file "${source_dest_backup_restore["${k}"]}"; then
			msg 'Y' "Attenzione: il file \"${source_dest_backup_restore["${k}"]}\" non è una directory o un file regolare." && file_error=true
		fi
	done

	for k in "${!source_dest_archive[@]}"; do
		if ! is_dir_or_file "${k}"; then
			msg 'Y' "Attenzione: il file \"${k}\" non è una directory o un file regolare." && file_error=true
		fi
		if ! is_dir_or_file "${source_dest_archive["${k}"]}"; then
			msg 'Y' "Attenzione: il file \"${source_dest_archive["${k}"]}\" non è una directory o un file regolare." && file_error=true
		fi
	done

	[[ "${file_error}" == true ]] && return ${EXIT_FAILURE} || return ${EXIT_SUCCESS}
}

# ${1} -> main return code
function on_exit {
    if [[ ${1} -ne ${EXIT_HELP_REQUESTED} ]]; then
        if [[ ${1} -eq ${EXIT_SUCCESS} ]]; then
            msg 'G' "Operazioni eseguite con successo."
        else
            msg 'R' "Qualcosa è andato storto."
        fi
    fi
    exit ${1}
}

function main {

	check_tools rsync printf basename mv cp || return ${EXIT_FAILURE}

	lazy_init_tool_vars

	parse_input "${@}" || return ${?}

	lazy_init_vars

	read_filename_to_backup_restore || return ${EXIT_FAILURE}

	if [[ "${print_conf}" == true ]]; then
		print_configuration || return ${?}
	fi

	if ! validation_check; then
		msg 'R' "Validazione input fallita."
		return ${EXIT_FAILURE}
	fi

	perform_archive
	perform_backup_restore

	# Flush buffers in scrittura
	msg 'NC' '\nFlushing buffers...'
	sync

	return ${EXIT_SUCCESS}

}

main "${@}"
on_exit ${?}
