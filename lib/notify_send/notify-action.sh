#!/bin/bash
# 20200520 b.kenyon.w@gmail.com
# This is a complete re-write & replacement of notify-action.sh from
# https://github.com/vlevit/notify-send.sh
# for https://github.com/bkw777/mainline
# See mainline_changes.txt before changing "kill obsolete" or "kill current"

NOTIFY_SEND=${0%/*}/notify-send.sh
GDBUS_ARGS=(monitor --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications)
SELF=${0##*/}
GDBUS_PIDF=/tmp/${APP_NAME:=${SELF}}.${$}.p

${DEBUG_NOTIFY_SEND:=false} && {
	exec 2>/tmp/.${SELF}.${$}.e
	set -x
}

set +H
shopt -s extglob

abrt () { echo "${0}: ${@}" >&2 ; exit 1 ; }

# consume the command line
typeset -i ID="${1}" ;shift
((${ID}>0)) || abrt "no notification id"
declare -A a ;while ((${#})) ;do a[${1}]=${2} ;shift 2 ;done
((${#a[@]})) || abrt "no actions"

[[ "${DISPLAY}" ]] || abrt "no DISPLAY"
typeset -i i=0 p=0
# only starting the pid file, no PID or linefeed yet
echo -n "${DISPLAY} ${ID} " > ${GDBUS_PIDF}

# kill obsolete monitors
for f in /tmp/${APP_NAME}.+([0-9]).p ;do
	[[ -s "${f}" ]] || continue
	[[ ${f} -ot ${GDBUS_PIDF} ]] || continue
	read d i p x < ${f}
	[[ "${d}" == "${DISPLAY}" ]] || continue
	((${i}==${ID})) || continue
	((${p}>1)) || continue
	rm -f ${f}
	kill ${p}
done

# set trap to kill the monitor on exit
trap "conclude" 0
conclude () {
	[[ -s ${GDBUS_PIDF} ]] || exit 0
	read d i p x < ${GDBUS_PIDF}
	rm -f ${GDBUS_PIDF}
	((${p}>1)) || exit 0
	kill ${p}
	exit 0
}

# execute an invoked command
doit () {
	setsid -f ${a[${1}]} >&- 2>&- <&- &
	${EXPLICIT_CLOSE:-false} && "${NOTIFY_SEND}" -s ${ID}
}

# start current monitor
{
	gdbus ${GDBUS_ARGS[@]} & echo ${!} >> ${GDBUS_PIDF}
} |while IFS=" :.(),'" read x x x x e x i x k x ;do
	((${i}==${ID})) || continue
	case "${e}" in
		"NotificationClosed") doit "close" ;;
		"ActionInvoked") doit "${k}" ;;
	esac
	break
done

${DEBUG_NOTIFY_SEND} && set >&2
