#!/usr/local/bin/bash
# ============================================================================
# Titolo: manage_ramdisk.sh
# Descrizione: Provvede all'inizializzazione e gestione di un ramdisk
# Autore: alfredo (alfredo.milani.94@gmail.com)
# Data: Gio 20 Set 2018 12:40:51 CEST
# Licenza: MIT License
# Versione: 1.0.0
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

# Exit status
declare -r -i EXIT_SUCCESS=0
declare -r -i EXIT_FAILURE=1
declare -r -i EXIT_HDIUTIL_ERR=2
declare -r -i EXIT_DISKUTIL_PART_ERR=3
declare -r -i EXIT_NEWFSAPFS_ERR=4
declare -r -i EXIT_DISKUTIL_MOUNT_ERR=5
declare -r -i EXIT_RAMDISK_SYNTAX_ERR=6

# Readonly vars
declare -r LOG='/var/log/ramdisk_manager.log'
declare -r OS_MACOS='darwin'
declare -r OS_V="${OSTYPE}"
declare -r DEV_NULL='/dev/null'

# Setup's paths
declare download_path='/Users/%s/Downloads'
declare daemon_name='it.%s.ramdisk.manager'
declare -r scripts_sys_path='/Library/Scripts/UtilityScripts'
declare -r launch_daemons_sys_path='/System/Library/LaunchDaemons'

declare username
declare script_name
declare script_filename

declare links_to_create=()
declare -i ramdisk_size
declare ramdisk_name
declare ramdisk_mount_point

# Azioni possibili
declare ask=true
declare create_ramdisk_op=false
declare setup_ramdisk_op=false
declare unload_script_op=false
declare create_link_Download_op=false
declare check_deps_op=true
declare create_trash_op=false


function log {
	printf "${1}\n" >> "${LOG}"
}

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

function check_os {
	if ! [[ "${OS_V}" == "${OS_MACOS}"* ]]; then
		msg 'R' "ERRORE: Questo tool può essere lanciato solo da sistemi MacOSX."
		return ${EXIT_FAILURE}
	fi
}

function check_root {
	local current_user=`id -u`
	local root_user=0

    if [[ ${current_user} -ne ${root_user} ]]; then
    	msg 'R' "Questo tool deve essere lanciato con privilegi di amministratore"
        return ${EXIT_FAILURE}
    fi

    return ${EXIT_SUCCESS}
}

function create_script {
	# Controllo esistenza directory
	if ! [[ -d "${scripts_sys_path}" ]]; then
		msg 'Y' "La directory ${scripts_sys_path} non esiste."
		if [[ "${ask}" == true ]] && ! get_response 'Y' "Crearla?"; then
			msg 'Y' "La directory non è stata creata."
			return ${EXIT_FAILURE}
		fi
		# Creazione directory
		mkdir -p "${scripts_sys_path}"
	fi

	# Controllo se lo script esiste già nella directory di destinazione
	if [[ -f "${scripts_sys_path}/${script_name}" ]]; then
		msg 'Y' "Il file ${scripts_sys_path}/${script_name} esiste."
		if [[ "${ask}" == true ]] && ! get_response 'Y' "Sovrascriverlo?"; then
			msg 'Y' "Il file non è stato sovrascitto."
			return ${EXIT_FAILURE}
		fi
	fi

	# Copia script in una posizione di sistema
	if ! cp "${script_filename}" "${scripts_sys_path}"; then
		msg 'R' "Errore durante la copia del file ${script_filename} in ${scripts_sys_path}/${script_name}"
		return ${EXIT_FAILURE}
	fi

	# Cambio proprietario e gruppo
	chown root:wheel "${scripts_sys_path}/${script_name}"
	# Impostazione permessi di esecuzione
	chmod +x "${scripts_sys_path}/${script_name}"
}

