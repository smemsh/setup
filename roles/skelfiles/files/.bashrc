#

umask 02

complete -r
unset -f $(compgen -A function)
unset $(compgen -A variable _)
shopt -s cmdhist lithist extglob globstar histappend

export HISTFILE=~/.bash_history
export HISTFILESIZE=
export HISTSIZE=$HISTFILESIZE
export HISTTIMEFORMAT='%Y%m%d%H%M%S '
export MAILCHECK=
export PS1='\n \$ '

PATH=$HOME/bin
PATH=$PATH:/usr/local/bin:/usr/local/sbin
PATH=$PATH:/bin:/sbin
PATH=$PATH:/usr/bin:/usr/sbin
export PATH

alias s='sudo'
r () { sudo -iu root bash -c "$*"; }

lsa     () { ls -lAF "$@" | less -XEr; }
procs   () { ps -N --ppid=2 -o comm= | sort -u | column; }
psf     () { ps -H --sid $(pgrep -d, $@) -F; }
psa     () { if pids=`pgrep -f "$*" -d,`; then
                 ps -Ho pid,pcpu,rss,vsz,tty,s,cmd -p $pids; fi; }

alias j='jobs'
alias f='fg'
alias m='fg -'
alias c='clear'
alias h='hostname'
