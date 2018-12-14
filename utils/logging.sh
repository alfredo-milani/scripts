# ============================================================================
# Titolo: logging.sh
# Descrizione: --/--
# Autore: Alfredo Milani (alfredo.milani.94@gmail.com)
# Data: Fri Dec 14 03:33:28 CET 2018
# Licenza: MIT License
# Versione: 1.0.0
# Note: Questo script non contiene alcun carattere di shebang perché dovrebbe essere utilizzato con il comando "source" (.)
# Versione bash: 4.4.19(1)-release
# ============================================================================


# Readonly vars
declare -r LOG='/var/log/script.log'


function log {
	printf "${1}\n" >> "${LOG}"
}
