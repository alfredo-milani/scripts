#!/usr/local/bin/bash
# ============================================================================
# Titolo: rsync_local_darwin.sh
# Descrizione: --/--
# Autore: alfredo
# Data: Fri Nov  2 23:19:57 CET 2018
# Licenza: MIT License
# Versione: 1.0.0
# Note: --/--
# Versione bash: 4.4.19(1)-release
# ============================================================================

declare -r -i EXIT_SUCCESS=0
declare -r -i EXIT_FAILURE=1
declare -r DEV_NULL='/dev/null'
declare -r current_script_name="`basename "$0"`"
declare -r mount_script='/usr/local/scripts/mount_drive_darwin.sh'
declare -r tmp_dir='/tmp'
declare -r log_file=''
declare ask=false

# Colori
declare -r R='\033[0;31m' # red
declare -r Y='\033[1;33m' # yellow
declare -r G='\033[0;32m' # green
declare -r NC='\033[0m' # No Color

declare log_on_file=false
declare b_Alfredo=false
declare b_Chrome=false
declare b_Projects=false
declare -A a_files=()

declare backup_vol='Data Backup'
declare -r Alfredo='Alfredo'
declare -r Chrome='Preferiti_Chrome'
declare -r Projects='Projects'

declare source_files='/Volumes/Data'
declare -r source_files_Alfredo="$source_files/$Alfredo/"
declare -r source_files_Chrome="$source_files/$Chrome/"
declare -r source_files_Projects="$source_files/$Projects/"

### TODO al posto di /Volumes/%s/Main -> %s/Main
declare backup_main='/Volumes/%s/Main'
declare backup_main_Alfredo=''
declare backup_main_Chrome=''
declare backup_main_Projects=''

declare backup_archive='/Volumes/%s/Archivio'

declare backup_other='Volumes/%s/Other'



function msg {
	case "$1" in
		G ) printf "${G}$2${NC}\n" ;;
		Y ) printf "${Y}$2${NC}\n" ;;
		R ) printf "${R}$2${NC}\n" ;;
		* ) printf "${NC}$2\n" ;;
	esac
}

function get_response {
	msg "$1" "$2\t[ S / N ]"

	read -e choose
	if [ "$choose" == "s" ] || [ "$choose" == "S" ]; then
		return $EXIT_SUCCESS
	else
		return $EXIT_FAILURE
	fi
}

function update_backup_main {
	backup_main="`printf "$backup_main" "$1"`"
	backup_main_Alfredo="$backup_main/$Alfredo/"
	backup_main_Chrome="$backup_main/$Chrome/"
	backup_main_Projects="$backup_main/$Projects/"
}

function execute_rsync {
<<COMM
	if [ "$log_on_file" == true ]; then
		echo "SINCRONIZZAZIONE $1 IN $2" >> "$log_file"
		rsync --delete --progress -avu --no-links 						\
			--exclude=".fseventsd" --exclude=".TemporaryItems" 			\
			--exclude=".Trashes" --exclude=".Spotlight-V100"  			\
			--exclude=".DocumentRevisions-V100" --exclude=".DS_Store" 	\
			--exclude=".PKInstallSandboxManager" "$1" "$2" &>> "$log_file"
		echo -e "\n\n" >> "$log_file"
	else
		rsync --delete --progress -avu --no-links 						\
			--exclude=".fseventsd" --exclude=".TemporaryItems" 			\
			--exclude=".Trashes" --exclude=".Spotlight-V100"  			\
			--exclude=".DocumentRevisions-V100" --exclude=".DS_Store" 	\
			--exclude=".PKInstallSandboxManager" "$1" "$2"
	fi
COMM

	[ "$log_on_file" == true ] && msg 'NC' "Utilizzo file di log: $log_file"
	echo "$1" "$2"
	
	return $?
}

function file_exist_and_is_dir {
	[ -e "$1" ] && [ -d "$1" ] && return $EXIT_SUCCESS
	return $EXIT_FAILURE;
}

function usage {
	cat <<EOF
# Utilizzo

	$current_script_name -[options]

# Options

	-all part_id | --all part_id
		Equivale a: $current_script_name -a -p -c

	-a | --sync-alfredo
		Sincronizzazione della directory "$Alfredo", contenuta nella partizione da specificare con il flag -part, conte con il contenuto della directory "$source_files_Alfredo".

	-ar filename | --archive filename
		Archivia il file (o directory) filename nella directory appropriata.
		Il file verrà eliminato dalla sorgente.

	-ask | --ask-permission
		Chiede il permesso dell'utente prima di eseguire un'operazione.

	-c | --sync-chrome-prefs				
		Sincronizzazione della directory "$Chrome", contenuta nella partizione da specificare con il flag -part, con il contenuto della directory "$backup_main_Chrome".

	-l | --log-on-file
		Salva l'output del comando rsync su un file nella directory /tmp.

	-m part_id | --mount part_id
		Utilizza lo script $mount_script per montare le partizioni che dovranno essere sincronizzate.
		Questa opzione, se utilizzata, DEVE essere la PRIMA opzione specificata.

	-p | --sync-projects
		Sincronizzazione della directory "$Projects", contenuta nella partizione da specificare con il flag -part, con il contenuto della directory "$backup_main_Projects".

	-s | --show-ext-dev
		Mostra i devices fisici estrerni collegati che è possibile montare.

	-t | -set-tmp-dir
		Imposta la directory per i files temporanei.

	-v volume | --set-volume volume
		Serve per specificare il nome del volume su cui vuole essere fatta la sincronizzazione.
		Utilizzare il flag -s per conoscere le possibili partizioni.
		### TODO ###
		Esempio, se il volume è montato in /Volumes/Data Backup, si dovrà digitare -v "Data Backup"

EOF
}

