#!/usr/local/bin/bash

# Colori
declare -r R='\033[0;31m' # red
declare -r Y='\033[1;33m' # yellow
declare -r G='\033[0;32m' # green
declare -r DG='\033[1;30m' # dark gray
declare -r U='\033[4m' # underlined
declare -r BD='\e[1m' # Bold
declare -r NC='\033[0m' # No Color

# Exit status
declare -r -i EXIT_SUCCESS=0
declare -r -i EXIT_FAILURE=1
declare -r -i EXIT_HELP_REQUESTED=2
declare -r -i EXIT_NO_ARGS=3
declare -r -i EXIT_MISSING_PERMISSION=4

# Script's constants
declare -r DEV_NULL='/dev/null'
declare -r VOLUMES='/Volumes'
declare -r DEV='/dev'
declare -r TMP='/tmp'
declare script_name
declare script_filename

declare -r URL_NTFS_3G='https://github.com/osxfuse/osxfuse/releases/download/osxfuse-3.8.2/osxfuse-3.8.2.dmg'
declare -r FILENAME_NTFS_3G='osxfuse-3.8.2.dmg'
declare -r TARGET_INSTALLATION="${VOLUMES}/Macintosh HD"
declare -r VOL_NTFS_3G="${VOLUMES}/FUSE for macOS"
declare -r PACKAGE_PATH_NTFS_3G="${VOL_NTFS_3G}/FUSE for macOS.pkg"

# Partizioni su cui operare
declare partitions=()

# Azioni
declare intall_ntfs3g_op=false
declare show_physical_devices_op=false
declare ask=true


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

