#!/usr/bin/env bash
# notice.sh - desktop notification client
# Brian K. White <b.kenyon.w@gmail.com>
# https://github.com/bkw777/notice.sh
# license GPL3
# https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html
# This copy slightly stripped for use in github.com/bkw777/mainline
set +H

tself="${0//\//_}"
TMP="${XDG_RUNTIME_DIR:-/tmp}"
${DEBUG:=false} && {
	e="${TMP}/${tself}.${$}.e"
	echo "$0 debug logging to $e" >&2
	exec 2>"$e"
	set -x
	ARGV=("$0" "$@")
	trap "set >&2" 0
}

VERSION="2.1-mainline"
GDBUS_ARGS=(--session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications)
GDBUS_PIDFILE="${TMP}/${tself}.${$}.p"
GDBUS_PIDFILES="${TMP}/${tself}.+([0-9]).p"

typeset -i ID=0 TTL=-1 KI=0
typeset -a ACMDS=()
unset ID_FILE ICON SUMMARY BODY AKEYS HINTS
APP_NAME="$0"
FORCE_CLOSE=false
CLOSE=false
ACTION_DAEMON=false
typeset -A c=()

typeset -Ar HINT_TYPES=(
	[action-icons]=boolean
	[category]=string
	[desktop-entry]=string
	[image-path]=string
	[resident]=boolean
	[sound-file]=string
	[sound-name]=string
	[suppress-sound]=boolean
	[transient]=boolean
	[x]=int32
	[y]=int32
	[urgency]=byte
)

typeset -r ifs="$IFS"

help () { echo "$0 [-Nnsbhapitfcv? ...] [--] [summary]
 -N \"Application Name\" - sending applications formal name
 -n icon_name_or_path  - icon
 -s \"summary text\"     - summary - same as non-option args
 -b \"body text\"        - body
 -h \"hint:value\"       - hint
 -a \"label:command\"    - button-action
 -a \":command\"         - default-action
 -a \"command\"          - close-action
 -i #                  - notification ID number
 -i @filename          - write ID to & read ID from filename
 -t #                  - time to live in seconds
 -f                    - force close after ttl or action
 -c                    - close notification specified by -i
 -v                    - version
 -?                    - this help"
}

abrt () { echo "$0: $@" >&2 ; exit 1 ; }

########################################################################
# action daemon
#

# TODO: Can we make this more elegant by just sending a signal
# to the parent process, it traps the signal to exit itself,
# and it's child gdbus process exits itself naturally on HUP?

ad_kill_obsolete_daemons () {
	local f l d x ;local -i i p
	shopt -s extglob ;l="${GDBUS_PIDFILES}" ;shopt -u extglob
	for f in $l ;do
		[[ -s $f ]] || continue
		[[ $f -ot ${GDBUS_PIDFILE} ]] || continue
		read d i p x < $f
		[[ "$d" == "${DISPLAY}" ]] || continue
		((i==ID)) || continue
		((p>1)) || continue
		rm -f "$f"
		kill $p
	done
}

ad_kill_current_daemon () {
	local d x ;local -i i p
	${DEBUG} && set >&2
	[[ -s ${GDBUS_PIDFILE} ]] || exit 0
	read d i p x < "${GDBUS_PIDFILE}"
	rm -f "${GDBUS_PIDFILE}"
	((p>1)) || exit
	kill $p
}

ad_run () {
	setsid -f ${c[${1}]} >&- 2>&- <&-
	${FORCE_CLOSE} && "$0" -i ${ID} -d
}

