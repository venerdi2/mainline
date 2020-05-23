#!/usr/bin/env bash

# notify-send.sh - drop-in replacement for notify-send with more features
# Copyright (C) 2015-2020 notify-send.sh authors (see AUTHORS file)

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

### 20200520 b.kenyon.w@gmail.com
### This copy is significantly modified for https://github.com/bkw777/mainline
### The associated notifty-action.sh is completely re-written
#
# * If expire time is 0, then ignore --force and don't try to calculate sleep time (divide by 0)
# * Derive sleep time from expire time without "bc" and without $(...)
# * Refactor to avoid unecessary child shells (still more could be done)
# * --close without ID gets ID from --replace-file
# * Fix quoting of action pairs so that -d default action, or any -o action with no label,
#   produces a blank button insted of a button with ''
# * Allow empty SUMMARY & BODY, treat missing as empty instead of error
# * Typeset -i to prevent ID from ever being '',
#   even if --replace-file is bad.
# * Export APP_NAME to notify-action.sh child process
# * setsid to free ourself from the action handler process

SELF=${0##*/}
VERSION="1.1-mainline"
ACTION_HANDLER=${0%/*}/notify-action.sh

NOTIFY_ARGS=(--session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications)
typeset -i EXPIRE_TIME=-1
typeset -i ID=0
URGENCY=1
HINTS=()
APP_NAME=${SELF}
PRINT_ID=false
FORCE_EXPIRE=false
unset ID_FILE
positional=false
SUMMARY_SET=false
SUMMARY=""
BODY=""

help() {
    cat <<EOF
Usage:
  notify-send.sh [OPTION...] <SUMMARY> [BODY] - create a notification

Help Options:
  -?|--help                         Show help options

Application Options:
  -u, --urgency=LEVEL               Specifies the urgency level (low, normal, critical).
  -t, --expire-time=TIME            Specifies the timeout in milliseconds at which to expire the notification.
  -f, --force-expire                Forcefully closes the notification when the notification has expired.
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
    [[ $? = 0 ]] || return 1
    name=${2}
    [[ "$type" = string ]] && command="\"$3\"" || command="$3"
    echo "\"$name\": <$type $command>"
}

concat_actions () {
    local r=${1} ;shift
    while [[ "${1}" ]] ;do r+=",${1}" ;shift ;done
    echo "[${r}]"
}

concat_hints () {
    local r=${1} ;shift
    while [[ "${1}" ]] ;do r+=",${1}" ;shift ;done
    echo "{${r}}"
}

notify_close () {
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
    [[ $? = 0 ]] || abrt "Invalid hint type \"${t}\". Valid types are int, double, string and byte."
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
    local k="${1}" c="${2}"
    [[ "${c}" ]] || abrt "Command must not be empty"
    ACTION_COMMANDS+=("${k}" "${c}")
    [[ "${k}" != "close" ]] && ACTIONS+=("\"${k}\",\"\"")
}

process_posargs () {
    [[ "${1}" = -* ]] && ! ${positional} && abrt "Unknown option ${1}"
    ${SUMMARY_SET} && BODY=${1} || SUMMARY=${1} SUMMARY_SET=true
}

while (( ${#} > 0 )) ; do
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
            [[ "${1}" = --urgency=* ]] && urgency="${1#*=}" || { shift; urgency="${1}"; }
            process_urgency "${urgency}"
            ;;
        -t|--expire-time|--expire-time=*)
            [[ "${1}" = --expire-time=* ]] && EXPIRE_TIME="${1#*=}" || { shift; EXPIRE_TIME="${1}"; }
            [[ "${EXPIRE_TIME}" =~ ^-?[0-9]+$ ]] || abrt "Invalid expire time: ${EXPIRE_TIME}"
            ;;
        -f|--force-expire)
            FORCE_EXPIRE=true
            ;;
        -a|--app-name|--app-name=*)
            [[ "${1}" = --app-name=* ]] && APP_NAME="${1#*=}" || { shift; APP_NAME="${1}"; }
            export APP_NAME
            ;;
        -i|--icon|--icon=*)
            [[ "${1}" = --icon=* ]] && ICON="${1#*=}" || { shift; ICON="${1}"; }
            ;;
        -c|--category|--category=*)
            [[ "${1}" = --category=* ]] && category="${1#*=}" || { shift; category="${1}"; }
            process_category "${category}"
            ;;
        -h|--hint|--hint=*)
            [[ "${1}" = --hint=* ]] && hint="${1#*=}" || { shift; hint="${1}"; }
            process_hint "${hint}"
            ;;
        -o | --action | --action=*)
            [[ "${1}" == --action=* ]] && action="${1#*=}" || { shift; action="${1}"; }
            process_action "${action}"
            ;;
        -d | --default-action | --default-action=*)
            [[ "${1}" == --default-action=* ]] && default_action="${1#*=}" || { shift; default_action="${1}"; }
            process_special_action default "${default_action}"
            ;;
        -l | --close-action | --close-action=*)
            [[ "${1}" == --close-action=* ]] && close_action="${1#*=}" || { shift; close_action="${1}"; }
            process_special_action close "${close_action}"
            ;;
        -p|--print-id)
            PRINT_ID=true
            ;;
        -r|--replace|--replace=*)
            [[ "${1}" = --replace=* ]] && ID=${1#*=} || { shift ;ID=${1} ; }
            ;;
        -R|--replace-file|--replace-file=*)
            [[ "${1}" = --replace-file=* ]] && filename="${1#*=}" || { shift; filename="${1}"; }
            [[ -s "${filename}" ]] && read ID < "${filename}"
            ID_FILE=${filename}
            ;;
        -s|--close|--close=*)
            [[ "${1}" = --close=* ]] && close_id="${1#*=}" || { shift; close_id="${1}"; }
            case "${close_id}" in ""|R|replace-file) [[ ${ID} -gt 0 ]] && close_id=${ID} ;; esac
            notify_close "${close_id}"
            exit $?
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
NEW_ID=$(gdbus call ${NOTIFY_ARGS[@]} \
	--method org.freedesktop.Notifications.Notify \
	"${APP_NAME}" "${ID}" "${ICON}" "${SUMMARY}" "${BODY}" \
	"${actions}" "${hints}" "int32 ${EXPIRE_TIME}" \
	|sed 's/(uint32 \([0-9]\+\),)/\1/g' )

# process the ID
[[ ${NEW_ID} -gt 0 ]] || abrt "invalid notification ID from gdbus"
[[ ${OLD_ID} = 0 ]] && ID=${NEW_ID}
[[ "${ID_FILE}" ]] && [[ ${OLD_ID} = 0 ]] && echo ${ID} > "${ID_FILE}"
${PRINT_ID} && echo ${ID}

# launch the action handler
[[ ${#ACTION_COMMANDS[@]} -gt 0 ]] && setsid -f "${ACTION_HANDLER}" "${ID}" "${ACTION_COMMANDS[@]}" >/dev/null 2>&1 &

# bg task to wait and then close notification
${FORCE_EXPIRE} && [[ ${EXPIRE_TIME} -gt 0 ]] && ( sleep ${EXPIRE_TIME:0:-3} ; notify_close ${ID} ) &
