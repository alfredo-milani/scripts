# ============================================================================
# Titolo: sys.sh
# Descrizione: --/--
# Autore: Alfredo Milani (alfredo.milani.94@gmail.com)
# Data: Fri Dec 14 03:32:38 CET 2018
# Licenza: MIT License
# Versione: 1.0.0
# Note: Questo script non contiene alcun carattere di shebang perché dovrebbe essere utilizzato con il comando "source" (.)
# Versione bash: 4.4.19(1)-release
# ============================================================================


# If guard
if [[ -z "${__CURRENT_SYS__}" ]]; then
	declare -r __CURRENT_SYS__='sys.sh'
	echo "CURRENT SYS SETTED"
else
	echo "RETURNED SYS"
	return
fi
echo "ATER DECLARE SYS 1"


# Source files necessari
source './io.sh'
echo "ATER DECLARE SYS 2"


# Readonly vars
declare -r -i EXIT_SUCCESS=0
declare -r -i EXIT_FAILURE=1

declare -r -i ROOT_USER=0

declare -r true='true'
declare -r false='false'
declare -r DEV_NULL='/dev/null'
declare -r TMP='/tmp'


function check_tools {
	local tools_missing="${false}"

	while [[ ${#} -gt 0 ]]; do
		command -v "${1}" &> "${DEV_NULL}"
		if [[ ${?} != 0 ]]; then
			msg 'R' "Il tool ${1}, necessario per l'esecuzione di questo script, non è presente nel sistema.\nInstallarlo per poter continuare."
			tools_missing="${true}"
		fi
		shift
	done

	if [[ "${tools_missing}" == "${true}" ]]; then
		return ${EXIT_FAILURE}
	else
		return ${EXIT_SUCCESS}
	fi
}

# ${1} (opzionale) -> messaggio da stampare all'utente nel caso 
# 	l'utente corrente non abbia i permessi di amministratore
function check_root {
	local msg="Questo tool deve essere lanciato con privilegi di amministratore"
	local current_user=$(id -u)

    if [[ ${current_user} -ne ${ROOT_USER} ]]; then
    	[[ -n "${1}" ]] && msg="${1}"
    	msg 'R' "${msg}"
        return ${EXIT_FAILURE}
    fi

    return ${EXIT_SUCCESS}
}