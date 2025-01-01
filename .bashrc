#

umask 02

complete -r
unset -f $(compgen -A function)
unset $(compgen -A variable _)
shopt -s cmdhist lithist extglob globstar histappend
set -o noclobber

export PS1='\n \$ '
export LANG=en_US.UTF-8
export MAILCHECK=
export HISTTIMEFORMAT='%Y%m%d%H%M%S '
export HISTFILE=~/.bash_history
export HISTFILESIZE=
export HISTSIZE=

export ANSIBLE_VAULT_PASSWORD_FILE=~/bin/ansvault
export ANSVAULT_PGPFILE=~/keys/vault/master.asc

export TF_CLI_ARGS_plan="-compact-warnings"
export TF_CLI_ARGS_apply="-compact-warnings"

export GPG_TTY=`tty`
export PDSH_RCMD_TYPE=ssh
export EDITOR=vim
export LESS="-iSQRF#3"
export QUOTING_STYLE=literal

PATH=~/bin
PATH=$PATH:~/venv/bin
PATH=$PATH:/usr/local/bin:/usr/local/sbin
PATH=$PATH:/bin:/sbin
PATH=$PATH:/usr/bin:/usr/sbin
export PATH

alias s='sudo'
alias j='jobs'
alias f='fg'
alias m='fg -'
alias h=hostname

complete -C /usr/bin/tofu tofu

r       () { sudo -iu root bash -c "$*"; }
lsa     () { ls -lAF "$@" | less -XEr; }
procs   () { ps -N --ppid=2 -o comm= | sort -u | column; }
psf     () { ps -H --sid $(pgrep -d, $@) -F; }
psa     () { if pids=`pgrep -f "$*" -d,`; then
                 ps -Ho pid,pcpu,rss,vsz,tty,s,cmd -p $pids; fi; }