function check_tools {
	local tools_missing=false

	while [[ ${#} -gt 0 ]]; do
		command -v "${1}" &> "${DEV_NULL}"
		if [[ ${?} != 0 ]]; then
			msg 'R' "Il tool ${1}, necessario per l'esecuzione di questo script, non è presente nel sistema.\nInstallarlo per poter continuare."
			tools_missing=true
		fi
		shift
	done

	[[ "${tools_missing}" == true ]] && return ${EXIT_FAILURE} || return ${EXIT_SUCCESS}
}

function check_root {
	local current_user=$(id -u)
	local root_user=0

    if [[ ${current_user} -ne ${root_user} ]]; then
    	msg 'R' "Questo tool deve essere lanciato con privilegi di amministratore"
        return ${EXIT_MISSING_PERMISSION}
    fi

    return ${EXIT_SUCCESS}
}

function install_ntfs3g {
	if check_tools ntfs-3g; then
		msg 'NC' 'Il tool ntfs-3g è già installato sul sistema'
		return ${EXIT_SUCCESS}
	fi

	msg 'NC' 'Download ed installazione del tool ntfs-3g'
	if [[ "${ask}" == true ]] && ! get_response 'Y' "Continuare?"; then
		msg 'Y' 'Il tool non è stato scaricato o installato'
		return ${EXIT_FAILURE}
	fi

	local current_dir="${PWD}"
	(
		cd "${TMP}"
		curl -LJO "${URL_NTFS_3G}"
		hdiutil mount "${TMP}/${FILENAME_NTFS_3G}" &> "${DEV_NULL}"
		installer -package "${PACKAGE_PATH_NTFS_3G}" -target "${TARGET_INSTALLATION}"
		status_code=${?}
		hdiutil unmount "${VOL_NTFS_3G}" &> "${DEV_NULL}"
		rm "${TMP}/${FILENAME_NTFS_3G}"
		return ${status_code}
	)
	return ${?}
}

function create_support_dir {
	# Creazione directory in /Volumes se non esistono
	[[ ! -d "${1}" ]] && mkdir "${1}"
}

function mount_partition {
	# ${1} -> device
	# ${2} -> mount point
	# Per utilizzare ntfs-3g è necessario installare FUSE (https://osxfuse.github.io/)
	ntfs-3g -o local -o allow_other -o uid=501 -o gid=20 -o umask=037 "${1}" "${2}"
	
	# Controllo se ci sono stati errori
	if [[ ${?} -ne ${EXIT_SUCCESS} ]]; then
		# Controllo se la directory è vuota
		if [[ -z "$(ls -A "${2}")" ]]; then
			msg 'NC' "La directory ${2} non è più necessaria"
			if [[ "${ask}" == true ]] && ! get_response 'Y' "Rimuoverla?"; then
				msg 'NC' "La directory ${2} non è stata rimossa"
				return ${EXIT_FAILURE}
			fi

			rm -rf "${2}"
			msg 'NC' "La directory ${2} è stata rimossa"
		else
			msg 'Y' "La directory ${2} non è più necessaria ma sembra essere non vuota"
			msg 'Y' "Dovrà essere rimossa in modo manualmente"
			open "${VOLUMES}"
		fi
		return ${EXIT_FAILURE}
	fi

	return ${EXIT_SUCCESS}
}

function umount_partition {
	diskutil umount "${1}" &>"${DEV_NULL}"
}

function usage {
	local usage
	read -r -d '' usage << EOF
${BD}### Utilizzo${NC}

	sudo ${script_name} -[options]

	Wrapper utile per montare in lettura e scrittura drives esterni.

${BD}### Options${NC}

	-i | --install-ntfs-3g
		Provvede ad installare il tool ntfs-3g utile a montare il lettura/scruttura i drives.

	-p ${U}parts_id${NC} | --partitions ${U}parts_id${NC}
		Per specificare le partizioni NTFS da montare in lettura/scrittura.
		${U}parts_id${NC} è una delle stringhe contenute nella colonna IDENTIFIER della
		tabella ottenuta utilizzando il flag -s.
		Per montare più di una partizione, la stringa ${U}parts_id${NC} deve contenere i nomi
		delle partizioni separati dal carattere ':'.

	-s | --show-physical-devices
		Mostra i devices fisici estrerni collegati che è possibile montare.

	-y | --yes
		Disabilita interazioni utente.

${BD}### Examples${NC}

	sudo ${script_name} -p "disk5s1"
		Monterà in lettura e scittura la partizione s1 del disco disk5

	sudo ${script_name} -p "disk6s1:disk8s4"
		Monterà in lettura e scrittura le partizioni s1 e s4 rispettivamente dei dischi disk6 e disk8.
		Utilizzare il carattere ':' per separare i nomi delle partizioni da montare.

${BD}### Note${NC}

	E' possibile utilizzare il flag -s per visualizzare l'elenco delle partizioni che è possibile montare nel sistema.
	Basta vedere la colonna IDENTIFIER.
\n
EOF

	printf "${usage}"
}

function show_physical_devices {
	local devices="$(diskutil list external physical)"
	msg 'NC' "Device estrerni collegati al computer:"
	if [[ -z "${devices}" ]]; then
		msg 'NC' "*** Nessun device fisico esterno è collegato al computer ***"
	else
		msg 'NC' "${devices}"
	fi
}

function parse_input {
	if [[ ${#} -eq 0 ]]; then
		msg 'R' "ERRORE: Non è stato specificato alcun argomento."
		usage
		return ${EXIT_NO_ARGS}
	fi

	while [[ ${#} -gt 0 ]]; do
		case "${1}" in
			-[hH] | -help | -HELP | --help | --HELP )
				usage
				return ${EXIT_HELP_REQUESTED}
				;;

			-i | --install-ntfs-3g )
				install_ntfs3g_op=true
				shift
				;;

			-p | --partitions )
				shift
				local IFS=':'
				partitions=(${1})
				shift
				;;

			-s | --show-physical-devices )
				show_physical_devices_op=true
				shift
				;;

			-y | --yes )
				ask=false
				shift
				;;

			* )
				msg 'R' "ERRORE: Opzione \"${1}\" sconosciuta"
				return ${EXIT_FAILURE}
				;;
		esac
	done

	return ${EXIT_SUCCESS}
}

function check_partition {
	if ! diskutil info "${DEV}/${1}" &> "${DEV_NULL}"; then
		msg 'Y' "ATTENZIONE: La partizione <${partitions[${i}]}> non esiste e non sarà considerata"
		return ${EXIT_FAILURE}
	fi

	# Controllo che sia effettivamente una partizione e non un disco
	# Prendo la parte destra della stringa, a destra della sequenza "disk"
	# Divido la stringa restante (del tipo XXXsYYY) in un array del tipo ARR=("XXX", "YYY")
	# Contrllo se esiste il secondo elemento dell'array. Se non esiste vuol dire che non
	# è una partizione
	local IFS='s'
	local tmp_array
	read -r -a tmp_array <<< "${1#disk*}"
	if ! [[ "${#tmp_array[@]}" -eq 2 ]]; then
		msg 'R' "Formato errato della partizione
Le partizioni hanno il seguente formato: diskXXXsYYY
Input ricevuto: ${1}"
		return ${EXIT_FAILURE}
	fi

	return ${EXIT_SUCCESS}
}

function mount_partitions {
	for ((i = 0; i < ${#partitions[@]}; ++i)); do
		check_partition "${partitions[${i}]}" || continue

		mount_point="${VOLUMES}/${partitions[${i}]}"
		dev_to_mount="${DEV}/${partitions[${i}]}"

		umount_partition "${dev_to_mount}"
		create_support_dir "${mount_point}"
		mount_partition "${dev_to_mount}" "${mount_point}"
	done
}

function lazy_init_tool_vars {
	script_name="$(basename "${0}")"
 	script_filename="${0}"
}

# ${1} -> main return code
function on_exit {
    if [[ ${1} -ne ${EXIT_HELP_REQUESTED} && ${1} -ne ${EXIT_MISSING_PERMISSION} && ${1} -ne ${EXIT_NO_ARGS} ]]; then
        if [[ ${1} -eq ${EXIT_SUCCESS} ]]; then
            msg 'G' "Operazioni eseguite con successo."
        else
            msg 'R' "Qualcosa è andato storto."
        fi
    fi
    exit ${1}
}

function main {
	check_root || return ${?}

	lazy_init_tool_vars

	check_tools diskutil ntfs-3g open mkdir basename \
	curl hdiutil installer rm || return ${?}

	parse_input "${@}" || return ${?}

	if [[ "${install_ntfs3g_op}" == true ]]; then
		install_ntfs3g || return ${?}
	fi

	if [[ "${show_physical_devices_op}" == true ]]; then
		show_physical_devices || return ${?}
	fi

	if [[ ${#partitions} -gt 0 ]]; then
		mount_partitions || return ${?}
	fi

	return ${EXIT_SUCCESS}
}

main "${@}"
on_exit ${?}
