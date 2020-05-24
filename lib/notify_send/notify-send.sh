#!/usr/bin/env bash

# notify-send.sh - drop-in replacement for notify-send with more features
# Copyright (C) 2015-2020 notify-send.sh authors (see AUTHORS file)

# 20200520 b.kenyon.w@gmail.com
# Originally from https://github.com/vlevit/notify-send.sh
# This copy is significantly re-written for https://github.com/bkw777/mainline
# See mainline_changes.txt

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Desktop Notifications Specification
# https://developer.gnome.org/notification-spec/

SELF=${0##*/}
VERSION="1.1-mainline"
ACTION_HANDLER=${0%/*}/notify-action.sh

${DEBUG_NOTIFY_SEND:=false} && {
	exec 2>/tmp/.${SELF}.${$}.e
	set -x
}

NOTIFY_ARGS=(--session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications)
typeset -i i=0 ID=0 EXPIRE_TIME=-1
URGENCY=1
HINTS=()
APP_NAME=${SELF}
PRINT_ID=false
EXPLICIT_CLOSE=false
unset ID_FILE
positional=false
SUMMARY_SET=false
SUMMARY=""
BODY=""
set +H

help() {
    cat <<EOF
Usage:
  notify-send.sh [OPTION...] <SUMMARY> [BODY] - create a notification

Help Options:
  -?|--help                         Show help options

Application Options:
  -u, --urgency=LEVEL               Specifies the urgency level (low, normal, critical).
  -t, --expire-time=TIME            Specifies the timeout in milliseconds at which to expire the notification.
  -f, --force-expire                Actively close the notification after the expire time, or after processing any action.
  -a, --app-name=APP_NAME           Specifies the app name for the icon.
  -i, --icon=ICON[,ICON...]         Specifies an icon filename or stock icon to display.
  -c, --category=TYPE[,TYPE...]     Specifies the notification category.
  -h, --hint=TYPE:NAME:VALUE        Specifies basic extra data to pass. Valid types are int, double, string and byte.
  -o, --action=LABEL:COMMAND        Specifies an action. Can be passed multiple times. LABEL is usually a button's label. COMMAND is a shell command executed when action is invoked.
  -d, --default-action=COMMAND      Specifies the default action which is usually invoked by clicking the notification.
  -l, --close-action=COMMAND        Specifies the action invoked when notification is closed.
  -p, --print-id                    Print the notification ID to the standard output.
  -r, --replace=ID                  Replace existing notification.
  -R, --replace-file=FILE           Store and load notification replace ID to/from this file.
  -s, --close=ID                    Close notification. With -R, get ID from -R file. 
  -v, --version                     Version of the package.

EOF
}

abrt () { echo "${SELF}: $@" >&2 ; exit 1 ; }

convert_type () {
    case "${1}" in
        int) echo int32 ;;
        double|string|byte) echo "${1}" ;;
        *) echo error; return 1 ;;
    esac
}

make_hint () {
    type=$(convert_type "$1")
    ((${?})) && return 1
    name=${2}
    [[ "$type" = string ]] && command="\"$3\"" || command="$3"
    echo "\"$name\": <$type $command>"
}

concat_actions () {
    local s=${1} ;shift
    while ((${#})) ;do s+=",${1}" ;shift ;done
    echo "[${s}]"
}

concat_hints () {
    local s=${1} ;shift
    while ((${#})) ;do s+=",${1}" ;shift ;done
    echo "{${s}}"
}

notify_close () {
	typeset -i i="${2}"
	((${i}>0)) && sleep ${i:0:-3}.${i:$((${#i}-3))}
    gdbus call ${NOTIFY_ARGS[@]} --method org.freedesktop.Notifications.CloseNotification "${1}" >&-
}

process_urgency () {
    case "${1}" in
        low) URGENCY=0 ;;
        normal) URGENCY=1 ;;
        critical) URGENCY=2 ;;
        *) abrt "Invalid urgency \"${URGENCY}\". Valid values: low normal critical" ;;
    esac
}

process_category () {
	local a c
    IFS=, a=(${1})
    for c in "${a[@]}"; do
        HINTS+=("$(make_hint string category "${c}")")
    done
}

process_hint () {
	local a t n c h
    IFS=: a=(${1})
    t=${a[0]} n=${a[1]} c=${a[2]}
    [[ "${n}" ]] && [[ "${c}" ]] || abrt "Invalid hint syntax specified. Use TYPE:NAME:VALUE."
    h="$(make_hint "${t}" "${n}" "${c}")"
    ((${?})) && abrt "Invalid hint type \"${t}\". Valid types are int, double, string and byte."
    HINTS+=("${h}")
}

process_action () {
	local x n c k
    IFS=: x=(${1})
    n=${x[0]} c=${x[1]}
    [[ "${n}" ]] && [[ "${c}" ]] || abrt "Invalid action syntax specified. Use NAME:COMMAND."
    k=${APP_NAME}_${n}
    ACTION_COMMANDS+=("${k}" "${c}")
    ACTIONS+=("\"${k}\",\"${n}\"")
}

process_special_action () {
    local k=${1} c=${2}
    [[ "${c}" ]] || abrt "Command must not be empty"
    ACTION_COMMANDS+=("${k}" "${c}")
    [[ "${k}" != "close" ]] && ACTIONS+=("\"${k}\",\"\"")
}

process_posargs () {
    [[ "${1}" = -* ]] && ! ${positional} && abrt "Unknown option ${1}"
    ${SUMMARY_SET} && BODY=${1} || SUMMARY=${1} SUMMARY_SET=true
}

while ((${#})) ; do
	s= i=0
    case "${1}" in
        -\?|--help)
            help
            exit 0
            ;;
        -v|--version)
            echo "${SELF} ${VERSION}"
            exit 0
            ;;
        -u|--urgency|--urgency=*)
            [[ "${1}" = --urgency=* ]] && s=${1#*=} || { shift ;s=${1} ; }
            process_urgency "${s}"
            ;;
        -t|--expire-time|--expire-time=*)
            [[ "${1}" = --expire-time=* ]] && EXPIRE_TIME=${1#*=} || { shift ;EXPIRE_TIME=${1} ; }
            ;;
        -f|--force-expire)
            export EXPLICIT_CLOSE=true # only export if explicitly set
            ;;
        -a|--app-name|--app-name=*)
            [[ "${1}" = --app-name=* ]] && APP_NAME=${1#*=} || { shift ;APP_NAME=${1} ; }
            export APP_NAME # only export if explicitly set
            ;;
        -i|--icon|--icon=*)
            [[ "${1}" = --icon=* ]] && ICON=${1#*=} || { shift ;ICON=${1} ; }
            ;;
        -c|--category|--category=*)
            [[ "${1}" = --category=* ]] && s=${1#*=} || { shift ;s=${1} ; }
            process_category "${s}"
            ;;
        -h|--hint|--hint=*)
            [[ "${1}" = --hint=* ]] && s=${1#*=} || { shift ;s=${1} ; }
            process_hint "${s}"
            ;;
        -o | --action | --action=*)
            [[ "${1}" == --action=* ]] && s=${1#*=} || { shift ;s=${1} ; }
            process_action "${s}"
            ;;
        -d | --default-action | --default-action=*)
            [[ "${1}" == --default-action=* ]] && s=${1#*=} || { shift ;s=${1} ; }
            process_special_action default "${s}"
            ;;
        -l | --close-action | --close-action=*)
            [[ "${1}" == --close-action=* ]] && s=${1#*=} || { shift ;s=${1} ; }
            process_special_action close "${s}"
            ;;
        -p|--print-id)
            PRINT_ID=true
            ;;
        -r|--replace|--replace=*)
            [[ "${1}" = --replace=* ]] && ID=${1#*=} || { shift ;ID=${1} ; }
            ;;
        -R|--replace-file|--replace-file=*)
            [[ "${1}" = --replace-file=* ]] && ID_FILE=${1#*=} || { shift ;ID_FILE=${1} ; }
            [[ -s "${ID_FILE}" ]] && read ID < "${ID_FILE}"
            ;;
        -s|--close|--close=*)
            [[ "${1}" = --close=* ]] && i=${1#*=} || { shift ;i=${1} ; }
            ((${i}<1)) && ((${ID}>0)) && i=${ID}
            ((${i}>0)) && notify_close ${i} ${EXPIRE_TIME}
            exit ${?}
            ;;
        --)
            positional=true
            ;;
        *)
            process_posargs "${1}"
            ;;
    esac
    shift
done

# build the special strings
actions="$(concat_actions "${ACTIONS[@]}")"
HINTS=("$(make_hint byte urgency "${URGENCY}")" "${HINTS[@]}")
hints="$(concat_hints "${HINTS[@]}")"
typeset -i OLD_ID=${ID} NEW_ID=0

# send the dbus message, collect the notification ID
s=$(gdbus call ${NOTIFY_ARGS[@]} \
	--method org.freedesktop.Notifications.Notify \
	"${APP_NAME}" ${ID} "${ICON}" "${SUMMARY}" "${BODY}" \
	"${actions}" "${hints}" "int32 ${EXPIRE_TIME}")

# process the ID
s=${s%,*} NEW_ID=${s#* }
((${NEW_ID}>0)) || abrt "invalid notification ID from gdbus"
((${OLD_ID}>0)) || ID=${NEW_ID}
[[ "${ID_FILE}" ]] && ((${OLD_ID}<1)) && echo ${ID} > "${ID_FILE}"
${PRINT_ID} && echo ${ID}

# launch the action handler
((${#ACTION_COMMANDS[@]}>0)) && setsid -f "${ACTION_HANDLER}" ${ID} "${ACTION_COMMANDS[@]}" >&- 2>&- &

# bg task to wait and then close notification
${EXPLICIT_CLOSE} && ((${EXPIRE_TIME}>0)) && setsid -f ${0} -t ${EXPIRE_TIME} -s ${ID} >&- 2>&- <&- &

${DEBUG_NOTIFY_SEND} && set >&2
