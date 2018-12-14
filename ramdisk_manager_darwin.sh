#!/usr/local/bin/bash
# ============================================================================
# Titolo: manage_ramdisk.sh
# Descrizione: Provvede all'inizializzazione e gestione di un ramdisk
# Autore: Alfredo Milani (alfredo.milani.94@gmail.com)
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
declare -r -i EXIT_HELP_REQUESTED=7
declare -r -i EXIT_NO_ARGS=8

# Readonly vars
declare -r LOG='/var/log/ramdisk_manager.log'
declare -r OS_MACOS='darwin'
declare -r OS_V="${OSTYPE}"
declare -r DEV_NULL='/dev/null'

# Setup's paths
declare -r scripts_sys_path='/Library/Scripts/UtilityScripts'
declare -r launch_daemons_sys_path='/System/Library/LaunchDaemons'
declare download_path='/Users/%s/Downloads'
declare daemon_name='it.%s.ramdisk.manager'

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
declare unload_service_op=false
declare create_link_Download_op=false
declare check_deps_op=true
declare create_trash_op=false


# Versione cutom del tool realpath
function rp_cstm {
    [[ "${1}" = /* ]] && echo "${1}" || echo "${PWD}/${1#./}"
}

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
	if [[ "${OS_V}" != "${OS_MACOS}"* ]]; then
		msg 'R' "ERRORE: Questo tool può essere lanciato solo da sistemi MacOSX."
		return ${EXIT_FAILURE}
	fi
}

function check_root {
	local current_user=$(id -u)
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
	if ! [[ -d "${launch_daemons_sys_path}" ]]; then
		msg 'R' "ERRORE: La directory di sistema ${launch_daemons_sys_path} non esiste."
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

	local plist_file_content
	read -r -d '' plist_file_content << EOF
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
			<string>${ramdisk_name}</string>
			<string>${ramdisk_mount_point}</string>
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
	# Creazione file plist nella directory di sistema
	tee <<< "${plist_file_content}" "${plist_file}" 1> "${DEV_NULL}"

	# Cambio proprietario e gruppo
	chown root:wheel "${plist_file}"
	# Imposto il caricamento automatico all'avvio del sistema
	launchctl load -w "${plist_file}"
}

function unload_script {
	# Eliminazione script
	rm -f "${scripts_sys_path}/${script_name}"
}

function unload_plist {
	# Disabilitazione caricamento automatico
	launchctl unload -w "${launch_daemons_sys_path}/${daemon_name}" &> "${DEV_NULL}" || return ${EXIT_FAILURE}
	# Rimozione file *.plist
	rm -f "${launch_daemons_sys_path}/${daemon_name}"
}

function unload_service {
	unload_script
	unload_plist
}

function setup_ramdisk {
	create_script
	create_and_launch_plist
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

# ${1} -> ramdisk name
# ${2} -> ramdisk mount point
# ${3} -> ramdisk size in MB
function create_ramdisk {
	local disk="$(basename $(hdiutil attach -nomount "ram://$((${3} * 1024 * 2))") )"
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

    newfs_apfs -v "${1}" "${disk}s1"
    if [[ ${?} -ne ${EXIT_SUCCESS} ]]; then
		msg 'R' "ERRORE: newfs_apfs - creazione APFS sul disco ${disk}s1"
		on_create_ramdisk_error "${disk}"
		return ${EXIT_NEWFSAPFS_ERR}
	fi

    diskutil mount -mountPoint "${2}" "${1}"
    if [[ ${?} -ne ${EXIT_SUCCESS} ]]; then
		msg 'R' "ERRORE: diskutil - creazione punto di mount ramdisk"
		on_create_ramdisk_error "${disk}"
		return ${EXIT_DISKUTIL_MOUNT_ERR}
	fi

    return ${EXIT_SUCCESS}
}

function create_links {
	local linkdir='Links'
	for file in "${links_to_create[@]}"; do
		# Creo la directory nel ramdisk
		mkdir -p "${ramdisk_mount_point}/${linkdir}/${file}"

		# Controllo se il file da sostituire con un link sia già un link e 
		# in caso negativo elimino la directory e creo il link
		if ! [[ -e "${file}" && "$(rp_cstm "${file}")" == "${ramdisk_mount_point}/${linkdir}/${file}" ]]; then
		 	rm -rf "${file}"
			ln -s "${ramdisk_mount_point}/${linkdir}/${file}" "${file}"
		fi
	done

	return ${EXIT_SUCCESS}
}

function usage {
	local usage
	read -r -d '' usage << EOF
${BD}### Utilizzo${NC}
	
	${script_name} -[options]

	Questo script può essere usato per configurare un ramdisk creato in modo 
	automatico all'avvio del sistema.

${BD}### Options${NC}

	-c ${U}ramdisk_name${NC} ${U}ramdisk_mount_point${NC} ${U}ramdisk_size_MB${NC} | --create-ramdisk ${U}ramdisk_name${NC} ${U}ramdisk_mount_point${NC} ${U}ramdisk_size_MB${NC}
		Inizializza un ramdisk creando un disco di nome ${U}ramdisk_name${NC} di dimensione ${U}ramdisk_size_MB${NC} che
		verrà montato in ${U}ramdisk_mount_point${NC}.

	-d | --create-link-to-Download
		Crea un link nella direcotry download che punta al punto di mount del ramdisk creato.

	-f ${U}file_list${NC} | --filenames-to-create ${U}file_list${NC}
		Una volta creato il ramdisk elimina le directory specificate e crea un link
		simbolico delle stesse all'interno del ramdisk.
		Il parametro ${U}file_list${NC} deve avere il seguente formato:

		"/path_uno/directory_uno:/path_due/directory_due/:/path_tre/directory_tre"

	-nask | --not-ask-permission
		Non chiede il permesso dell'utente prima di eseguire un'operazione.

	-p ${U}username${NC} | --set-user-profile ${U}username${NC}
		Specifica lo username che si vuole utilizzare.
		Questa opzione è utile per impostare correttamente i path che vengono usati con il flag -d e -su.

	-sd | --skip-deps-check
		Disabilitazione controllo dipendenze tools ausiliari.

	-su ${U}ramdisk_name${NC} ${U}ramdisk_mount_point${NC} ${U}ramdisk_size_MB${NC} | --setup-ramdisk-at-boot ${U}ramdisk_name${NC} ${U}ramdisk_mount_point${NC} ${U}ramdisk_size_MB${NC}
		Inizializza i files necessari per la creazione del ramdisk all'avvio del sistema.
		Il ramdisk verrà inizializzato creando un disco di nome ${U}ramdisk_name${NC} di dimensione ${U}ramdisk_size_MB${NC} che
		verrà montato in ${U}ramdisk_mount_point${NC}.

	-t | --create-trash
		Crea la directory "Trash" all'interno della directory dove è stato montato il ramdisk

	-u | --unload-script
		Permette di non caricare più lo script all'avvio del sistema.

${BD}### Esempio di utilizzo${NC}

	$ sudo ${script_name} -t -d -p user -f "/Library/Caches:/Library/Logs:/Users/alfredo/Library/Caches" -su Ramdisk /Volumes/Ramdisk 1000

		Crea un file *.plist nella directory ${launch_daemons_sys_path} e copia questo script nella posizione ${scripts_sys_path}.
		Così facendo verrà creato un volume di nome "Ramdisk", con punto di mount in /Volumes/Ramdisk e di dimensione 1000 MB, inoltre verrà
		creato un link simbolico del punto di mount nella directory /Users/user/Download/ e verrà creato una directory di nome "Trash"
		all'interno del Ramdisk.
		Le directory /Library/Caches, /Library/Logs e /Users/alfredo/Library/Caches saranno sostituite con dei link simbolici che puntano a
		directories all'interno del ramdisk, quindi in questo caso saranno eliminate le directory /Library/Caches, /Library/Logs e
		/Users/alfredo/Library/Caches, saranno create le direcotries /Volumes/Ramdisk/Links/Library/Caches, /Volumes/Ramdisk/Links/Library/Logs e
		/Volumes/Ramdisk/Links/Users/alfredo/Library/Caches e sarà creato un link simbolico delle directories contenute in /Volumes/Ramdisk/Links/
		nella posizione di origine (specificate dal flag -f).

	$ ${script_name} -c Ramdisk /Volumes/Ramdisk 1000

		Crea un un volume di nome "Ramdisk", con punto di mount in /Volumes/Ramdisk e di dimensione 1000 MB.
\n
EOF

	printf "${usage}"
}

function parse_input {
	if [[ ${#} -eq 0 ]]; then
		msg 'R' "ERRORE: Non è stato specificato alcun argomento."
		usage
		return ${EXIT_NO_ARGS}
	fi

	while [[ ${#} -gt 0 ]]; do
		case "${1}" in
			-c | --create-ramdisk )
				shift
				ramdisk_name="${1}"
				shift
				ramdisk_mount_point="${1}"
				shift
				ramdisk_size="${1}"
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
				return ${EXIT_HELP_REQUESTED}
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

			-sd | --skip-deps-check )
				check_deps_op=false
				shift
				;;

			-su | --setup-ramdisk-at-boot )
				shift
				ramdisk_name="${1}"
				shift
				ramdisk_mount_point="${1}"
				shift
				ramdisk_size="${1}"
				setup_ramdisk_op=true;
				shift
				;;

			-t | --create-trash )
				create_trash_op=true
				shift
				;;

			-u | --unload-script )
				unload_service_op=true
				shift
				;;

			* )
				msg 'R' "ERRORE: Opzione \"${1}\" non valida."
				return ${EXIT_FAILURE}
				;;
		esac
	done

	return ${EXIT_SUCCESS}
}

function validate_input {
	# Non possono essere specificate entrambi i flags contemporaneamente
	if [[ "${create_ramdisk_op}" == true && "${setup_ramdisk_op}" == true ]]; then
		msg 'R' "ERRORE: Non è possibile specificare contemporaneamente i flags -c e -su."
		return ${EXIT_FAILURE}
	fi

	# Informazioni necessarie sia per creare un ramdisk che per il setup all'avvio del sistema
	if [[ ${ramdisk_size} -le 0 ]]; then
		msg 'R' "ERRORE: La dimensione del ramdisk non può essere <= 0"
		return ${EXIT_RAMDISK_SYNTAX_ERR}
	elif [[ -z "${ramdisk_name}" ]]; then
		msg 'R' "ERRORE: Il nome del ramdisk non può essere vuoto"
		return ${EXIT_RAMDISK_SYNTAX_ERR}
	elif [[ -z "${ramdisk_mount_point}" ]]; then
		msg 'R' "ERRORE: Il punto di mount del ramdisk non può essere vuoto"
		return ${EXIT_RAMDISK_SYNTAX_ERR}

	elif [[ "${create_ramdisk_op}" == true && ! -d "${ramdisk_mount_point}" ]]; then
		msg 'NC' "Creazione directory su cui montare il ramdisk - \"${ramdisk_mount_point}\""
		if [[ "${ask}" == true ]] && ! get_response 'Y' "Continuare?"; then
			msg 'Y' "La crezione del punto di mount non è stata effettuata"
			return ${EXIT_FAILURE}
		fi
		mkdir -p "${ramdisk_mount_point}" || return ${EXIT_FAILURE}
	fi

	# Necessario specificare lo username per risolvere correttamente i paths
	if [[ "${create_link_Download_op}" == true || "${setup_ramdisk_op}" == true ]] && [[ -z "${username}" ]]; then		
		msg 'R' "ERRORE: Il campo username NON può essere vuoto se si vuole creare un link nella directory Download o creare il ramdisk all'avvio del sistema.\nUtilizzare il flag -p username."
		return ${EXIT_FAILURE}
	fi

	return ${EXIT_SUCCESS}
}

function lazy_init_tool_vars {
	script_name="$(basename "${0}")"
 	script_filename="${0}"
}

function lazy_init_vars {
	download_path="$(printf "${download_path}" "${username}")"
	daemon_name="$(printf "${daemon_name}" "${username}")"
}

function create_link_Download {
	ln -s "${ramdisk_mount_point}" "${download_path}"
	return ${EXIT_SUCCESS}
}

function create_trash {
	local dirname='Trash'
	mkdir "${ramdisk_mount_point}/${dirname}"
	return ${EXIT_SUCCESS}
}

# ${1} -> main return code
function on_exit {
	if [[ ${1} -ne ${EXIT_HELP_REQUESTED} && ${1} -ne ${EXIT_NO_ARGS} ]]; then
		if [[ ${1} -eq ${EXIT_SUCCESS} ]]; then
			msg 'G' "Operazioni eseguite con successo."
		else
			msg 'R' "Qualcosa è andato storto."
		fi
	fi
	exit ${1}
}

# Utilizzare questi flags per creare il file *.plist, lo script in una 
# posizione di sistema e caricare lo script all'avvio del sistema
# -t
# -d
# -p alfredo
# -f "/Library/Caches:/Library/Logs:/System/Library/Caches:/System/Library/CacheDelete:/private/tmp:/private/var/log:/private/var/tmp:/Users/alfredo/Library/Logs:/Users/alfredo/Library/Caches:/Users/alfredo/.cache"
# -su Ramdisk /Volumes/Ramdisk 1000
function main {

	# Controllo dipendenze
	if [[ "${check_deps_op}" == true ]]; then
		# Controllo se il sistema operativo è MacOSX
		check_os || return ${EXIT_FAILURE}
		# Controllo tools non builtin
		check_tools open read touch basename mv rm ln \
		cp tee hdiutil diskutil newfs_apfs mkdir || return ${EXIT_FAILURE}
	fi

	# Inizializzazione variabili del tool
	lazy_init_tool_vars

	# Parsing input utente
	parse_input "${@}" || return ${?}
	# Validazione input
	validate_input || return ${?}

	# Inizializzazione variabili
	lazy_init_vars

	# Rimozione script e file *.plist per la creazione automatica del ramdisk ad avvio sistema
	if [[ "${unload_service_op}" == true ]]; then
		check_root || return ${?}
		unload_service || return ${?}
	fi

	# Creazione ramdisk
	if [[ "${create_ramdisk_op}" == true ]]; then
		create_ramdisk "${ramdisk_name}" "${ramdisk_mount_point}" ${ramdisk_size} || return ${?}

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
			create_link_Download || return ${?}
		fi

	# Setup script e file *.plist per la creazione automatica di un ramdisk ad avvio di sistema
	elif [[ "${setup_ramdisk_op}" == true ]]; then
		check_root || return ${?}
		setup_ramdisk || return ${?}
	fi

	return ${EXIT_SUCCESS}

}

main "${@}"
on_exit ${?}
