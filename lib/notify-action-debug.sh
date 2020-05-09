#!/bin/bash
printf -v DT "%(%Y%m%d%H%M%S)T_${RANDOM}" -1
LF=/tmp/.mainline_notify_action_${DT}.log
set > ${LF}
mainline-gtk --debug 2>&1 >> ${LF}
