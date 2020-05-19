#!/bin/bash
printf -v DT "%(%Y%m%d%H%M%S)T_${RANDOM}" -1
LF=/tmp/.mainline_notify_action_${DT}.log
echo ${DT} > ${LF}
printf "%s %s\n" "${0}" "${@}" >> ${LF}
set >> ${LF}
${@} 2>&1 >> ${LF}