action_daemon () {
	local e k x ; local -i i
	((ID)) || abrt "no ID"
	while (($#)) ;do c[$1]="$2" ;shift 2 ;done
	((${#c[@]})) || abrt "no actions"
	[[ "${DISPLAY}" ]] || abrt "no DISPLAY"
	echo -n "${DISPLAY} ${ID} " > "${GDBUS_PIDFILE}"
	ad_kill_obsolete_daemons
	trap "ad_kill_current_daemon" 0
	{
		gdbus monitor ${GDBUS_ARGS[@]} -- & echo ${!} >> "${GDBUS_PIDFILE}"
	} |while IFS=" :.(),'" read x x x x e x i x k x ;do
		((i==ID)) || continue
		${DEBUG} && printf 'event="%s" key="%s"\n' "$e" "$k" >&2
		case "$e" in
			"NotificationClosed") ad_run "close" ;;
			"ActionInvoked") ad_run "$k" ;;
		esac
		break
	done
	exit
}

#
# action daemon
########################################################################

close_notification () {
	((ID)) || abrt "no ID"
	((TTL>0)) && sleep ${TTL}
	gdbus call ${GDBUS_ARGS[@]} --method org.freedesktop.Notifications.CloseNotification -- ${ID} >&-
	[[ ${ID_FILE} ]] && rm -f "${ID_FILE}"
	exit
}

add_hint () {
	local a ;IFS=: a=($1) ;IFS="$ifs"
	((${#a[@]}==2 || ${#a[@]}==3)) || abrt 'syntax: -h "name:value[:type]"'
	local n="${a[0]}" v="${a[1]}" t="${a[2]}"
	t=${HINT_TYPES[$n]:-${t,,}}
	[[ $t = string ]] && v="\"$v\""
	((${#HINTS})) && HINTS+=,
	HINTS+="\"$n\":<$t $v>"
}

add_action () {
	local a k ;IFS=: a=($1) ;IFS="$ifs"
	case ${#a[@]} in
		1) k=close a=("" "${a[0]}") ;;
		2) ((${#a[0]})) && k=$((KI++)) || k=default ;((${#AKEYS})) && AKEYS+=, ;AKEYS+="\"${k}\",\"${a[0]}\"" ;;
		*) abrt 'syntax: -a "[[name]:]command"' ;;
	esac
	ACMDS+=("${k}" "${a[1]}")
}

########################################################################
# parse the commandline
#
OPTIND=1
while getopts 'N:n:s:b:h:a:i:t:fcv%?' x ;do
	case "$x" in
		N) APP_NAME="$OPTARG" ;;
		n) ICON="$OPTARG" ;;
		s) SUMMARY="$OPTARG" ;;
		b) BODY="$OPTARG" ;;
		a) add_action "$OPTARG" ;;
		h) add_hint "$OPTARG" ;;
		i) [[ ${OPTARG:0:1} == '@' ]] && ID_FILE="${OPTARG:1}" || ID=$OPTARG ;;
		t) TTL=$OPTARG ;;
		f) FORCE_CLOSE=true ;;
		c) CLOSE=true ;;
		v) echo "$0 ${VERSION}" ;exit 0 ;;
		%) ACTION_DAEMON=true ;;
		'?') help ;exit 0 ;;
		*) help ;exit 1 ;;
	esac
done
shift $((OPTIND-1))

# if we don't have an ID, try ID_FILE
((ID<1)) && [[ -s "${ID_FILE}" ]] && read ID < "${ID_FILE}"

########################################################################
# modes
#

# if we got a close command, then do that now and exit
${CLOSE} && close_notification

# if daemon mode, divert to that
${ACTION_DAEMON} && action_daemon "$@"

########################################################################
# main
#

((${#SUMMARY}<1)) && (($#)) && SUMMARY="$@"
typeset -i t=${TTL} ;((t>0)) && ((t=t*1000))

# send the dbus message, collect the notification ID
s=$(gdbus call ${GDBUS_ARGS[@]} --method org.freedesktop.Notifications.Notify -- \
	"${APP_NAME}" ${ID} "${ICON}" "${SUMMARY}" "${BODY}" "[${AKEYS}]" "{${HINTS}}" "$t")

# process the collected ID
s="${s%,*}" ID="${s#* }"
((ID)) || abrt "invalid notification ID from gdbus"
[[ "${ID_FILE}" ]] && echo ${ID} > "${ID_FILE}" || echo ${ID}

# background task to monitor dbus and perform the actions
s= ;${FORCE_CLOSE} && s='-f'
((${#ACMDS[@]})) && setsid -f "$0" -i ${ID} $s -% "${ACMDS[@]}" >&- 2>&- <&-

# background task to wait TTL seconds and then actively close the notification
${FORCE_CLOSE} && ((TTL)) && setsid -f "$0" -t ${TTL} -i ${ID} -c >&- 2>&- <&-
