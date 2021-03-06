#!/usr/bin/env bash

#/*******************************************************************************
# Copyright (c) 2012 IBM Corp.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#/*******************************************************************************

cd ~
source $(echo $0 | sed -e "s/\(.*\/\)*.*/\1.\//g")/cb_common.sh

set_load_gen $@

FILEBENCH_IP=`get_ips_from_role filebench`

FB_BINARY_NAME=filebench
FILEBENCH_DATA_DIR=$(get_my_ai_attribute_with_default filebench_data_dir /fbtest)
FILEBENCH_DATA_FSTYP=$(get_my_ai_attribute_with_default filebench_data_fstyp ext4)
FILEBENCH_DATA_VOLUME=$(get_my_ai_attribute_with_default filebench_data_volume NONE)

filebench=`which ${FB_BINARY_NAME}`

cd ~

PERSONALITY_TEMPLATE="cb_"${LOAD_PROFILE}".f"
PERSONALITY_FILE=`mktemp`

cat ${PERSONALITY_TEMPLATE} > ${PERSONALITY_FILE}

sed -i "s^FILEBENCH_DATA_DIR^$FILEBENCH_DATA_DIR^g" ${PERSONALITY_FILE}
sed -i "s^LOAD_DURATION^$LOAD_DURATION^g" ${PERSONALITY_FILE}
sed -i "s^usage \"^#usage \"^g" ${PERSONALITY_FILE}

if [[ $(sudo cat /etc/*release* | grep DISTRIB_RELEASE | cut -d '=' -f 2) == "18.04" ]]
then
    echo 0 | sudo tee /proc/sys/kernel/randomize_va_space >/dev/null 2>&1
    if [[ $(sudo cat /proc/sys/kernel/randomize_va_space) -ne 0 ]]
    then
        syslog_netcat "\"/proc/sys/kernel/randomize_va_space\" in non-zero. Filebench will hang!"
    fi
fi

CMDLINE="sudo ${filebench} -f ${PERSONALITY_FILE}"

execute_load_generator "${CMDLINE}" ${RUN_OUTPUT_FILE} ${LOAD_DURATION}

#tp=`cat ${RUN_OUTPUT_FILE} | grep Summary | cut -d "," -f 2 | tr -d ' ' | sed 's/\(.*\)...../\1/'`
tp=$(cat ${RUN_OUTPUT_FILE} | grep Summary | awk '{ print $6 }')
#lat=`cat ${RUN_OUTPUT_FILE} | grep Summary | cut -d "," -f 6 | tr -d ' ' | sed 's/\(.*\)........./\1/'`
lat=$(cat ${RUN_OUTPUT_FILE} | grep Summary | awk '{ print $11 }' | sed 's^ms/op^^g')
#bw=`cat ${RUN_OUTPUT_FILE} | grep Summary | cut -d "," -f 4 | tr -d ' ' | sed 's/\(.*\)..../\1/'`
bw=$(cat ${RUN_OUTPUT_FILE} | grep Summary | awk '{ print $10 }' | sed 's^mb/s^^g')

~/cb_report_app_metrics.py \
latency:$lat:msec \
throughput:$tp:tps \
bandwidth:$bw:MBps \
$(common_metrics)   

unset_load_gen
rm ${PERSONALITY_FILE}

exit 0
