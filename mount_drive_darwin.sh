#!/usr/local/bin/bash

EXIT_SUCCESS=0
EXIT_FAILURE=1
DEV_NULL="/dev/null"
script_name="`basename "$0"`"
VOLUMES="/Volumes"
DEV="/dev"
TMP="/tmp"

URL_NTFS_3G="https://github.com/osxfuse/osxfuse/releases/download/osxfuse-3.8.2/osxfuse-3.8.2.dmg"
FILENAME_NTFS_3G="osxfuse-3.8.2.dmg"
TARGET_INSTALLATION="$VOLUMES/Macintosh HD"
VOL_NTFS_3G="$VOLUMES/FUSE for macOS"
PACKAGE_PATH_NTFS_3G="$VOL_NTFS_3G/FUSE for macOS.pkg"

partitions=()

function check_root {
	current_user=`id -u`
	root_user=0

    if [ $current_user -ne $root_user ]; then
        cat <<EOF
Questo tool deve essere lanciato con privilegi di amministratore
EOF
		return $EXIT_FAILURE
    fi
    return $EXIT_SUCCESS
}

function check_tool_ntfs {
	if ! command -v ntfs-3g &> "$DEV_NULL"; then
		echo "E' necessario installare il tool FUSE per montare in lettura/scrittura le partizioni NTFS"
		echo "Scaricare ed installare il tool?"
		echo "[ s / n ]"
		read choise
		if [ "$choise" == "s" ]; then
			cd "$TMP"
			curl -LJO "$URL_NTFS_3G"
			hdiutil mount "$TMP/$FILENAME_NTFS_3G" &> "$DEV_NULL"
			installer -package "$PACKAGE_PATH_NTFS_3G" -target "$TARGET_INSTALLATION"
			status_code=$?
			hdiutil unmount "$VOL_NTFS_3G" &> "$DEV_NULL"
			rm "$TMP/$FILENAME_NTFS_3G"
			return $status_code
		fi
		return $EXIT_FAILURE
	fi
	return $EXIT_SUCCESS
}

function create_support_dir {
	# Creazione directory in /Volumes se non esistono
	[ ! -d "$1" ] && mkdir "$1"
}

function mount_partition {
	# $1 -> device
	# $2 -> mount point
	# Per utilizzare ntfs-3g è necessario installare FUSE (https://osxfuse.github.io/)
	ntfs-3g -o local -o allow_other -o uid=501 -o gid=20 -o umask=037 "$1" "$2"
	
	# Controllo se ci sono stati errori
	if [ $? -ne $EXIT_SUCCESS ]; then
		# Controllo se la directory è vuota
		if [ -z "`ls -A "$2"`" ]; then
			echo "La directory $2 non è più necessaria"
			echo "Vuoi rimuoverla?"
			echo "[ s / n ]"
			read choise
			if [ "$choise" == "s" ]; then
				rm -rf "$2"
				echo "La directory $2 è stata rimossa"
			else
				echo "La directory $2 non è stata rimossa"
			fi
		else
			echo "La directory $2 non è più necessaria ma sembra essere non vuota"
			echo "Se necessario rimuoverla manualmente"
			open "$VOLUMES"
		fi
		return $EXIT_FAILURE
	fi

	return $EXIT_SUCCESS
}

function umount_partition {
	diskutil umount "$1" &>"$DEV_NULL"
}

function usage {
	cat <<EOF
# Utilizzo

	sudo $script_name -[options]

# Options

	-h | -H )					Per visualizzare le opzioni disponibili
	-p part_id | -P part_id )	Per specificare la partizione NTFS da montare in lettura/scrittura
	-s | -S )					Mostra i devices fisici estrerni collegati che è possibile montare

# Examples

	sudo $script_name -p "disk5s1"
		Monterà in lettura e scittura la partizione s1 del disco disk5
	sudo $script_name -p "disk6s1" -p "disk8s4"
		Monterà in lettura e scrittura le partizioni s1 e s4 rispettivamente dei dischi disk6 e disk8

# Note

	E' possibile utilizzare il flag -s per visualizzare l'elenco delle partizioni che è possibile montare nel sistema.
	Basta vedere la colonna IDENTIFIER.
EOF
}

function show_physical_devices {
	local devices="`diskutil list external physical`"
	if [ -z "$devices" ]; then
		devices="*** Nessun device fisico esterno è collegato al computer ***"
	fi

	echo "Device estrerni collegati al computer:"
	echo "$devices"
}

function check_args {
	if [ $# -eq 0 ]; then
		usage
		return $EXIT_FAILURE
	fi

	while [ $# -gt 0 ]; do
		case "$1" in
			-[hH] )
				usage
				exit $EXIT_SUCCESS
				;;

			-[pP] )
				shift
				partitions+=("$1")
				shift
				;;

			-[sS] )
				show_physical_devices
				break
				;;

			* )
				echo "Opzione \"$1\" sconosciuta"
				return $EXIT_FAILURE
				;;
		esac
	done

	return $EXIT_SUCCESS
}

function check_partition {
	if ! diskutil info "$DEV/$1" &>"$DEV_NULL"; then
		echo "La partizione <${partitions[$i]}> non esiste"
		return $EXIT_FAILURE
	fi

	# Controllo che sia effettivamente una partizione e non un disco
	# Prendo la parte destra della stringa, a destra della sequenza "disk"
	# Divido la stringa restante (del tipo XXXsYYY) in un array del tipo ARR=("XXX", "YYY")
	# Contrllo se esiste il secondo elemento dell'array. Se non esiste vuol dire che non
	# è una partizione
	IFS='s' read -r -a tmp_array <<< "${1#disk*}"
	if ! [ "${#tmp_array[@]}" -eq 2 ]; then
		echo "Formato errato della partizione"
		echo "Le partizioni hanno il seguente formato: diskXXXsYYY"
		echo "Input ricevuto: $1"
		return $EXIT_FAILURE
	fi

	return $EXIT_SUCCESS
}



function main {
	check_root || return $EXIT_FAILURE

	if ! check_tool_ntfs; then
		echo "Errore installazione"
		return $EXIT_FAILURE
	fi

	check_args "$@" || return $EXIT_FAILURE

	for ((i = 0; i < ${#partitions[@]}; ++i)); do
		check_partition "${partitions[$i]}" || continue

		mount_point="$VOLUMES/${partitions[$i]}"
		dev_to_mount="$DEV/${partitions[$i]}"

		umount_partition "$dev_to_mount"
		create_support_dir "$mount_point"
		mount_partition "$dev_to_mount" "$mount_point"
	done
}

main "$@"
exit $?