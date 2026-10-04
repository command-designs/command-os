# Command OS — shell de desarrollo. Se carga desde ~/.bashrc (lo gestiona install.sh).
[[ $- != *i* ]] && return

export EDITOR=nano VISUAL=nano PAGER=less
export LESS='-R -F -X'
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export HISTSIZE=50000 HISTFILESIZE=100000 HISTCONTROL=ignoreboth:erasedups
shopt -s histappend checkwinsize cdspell autocd globstar 2>/dev/null

[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion
[[ -r /usr/share/fzf/key-bindings.bash ]] && . /usr/share/fzf/key-bindings.bash
[[ -r /usr/share/fzf/completion.bash ]] && . /usr/share/fzf/completion.bash

alias ls='eza --group-directories-first --icons=auto'
alias ll='eza -lah --group-directories-first --icons=auto --git'
alias lt='eza --tree --level=2 --icons=auto'
alias cat='bat --paging=never --style=plain'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias update='sudo pacman -Syu'
alias n='nano'
alias v='vim'

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

command -v zoxide >/dev/null && eval "$(zoxide init bash)"
