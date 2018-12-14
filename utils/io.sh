# ============================================================================
# Titolo: io.sh
# Descrizione: --/--
# Autore: Alfredo Milani (alfredo.milani.94@gmail.com)
# Data: Fri Dec 14 03:20:41 CET 2018
# Licenza: MIT License
# Versione: 1.0.0
# Note: Questo script non contiene alcun carattere di shebang perché dovrebbe essere utilizzato con il comando "source" (.)
# Versione bash: 4.4.19(1)-release
# ============================================================================


# If guard
if [[ -z "${__CURRENT_IO__}" ]]; then
	declare -r __CURRENT_IO__='io.sh'
	echo "CURRENT IO SETTED"
else
	echo "RETURNED IO"
	return
fi
echo "ATER DECLARE IO 1"

# Necessario per l'utilizzo di variabili si sistema
source './sys.sh'
echo "ATER DECLARE IO 2"

# Colori
declare -r R='\033[0;31m' 	# Red
declare -r Y='\033[1;33m' 	# Yellow
declare -r G='\033[0;32m' 	# Green
declare -r DG='\033[1;30m' 	# Dark gray
declare -r U='\033[4m' 		# Underlined
declare -r BD='\e[1m' 		# Bold
declare -r NC='\033[0m' 	# No Color


# ${1} -> il colore che deve avere la stringa
# ${2} -> la stringa che sarà stampata
function msg {
	case "${1}" in
		G )
			printf "${G}${2}${NC}\n"
			;;

		Y )
			printf "${Y}${2}${NC}\n"
			;;

		R )
			printf "${R}${2}${NC}\n"
			;;

		DG )
			printf "${DG}${2}${NC}\n"
			;;

		U )
			printf "${U}${2}${NC}\n"
			;;

		BD )
			printf "${BD}${2}${NC}\n"
			;;

		* )
			printf "${NC}${2}\n"
			;;
	esac
}

# ${1} -> il colore che deve avere la stringa
# ${2} -> la stringa che sarà stampata
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