function create_and_launch_plist {
	if [[ -z "${username}" ]]; then
		msg 'R' "ERRORE: Il campo username NON può essere vuoto se si vuole fare il setup per l'avvio automatico del ramdisk.\nUtilizzare il flag -p username."
		return ${EXIT_FAILURE}
	fi

	local plist_file="${launch_daemons_sys_path}/${daemon_name}.plist"

	# Controllo se il file plist esiste già nella directory di destinazione
	if [[ -f "${plist_file}" ]]; then
		msg 'Y' "Il file ${plist_file} esiste."
		if [[ "${ask}" == true ]] && ! get_response 'Y' "Sovrascriverlo?"; then
			msg 'Y' "Il file non è stato sovrascitto."
			return ${EXIT_FAILURE}
		fi
		# Unload vecchio file *.plist
		launchctl unload -w "${plist_file}" &> "${DEV_NULL}"
	fi

	# Creazione file plist nella directory di sistema
	tee <<EOF "${plist_file}" 1> "${DEV_NULL}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
	<dict>
		<key>UserName</key>
	    <string>root</string>
	    <key>GroupName</key>
	    <string>wheel</string>
	    <key>InitGroups</key>
	    <true/>

	    <key>RunAtLoad</key>
	    <true/>
	    <key>KeepAlive</key>
	    <false/>
		<key>LaunchOnlyOnce</key>
		<true/>

		<key>Label</key>
		<string>${daemon_name}</string>

		<key>Program</key>
		<string>${scripts_sys_path}/${script_name}</string>

		<key>ProgramArguments</key>
		<array>
			<string>${scripts_sys_path}/${script_name}</string>
			<string>--create-ramdisk</string>
			<string>--ramdisk-mount-point</string>
			<string>${ramdisk_mount_point}</string>
			<string>--ramdisk-name</string>
			<string>${ramdisk_name}</string>
			<string>--ramdisk-size</string>
			<string>${ramdisk_size}</string>
			<string>--not-ask-permission</string>
			<string>--skip-deps-check</string>
			$(
				if [[ "${create_link_Download_op}" == true ]]; then
					printf '\t\t\t<string>%s</string>\n' '--set-user-profile'
					printf '\t\t\t<string>%s</string>\n' "${username}"
					printf '\t\t\t<string>%s</string>\n' '--create-link-in-Download'
				fi
				if [[ "${create_trash_op}" == true ]]; then
					printf '\t\t\t<string>%s</string>\n' '--create-trash'
				fi
				if [[ "${#links_to_create[@]}" -gt 0 ]]; then
					local IFS=':'
					printf '\t\t\t<string>%s</string>\n' '--filenames-to-create'
					printf '\t\t\t<string>%s</string>\n' "${links_to_create[*]}"
				fi
			)
		</array>
	</dict>
</plist>
EOF

	# Cambio proprietario e gruppo
	chown root:wheel "${plist_file}"
	# Imposto il caricamento automatico all'avvio del sistema
	launchctl load -w "${plist_file}"
}

function unload_script {
	# Disabilitazione caricamento automatico
	launchctl unload -w "${launch_daemons_sys_path}/${daemon_name}" &> "${DEV_NULL}" || return ${EXIT_FAILURE}
	# Rimozione file *.plist
	rm -f "${launch_daemons_sys_path}/${daemon_name}"
	# Eliminazione script
	rm -f "${scripts_sys_path}/${script_name}"
}

function setup_ramdisk {
	create_script
	create_and_launch_plist
}

function create_mount_point {
	if ! [[ -d "${1}" ]]; then
		msg 'NC' "Creazione directory su cui montare il ramdisk - \"${1}\""
		if [[ "${ask}" == true ]] && ! get_response 'Y' "Continuare?"; then
			msg 'Y' "La crezione del punto di mount non è stata effettuata"
			return ${EXIT_FAILURE}
		fi

		mkdir -p "${1}" || return ${EXIT_FAILURE}
	fi

	return ${EXIT_SUCCESS}
}

# ${1} -> disco da smontare ed espellere (e.g. disk7)
function on_create_ramdisk_error {
	msg 'NC' "Rimozione disco \"${1}\""
	if [[ "${ask}" == true ]] && ! get_response 'Y' "Continuare?"; then
		msg 'Y' "La rimozione non è stata effettuata"
		return ${EXIT_FAILURE}
	fi

	local dev='/dev'
	diskutil umountDisk "${dev}/${1}"
	diskutil eject "${dev}/${1}"

	return ${EXIT_SUCCESS}
}

