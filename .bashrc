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
export LESS_SHELL_LINES=2
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
alias ansj=ANSIBLE_STDOUT_CALLBACK=json\ ansible

for ((i = 1; i <= 64; i++)); do alias $i="fg $i"; done
enable -n .
alias .="cd \$OLDPWD"
alias ..="cd .."
for ((i = 3; i < 10; i++)); do
	aname=''; dir=''
	for ((j = 0; j < i; j++)); do aname+=.; done
	for ((j = 0; j < i-1; j++)); do dir+=../; done
	alias $aname="cd ${dir%/}"
done
unset i j aname dir

complete -C /usr/bin/tofu tofu

r       () { sudo -iu root bash -c "$*"; }
lsa     () { ls -lAF "$@" | less -XEr; }
procs   () { ps -N --ppid=2 -o comm= | sort -u | column; }
psf     () { ps -H --sid $(pgrep -d, $@) -F; }
psa     () { if pids=`pgrep -f "$*" -d,`; then
                 ps -Ho pid,pcpu,rss,vsz,tty,s,cmd -p $pids; fi; }
