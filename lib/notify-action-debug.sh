#!/bin/bash
printf -v DT "%(%Y%m%d%H%M%S)T_${RANDOM}" -1
LF=/tmp/.mainline_notify_action_${DT}.log
exec 2>${LF} >&2
ARGS=(${0} ${@})
set -x
set
${@}