# ${1} -> size ramdisk in MB
# ${2} -> ramdisk name
# ${3} -> ramdisk mount point
function create_ramdisk {
	if [[ ${1} -le 0 ]]; then
		msg 'R' "ERRORE: La dimensione del ramdisk non può essere <= 0"
		return ${EXIT_RAMDISK_SYNTAX_ERR}
	elif [[ -z "${2}" ]]; then
		msg 'R' "ERRORE: Il nome del ramdisk non può essere vuoto"
		return ${EXIT_RAMDISK_SYNTAX_ERR}
	elif [[ -z "${3}" ]]; then
		msg 'R' "ERRORE: Il punto di mount del ramdisk non può essere vuoto"
		return ${EXIT_RAMDISK_SYNTAX_ERR}
	fi

	create_mount_point "${3}" || return ${EXIT_FAILURE}

	local disk="$(basename $(hdiutil attach -nomount "ram://$((${1} * 1024 * 2))") )"
	if [[ -z "${disk}" ]]; then
		msg 'R' "ERRORE: hdiutil - creazione disco per il ramdisk"
		return ${EXIT_HDIUTIL_ERR}
	fi

    diskutil partitionDisk "${disk}" GPT APFS %noformat% R
    if [[ ${?} -ne ${EXIT_SUCCESS} ]]; then
		msg 'R' "ERRORE: diskutil - partizionamento disco ${disk}"
		on_create_ramdisk_error "${disk}"
		return ${EXIT_DISKUTIL_PART_ERR}
	fi

    newfs_apfs -v "${2}" "${disk}s1"
    if [[ ${?} -ne ${EXIT_SUCCESS} ]]; then
		msg 'R' "ERRORE: newfs_apfs - creazione APFS sul disco ${disk}s1"
		on_create_ramdisk_error "${disk}"
		return ${EXIT_NEWFSAPFS_ERR}
	fi

    diskutil mount -mountPoint "${3}" "${2}"
    if [[ ${?} -ne ${EXIT_SUCCESS} ]]; then
		msg 'R' "ERRORE: diskutil - creazione punto di mount ramdisk"
		on_create_ramdisk_error "${disk}"
		return ${EXIT_DISKUTIL_MOUNT_ERR}
	fi

    return ${EXIT_SUCCESS}
}

function create_links {
	if ! [[ -d "${ramdisk_mount_point}" ]]; then
		msg 'Y' "Il punto di mount (${ramdisk_mount_point}) sembra non esistere."
		return ${EXIT_FAILURE}
	fi

	local linkdir='Links'
	for file in "${links_to_create[@]}"; do
		# Creo la directory nel ramdisk
		mkdir -p "${ramdisk_mount_point}/${linkdir}/${file}"

		# Controllo se il file da sostituire con un link sia già un link e 
		# in caso negativo elimino la directory e creo il link
		if ! [[ -L "${file}" && -d "${file}" ]]; then
			rm -rf "${file}"
			ln -s "${ramdisk_mount_point}/${linkdir}/${file}" "${file}"
		fi

	done
}

function create_link_Download {
	if [[ -d "${ramdisk_mount_point}" ]]; then
		ln -s "${ramdisk_mount_point}" "${download_path}"
	else
		msg 'R' "ERRORE: Il punto di mount non esiste quindi non è possibile creare il link simbolico."
		return ${EXIT_FAILURE}
	fi
}

function usage {
	cat <<EOF
`printf "${BD}# Utilizzo${NC}"`
	
	${script_name} -[options]

	Questo script può essere usato per configurare un ramdisk creato in modo 
	automatico all'avvio del sistema.

`printf "${BD}# Options${NC}"`

	-c | --create-ramdisk
		Crea il ramdisk utilizzando le informazioni specificate attraverso i flags -f, -m, -n, -s.

	-d | --create-link-to-Download
		Crea un link nella direcotry download che punta al punto di mount del ramdisk creato.

	-f file_list | --filenames-to-create file_list
		Una volta creato il ramdisk elimina le directory specificate e crea un link
		simbolico delle stesse all'interno del ramdisk.
		Il parametro deve avere il seguente formato:

		/directory/sorgente_uno:/directory/destinazione_uno
		/directory/sorgente_due:/directory/destinazione_due

	-m directory | --ramdisk-mount-point directory
		Specifica la directory nella quale verrà creato e montato il ramdisk.

	-n ramdisk_name | --ramdisk-name ramdisk_name
		Specifica il nome del ramdisk che dovrà essere creato.

	-nask | --not-ask-permission
		Non chiede il permesso dell'utente prima di eseguire un'operazione.

	-p | --set-user-profile
		Specifica lo username che si vuole utilizzare.
		Questa opzione è utile per impostare correttamente i path che vengono usati con il flag -d e -su.

	-s size_MB | --ramdisk-size size_MB
		Specifica la dimensione del ramdisk in Mega Bytes.

	-sd | --skip-deps-check
		Disabilitazione controllo dipendenze tools ausiliari.

	-su | --setup-ramdisk-at-boot
		Inizializza i files necessari per la creazione del ramdisk all'avvio del sistema utilizzando 
		le informazioni specificate attraverso i flags -f, -m, -n, -s.

	-t | --create-trash
		Crea la directory "Trash" all'interno della directory dove è stato montato il ramdisk

	-u | --unload-script
		Permette di non caricare più lo script all'avvio del sistema.

EOF
}

