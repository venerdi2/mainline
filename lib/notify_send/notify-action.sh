#!/bin/bash

### 20200520 b.kenyon.w@gmail.com
#   This is completely re-written for https://github.com/bkw777/mainline
#
# * If REPLACE_ID then find the PID of any previous monitor for the same NOTIFICATION_ID
#   and kill that process and replace it, rather than add more and more monitor processes.
# * Run gdbus in {} instead of ()
# * Parse gdbus output without $(sed ...)
# * Close notifcation after receiving any action.
# * Robust pid file and old-job processing
# * Robust cleanup on exit
# * Vastly refactored to use all bash built-in features
#   and no child processes except gdbus and the invoked actions
#   no more sed to parse output or foo=$(command ...) to collect output etc
# * Use APP_NAME (if present) in place of $0 in pid filename
# * setsid to free ourself from the invoved action process

NOTIFY_SEND=${0%/*}/notify-send.sh
GDBUS_ARGS=(monitor --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications)
SELF=${0##*/}
GDBUS_PIDF=/tmp/${APP_NAME:=${SELF}}.${$}.p

set +H
shopt -s extglob

abrt () { echo "${0}: ${@}" >&2 ; exit 1 ; }

# consume the command line
typeset -i ID="${1}" ;shift
[[ ${ID} -gt 0 ]] || abrt "no notification id"
declare -A a ;while [[ "${1}" ]] ;do a[${1}]=${2} ;shift 2 ;done
[[ ${#a[@]} -gt 0 ]] || abrt "no actions"

[[ "${DISPLAY}" ]] || abrt "no DISPLAY"
typeset -i i=0 p=0
# start the pid file, no PID or linefeed yet
echo -n "${DISPLAY} ${ID} " > ${GDBUS_PIDF}

# kill any duplicate jobs older than ourself
for f in /tmp/${APP_NAME}.+([0-9]).p ;do
	[[ -s "${f}" ]] || continue
	[[ ${f} -ot ${GDBUS_PIDF} ]] || continue
	read d i p x < "${f}"
	[[ "${d}" == "${DISPLAY}" ]] || continue
	[[ ${i} == ${ID} ]] || continue
	[[ ${p} -gt 0 ]] || continue
	rm -f "${f}"
	kill ${p}
done

# start the dbus monitor
{
	gdbus ${GDBUS_ARGS[@]} & echo "${!}" >> ${GDBUS_PIDF}
} |while IFS+=":.()," read x x x x e x i k x ;do
	[[ ${i} == ${ID} ]] || continue
	k=${k:1} k=${k:0:-1}
	case "${e}" in
		"NotificationClosed") k="close" ;;
		"ActionInvoked") "${NOTIFY_SEND}" -s ${ID} ;;
	esac
	setsid -f bash -c "${a[${k}]}" >/dev/null 2>&1 &
	break
done

# kill the dbus monitor
# Our gdbus process might be killed by a new instance of ourself (see above)
# while we wait forever for a dbus event that never came. So here, don't treat
# a missing file as an alarming error. Above, we will delete the file before we
# kill the gdbus process so that here, we can't end up trying to kill a random
# unrelated new process that happened to get the same PID after it was freed.
[[ -s ${GDBUS_PIDF} ]] || exit
read d i p x < ${GDBUS_PIDF}
rm -f ${GDBUS_PIDF}
[[ ${p} -gt 0 ]] || exit
kill ${p}
