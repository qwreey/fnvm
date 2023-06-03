# reformatting
fnvm_escape_search() {
	echo "$(sed -e 's/[^^]/[&]/g; s/\^/\\^/g; $!a\'$'\n''\\n' <<<"$1" | tr -d '\n')"
}
fnvm_escape_replace() {
	IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g' <<<"$1")
	echo "${REPLY%$'\n'}"
}
fnvm_replace() {
	grep -F -q "$2" "$1" && sed -n -e ':a' -e '$!{N;ba' -e '}' -e "s/$(fnvm_escape_search "$2")/$(fnvm_escape_replace "$3")/p" -i "$1"
}

# update single rc file
fnvm_update_rcfile() {
	pattern1='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion'
	pattern2='export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm'
	replace='# load fnvm
source $HOME/.nvm/fnvm/fnvm.sh; fnvm_init'

	grep -F -q 'source $HOME/.nvm/fnvm/fnvm.sh; fnvm_init' "$1" && return
	grep -F -q "$pattern" "$1" || grep -F -q "$pattern2" "$1"
	if [ "$?" = "0" ]; then
		echo "Updating $1 ..."
		fnvm_replace "$1" "$pattern1" "$replace"
		fnvm_replace "$1" "$pattern2" "$replace"
	else
		echo "'source nvm.sh' is not found from $1."
		echo "Appending fnvm loader on end of $1"
		echo "Please manually remove original nvm sourcing on $1 if exist"
		echo "$replace" >> "$1"
	fi
}