function parse_input {
	while [[ ${#} -gt 0 ]]; do
		case "${1}" in
			-c | --create-ramdisk )
				create_ramdisk_op=true
				shift
				;;

			-d | --create-link-in-Download )
				create_link_Download_op=true
				shift
				;;

			-f | --filenames-to-create )
				shift
				local IFS=':'
				links_to_create=(${1})
	        	shift
				;;

			-[hH] | --help | --HELP )
				usage
				return ${EXIT_FAILURE}
				;;

			-m | --ramdisk-mount-point )
				shift
				ramdisk_mount_point="${1}"
				shift
				;;

			-n | --ramdisk-name )
				shift
				ramdisk_name="${1}"
				shift
				;;

			-nask | --not-ask-permission )
				ask=false
				shift
				;;

			-p | --set-user-profile )
				shift
				username="${1}"
				shift
				;;

			-s | --ramdisk-size )
				shift
				ramdisk_size=${1}
				shift
				;;

			-sd | --skip-deps-check )
				check_deps_op=false
				shift
				;;

			-su | --setup-ramdisk-at-boot )
				setup_ramdisk_op=true;
				shift
				;;

			-t | --create-trash )
				create_trash_op=true
				shift
				;;

			-u | --unload-script )
				unload_script_op=true
				shift
				;;

			* )
				msg 'R' "ERRORE: Opzione \"${1}\" non valida."
				return ${EXIT_FAILURE}
				;;
		esac
	done
}

function validate_input {
	if [[ "${create_ramdisk_op}" == true && "${setup_ramdisk_op}" == true ]]; then
		msg 'R' "ERRORE: Non è possibile specificare contemporaneamente i flags -c e -su."
		return ${EXIT_FAILURE}
	fi
}

function lazy_init_tool_vars {
	script_name="`basename "${0}"`"
 	script_filename="${0}"
}

function lazy_init_vars {
	download_path="`printf "${download_path}" "${username}"`"
	daemon_name="`printf "${daemon_name}" "${username}"`"
}

function create_trash {
	local dirname='Trash'
	if mkdir "${ramdisk_mount_point}/${dirname}"; then
		return ${EXIT_SUCCESS}
	else
		return ${EXIT_FAILURE}
	fi
}

# Utilizzare questi flags per creare il file *.plist, lo script in una 
# posizione di sistema e caricare lo script all'avvio del sistema
# -t
# -d
# -f "/Library/Caches:/Library/Logs:/System/Library/Caches:/System/Library/CacheDelete:/private/tmp:/private/var/log:/private/var/tmp:/Users/alfredo/Library/Logs:/Users/alfredo/Library/Caches:/Users/alfredo/.cache"
# -s 1000
# -m /Volumes/Ramdisk
# -n Ramdisk
# -su
function main {

	# Controllo dipendenze
	if [[ "${check_deps_op}" == true ]]; then
		check_os || return ${EXIT_FAILURE}
		check_tools printf open read test basename mv rm ln cp tee hdiutil diskutil newfs_apfs mkdir || return ${EXIT_FAILURE}
	fi

	# Inizializzazione variabili del tool
	lazy_init_tool_vars

	# Parsing input utente
	parse_input "${@}" || return ${EXIT_FAILURE}
	validate_input || return ${EXIT_FAILURE}

	# Inizializzazione variabili
	lazy_init_vars

	# Rimozione script e file *.plist per la creazione automatica del ramdisk ad avvio sistema
	if [[ "${unload_script_op}" == true ]]; then
		check_root || return ${?}
		unload_script || return ${EXIT_FAILURE}
	fi

	# Creazione ramdisk
	if [[ "${create_ramdisk_op}" == true ]]; then
		create_ramdisk ${ramdisk_size} "${ramdisk_name}" "${ramdisk_mount_point}" || return ${?}

		# Creazione links all'interno del ramdisk
		if [[ "${#links_to_create[@]}" -gt 0 ]]; then
			create_links || return ${?}
		fi

		# Creazione directory Trash all'interno del ramdisk
		if [[ "${create_trash_op}" == true ]]; then
			create_trash || return ${?}
		fi

		# Creazione link del ramdisk all'interno della directory Download
		if [[ "${create_link_Download_op}" == true ]]; then
			if [[ -z "${username}" ]]; then
				msg 'Y' "Il campo username NON può essere vuoto se si vuole creare un link nella directory Download.\nUtilizzare il flag -p username."
			else
				create_link_Download
			fi
		fi

	# Setup script e file *.plist per la creazione automatica di un ramdisk ad avvio di sistema
	elif [[ "${setup_ramdisk_op}" == true ]]; then
		check_root || return ${?}
		setup_ramdisk || return ${?}
	fi

}

main "${@}"
exit ${?}
