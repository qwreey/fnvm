# bash / zsh compatible echo
fnvm_out() {
	\printf '%s' $(sed "s/"$'\r'"//g"<<<"$@")
}

# reformatter
fnvm_escape_search() {
	sed -e 's/[^^]/[&]/g; s/\^/\\^/g; $!a\'$'\n''\\n' <<<"$1" | tr -d '\n'
}
fnvm_escape_replace() {
	IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g' <<<"$1")
	fnvm_out "${REPLY%'\n'}"
}
fnvm_safe_find() {
	grep -q -F "$(sed ':a;N;$!ba;s/\n/__NEWLINE__/g' <<<"$2")" <<<"$(sed ':a;N;$!ba;s/\n/__NEWLINE__/g' <<<"$1")" || return 1
}
fnvm_replace_file() {
	fnvm_safe_find "$(cat $1)" "$2" || return
	sed -n -e ':a' -e '$!{N;ba' -e '}' -e "s/$(fnvm_escape_search "$2")/$(fnvm_escape_replace "$3")/p" -i "$1"
}
fnvm_replace() {
	fnvm_safe_find "$1" "$2" || return
	sed -n -e ':a' -e '$!{N;ba' -e '}' -e "s/$(fnvm_escape_search "$2")/$(fnvm_escape_replace "$3")/p" <<<"$1"
}

# faster nvm change path
fnvm_pathformat() {
	\printf "%s:%s"\
		"${1-}"\
		"$(sed "s#$(fnvm_escape_search "$NVM_DIR")/[^:]*:##g" <<<"$PATH")"
}

# faster nvm use
fnvm_use() {
	version_dir="$(fnvm_out "$(nvm_version_path "$1" 2> /dev/null)")"
	if [ ! -z "$version_dir" ] && [ -e "$version_dir" ]; then
		[ "$FNVM_VER" = "$1" ] && return
		export PATH=$(fnvm_pathformat "$version_dir/bin")
		export NVM_BIN="${version_dir}/bin"
		export NVM_INC="${version_dir}/include/node"
		export FNVM_VER="$1"
	else
		fnvm_out "ERROR: path '$version_dir' is not exist, failed to load nodejs. Please check your ~/.nvmrc.default"$'\n'
		fnvm_out "Tip: To init .nvmrc.cached follow this step"$'\n'
		fnvm_out "  nvm install node # Choose version you want"$'\n'
		fnvm_out "  nvm use node"$'\n'
		fnvm_out "  node --version > ~/.nvmrc.default"$'\n'
		fnvm_out "  export FNVM_VER=\$(cat ~/.nvmrc.default)"$'\n'
	fi
}

# load .nvmrc or ~/.nvmrc.default
fnvm_apply() {
	# find .nvmrc file on cwd
	cpd_nvmrc=$(nvm_find_nvmrc)
	if [ ! -z "$cpd_nvmrc" ]; then
		# found nvmrc, and match with last nvmrc file
		[ "$cpd_nvmrc" = "$FNVM_NVMRC" ] && return

		# check is installed
		content="$(cat "$cpd_nvmrc")"
		version=$(nvm_match_version "$content")
		if [ "$version" = "N/A" ]; then
			# not found, install it
			echo "version '$content' not found. install it"
			nvm install "$content"
		else
			# found it, use with faster method
			echo "Found '$cpd_nvmrc' with version $version"
			fnvm_use $version
			echo "PATH was updated"
		fi
		export FNVM_NVMRC=$cpd_nvmrc
		return
	fi

	# load default version
	[ "$FNVM_NVMRC" = "$FNVM_NVMRC_DEFAULT" ] && return
	[ ! -z "$FNVM_NVMRC" ] && echo "Reverting to ~/.nvmrc.default"
	export FNVM_NVMRC="$FNVM_NVMRC_DEFAULT"
	fnvm_use "$(cat "$FNVM_NVMRC_DEFAULT")"
}

# cd wraping
fnvm_cd() {
	\cd $@ && fnvm_apply
}

# update fnvm
# update single rc file
fnvm_update_rcfile() {
	pattern1='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion'
	pattern2='export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm'
	pattern3="export NVM_DIR=\"$(cygpath --mixed $HOME)/.nvm\"
[ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"  # This loads nvm
[ -s \"\$NVM_DIR/bash_completion\" ] && \. \"\$NVM_DIR/bash_completion\"  # This loads nvm bash_completion"
	replace='# load fnvm
source $HOME/.nvm/fnvm/fnvm.sh; fnvm_init'

	grep -F -q 'source $HOME/.nvm/fnvm/fnvm.sh; fnvm_init' "$1" && return
	content="$(cat "$1")"
	fnvm_safe_find "$content" "$pattern1" ||
	fnvm_safe_find "$content" "$pattern2" ||
	fnvm_safe_find "$content" "$pattern3"
	if [ "$?" = "0" ]; then
		echo "Updating $1 ..."
		fnvm_replace_file "$1" "$pattern1" "$replace"
		fnvm_replace_file "$1" "$pattern2" "$replace"
		fnvm_replace_file "$1" "$pattern3" "$replace"
	else
		echo "'source nvm.sh' is not found from $1."
		echo "Appending fnvm loader on end of $1"
		echo "Please manually remove original nvm sourcing on $1 if exist"
		echo "$replace" >> $1
	fi
}
fnvm_update() {
	git -C $NVM_DIR/fnvm pull
	fnvm_uninit

	[ -z "$nvmdir" ] && nvmdir="$HOME/.nvm"

	[ -e "$HOME/.zshrc" ] && fnvm_update_rcfile "$HOME/.zshrc"
	[ -e "$HOME/.bashrc" ] && fnvm_update_rcfile "$HOME/.bashrc"
	
	source $nvmdir/fnvm/fnvm.sh
	fnvm_init
}

# unload fnvm
fnvm_uninit() {
	which nvm 2>/dev/null 1>/dev/null && nvm unload

	if [ "$FNVM_DISABLE_CD" != "yes" ]; then
		if [ -n "${ZSH_VERSION-}" ]; then
			# remove zsh hook
			add-zsh-hook -d chpwd fnvm_update
		else
			# remove bash hook
			unalias cd 2>/dev/null 1>/dev/null
		fi
	fi

	unset FNVM_NVMRC_DEFAULT
	unset FNVM_NVMRC
}

# load fnvm
fnvm_init() {
	export NVM_DIR="$HOME/.nvm"
	export FNVM_NVMRC_DEFAULT="$HOME/.nvmrc.default"
	shell_name=$(basename $(fnvm_out $0))

	source "$NVM_DIR/nvm.sh" --no-use
	[ "$shell_name" = "bash" ] && source "$NVM_DIR/bash_completion"

	if [ "$FNVM_DISABLE_CD" != "yes" ]; then
		if [ -n "${ZSH_VERSION-}" ]; then
			# this terminal is zsh, using add-zsh-hook to hooking cd
			autoload -U add-zsh-hook
			add-zsh-hook chpwd fnvm_apply
		else
			# bash or something else
			alias cd=fnvm_cd
		fi
	fi
	fnvm_apply
}
