# Command OS — shell de la terminal. Se carga desde ~/.bashrc (lo añade command-os-user-setup).
[[ $- != *i* ]] && return

export EDITOR=nano VISUAL=nano PAGER=less
export LESS='-R -F -X'
export HISTSIZE=50000 HISTFILESIZE=100000 HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize cdspell autocd globstar 2>/dev/null

[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion

alias ls='ls --color=auto --group-directories-first'
alias ll='ls -lah'
alias grep='grep --color=auto'
alias ..='cd ..'
# Actualización segura: fecha validada de Arch e instantánea antes y después (command-os-update).
alias update='command-os-update'

# Prompt HUD (docs/DISENO.md): usuario en hueso, ruta en cian, rama en gris y flecha roja.
# Si el último comando falló, se añade su código en amarillo.
__cmd_prompt() {
  local rc=$?
  local branch; branch=$(git branch --show-current 2>/dev/null)
  PS1='\[\e[38;2;237;235;230m\]\u@\h\[\e[0m\] \[\e[38;2;91;191;196m\]\w\[\e[0m\]'
  [[ -n $branch ]] && PS1+=" \[\e[38;2;111;104;112m\]// $branch\[\e[0m\]"
  (( rc != 0 )) && PS1+=" \[\e[38;2;226;192;68m\][$rc]\[\e[0m\]"
  PS1+='\n\[\e[38;2;209;52;73m\]›\[\e[0m\] '
}
PROMPT_COMMAND=__cmd_prompt
