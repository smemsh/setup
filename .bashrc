#

umask 02

complete -r
unset -f $(compgen -A function)
unset $(compgen -A variable _)
shopt -s cmdhist lithist extglob globstar histappend

export PS1='\n \$ '
export MAILCHECK=
export HISTTIMEFORMAT='%Y%m%d%H%M%S '
export HISTFILE=~/.bash_history
export HISTFILESIZE=
export HISTSIZE=

export ANSIBLE_VAULT_PASSWORD_FILE=~/bin/ansvault
export ANSVAULT_PGPFILE=~/keys/vault/master.asc

export GPG_TTY=`tty`
export PDSH_RCMD_TYPE=ssh
export EDITOR=vim

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

r       () { sudo -iu root bash -c "$*"; }
lsa     () { ls -lAF "$@" | less -XEr; }
procs   () { ps -N --ppid=2 -o comm= | sort -u | column; }
psf     () { ps -H --sid $(pgrep -d, $@) -F; }
psa     () { if pids=`pgrep -f "$*" -d,`; then
                 ps -Ho pid,pcpu,rss,vsz,tty,s,cmd -p $pids; fi; }