function parse_input {
	if [ $# -eq 0 ]; then
		usage
		return $EXIT_FAILURE
	fi

	while [ $# -gt 0 ]; do
		case "$1" in
			-all | --all )
				b_Chrome=true
				b_Alfredo=true
				b_Projects=true
				shift
				;;

			-a | --sync-alfredo )
				b_Alfredo=true
				shift
				;;

			-ar | --archive )
				echo "### TOOD ###"
				;;

			-ask | --ask-permission )
				ask=true
				shift
				;;

			-c | --sync-chrome-prefs )
				b_Chrome=true
				shift
				;;

			-[hH] | --help | --HELP )
				usage
				break
				;;

			-l | --log-on-file )
				log_on_file=true
				shift
				;;

			-m | --mount )
				echo "### TODO ###"
				# shift
				# echo "Per montare le partizioni sono necessari i permessi di amministratore"
				# BUG
				# sudo "$mount_script" -p "$1"
				# END BUG
				# update_backup_main "$1"
				# shift
				;;

			-p | --sync-projects )
				b_Projects=true
				shift
				;;

			-s | --show-ext-dev )
				diskutil list external physical
				shift
				;;

			-t | --set-tmp-dir )
				shift
				if [ -d "$1" ]; then
					tmp_dir="$1"
					echo "Directory per i files temporanei impostata correttamente: \"$tmp_dir\""
				else
					echo "Directory \"$1\" non esistente. Verrà utilizzata quella di default: $tmp_dir"
				fi

				log_file=`mktemp "$tmp_dir/$current_script_name.XXXXXX"`
				msg "NC" "File di log: \"$log_file\""
				shift
				;;

			-v | --set-volume )
				shift
				if ! file_exist_and_is_dir "$1"; then
					echo "Specificare una partizione valida già montata"
					echo "Utilizzare il flag -s per l'elenco delle partizioni che è possibile montare"
					return $EXIT_FAILURE
				fi
				update_backup_main "$1"
				shift
				;;

			* )
				echo "Opzione \"$1\" sconosciuta"
				return $EXIT_FAILURE
				;;
		esac
	done
}

function sync_operation {
	if [ "$1" == true ]; then
		msg 'Y' "Sincronizzazione direcotry \"$2\" nella directory \"$3\""
		if [ "$ask" == true ] && ! get_response "Y" "Continuare?"; then
			msg "Y" "La sincronizzazione di \"$2\" in \"$3\" è stata interrotta"
			return $EXIT_FAILURE
		fi

		execute_rsync "$2" "$3"
		if [ $? == $EXIT_SUCCESS ]; then
			msg "G" "La sincronizzazione ha avuto esito positivo"
		else
			msg "R" "Qualcosa è andato storto durante la sincronizzazione"
		fi
	fi
}

function archive {
	# TODO
	if [ "$b_Chrome" == true ]; then
		msg 'Y' "Sincronizzazione direcotry SOURCE nella directory DEST"
		if [ "$ask" == true ] && ! get_response "Y" "Continuare?"; then
			msg "Y" "La sincronizzazione di \"$1\" in \"$2\" è stata interrotta"
			return $EXIT_FAILURE
		fi

		execute_rsync "$source_files_Chrome" "$backup_main_Chrome"
		if [ $? == $EXIT_SUCCESS ]; then
			msg "G" "La sincronizzazione ha avuto esito positivo"
		else
			msg "R" "Qualcosa è andato storto durante la sincronizzazione"
		fi
	fi
}

function print_conf {
	cat <<EOF
##########
### Configurazione
##
# Path sorgente backup: 
# Path destinazione backup:
# Path sorgente archiviazione:
# Path destinazione archiviazione:  
##########
EOF
}

function main {
	! parse_input "$@" && return $EXIT_FAILURE

	print_conf

	sync_operation "$b_Chrome" "$source_files_Chrome" "$backup_main_Chrome"
	sync_operation "$b_Alfredo" "$source_files_Alfredo" "$backup_main_Alfredo"
	sync_operation "$b_Projects" "$source_files_Projects" "$backup_main_Projects"
	archive

	return $EXIT_SUCCESS
}

main "$@"
exit $?
