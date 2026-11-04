#!/bin/sh

# 0.4.1, yi-dome-hack: cloud is not watched (TSK-004 step 2); the polling loop reads /proc instead of spawning top, ps, netstat or grep (ADR-0004, ADR-0005).
# Behaviour matches stock: stock check_rtsp's "locked process" branch never ran, because $RTSP_PORT is unset
# in this script and its netstat count was always 0, so only the presence checks are kept.

script_name=$(basename -- "$0")

if pidof "$script_name" -o $$ >/dev/null;then
   echo "Already Running - Quitting"
   exit 1
fi

CONF_FILE="etc/system.conf"

YI_HACK_PREFIX="/tmp/sd/yi-hack-v5"
MODEL_SUFFIX=$(cat /home/app/.camver)

LOG_FILE="/tmp/sd/wd_rtsp.log"
#LOG_FILE="/dev/null"

get_config()
{
    key=$1
    grep -w $1 $YI_HACK_PREFIX/$CONF_FILE | cut -d "=" -f2 | awk 'NR==1 {print; exit}'
}

INTERVAL=10

# Read once: stock re-read these on every restart, and system.conf only changes with a reboot.
if [[ "$(get_config USERNAME)" != "" ]] ; then
    USERNAME=$(get_config USERNAME)
    PASSWORD=$(get_config PASSWORD)
fi

RTSP=$(get_config RTSP)
RRTSP_RES=$(get_config RTSP_STREAM)
RRTSP_AUDIO=$(get_config RTSP_AUDIO)
RRTSP_MODEL=$MODEL_SUFFIX
RRTSP_PORT=$(get_config RTSP_PORT)
if [ ! -z $USERNAME ]; then
    RRTSP_USER="-u $USERNAME"
fi
if [ ! -z $PASSWORD ]; then
    RRTSP_PWD="-w $PASSWORD"
fi

restart_rtsp()
{
    killall -q rRTSPServer
    rRTSPServer -r $RRTSP_RES -a $RRTSP_AUDIO -p $RRTSP_PORT $RRTSP_USER $RRTSP_PWD &
}

restart_grabber()
{
    killall -q rRTSPServer
    killall -q h264grabber
    if [[ $RRTSP_RES == "low" ]]; then
        h264grabber -r low -m $MODEL_SUFFIX -f &
    fi
    if [[ $RRTSP_RES == "high" ]]; then
        h264grabber -r high -m $MODEL_SUFFIX -f &
    fi
    if [[ $RRTSP_RES == "both" ]]; then
        h264grabber -r low -m $MODEL_SUFFIX -f &
        h264grabber -r high -m $MODEL_SUFFIX -f &
    fi
    if [[ $RRTSP_AUDIO == "yes" ]]; then
        h264grabber -r AUDIO -m $MODEL_SUFFIX -f &
    fi
    rRTSPServer -r $RRTSP_RES -a $RRTSP_AUDIO -p $RRTSP_PORT $RRTSP_USER $RRTSP_PWD &
}

restart_mqttv4()
{
    mqttv4 &
}

# One pass over /proc/<pid>/stat sets a flag per watched process name.
# A zombie still counts as running, as it did for the stock `ps | grep` checks.
scan_procs()
{
    SEEN=0
    HAS_GRABBER=0
    HAS_RTSP=0
    HAS_RMM=0
    HAS_MQTTV4=0
    for f in /proc/[0-9]*/stat; do
        { read l < $f; } 2>/dev/null || continue
        set -- $l
        SEEN=$((SEEN+1))
        case "$2" in
            "(h264grabber)") HAS_GRABBER=1 ;;
            "(rRTSPServer)") HAS_RTSP=1 ;;
            "(rmm)") HAS_RMM=1 ;;
            "(mqttv4)") HAS_MQTTV4=1 ;;
        esac
    done
}

check_grabber()
{
    if [ $HAS_GRABBER -eq 0 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - No running processes, restarting h264grabber ..." >> $LOG_FILE
        killall -q h264grabber
        sleep 1
        restart_grabber
        # restart_grabber also starts rRTSPServer; stop check_rtsp from starting a second one off the stale scan.
        HAS_RTSP=1
    fi
}

check_rtsp()
{
    if [ $HAS_RTSP -eq 0 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - No running processes, restarting rRTSPServer ..." >> $LOG_FILE
        killall -q rRTSPServer
        sleep 1
        restart_rtsp
    fi
}

check_rmm()
{
    # SEEN guards against an unreadable /proc rebooting the camera.
    if [ $SEEN -gt 0 ] && [ $HAS_RMM -eq 0 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - ./rmm is not running, restarting the camera  ..." >> $LOG_FILE
        reboot
    fi
}

check_mqttv4()
{
    if [ $HAS_MQTTV4 -eq 0 ]; then
        echo "$(date +'%Y-%m-%d %H:%M:%S') - No running processes, restarting mqttv4 ..." >> $LOG_FILE
        killall -q mqttv4
        sleep 1
        restart_mqttv4
    fi
}

if [[ $RTSP == "no" ]] ; then
    exit
fi

# Re-enabled when its starting
echo "$(date +'%Y-%m-%d %H:%M:%S') - Starting RTSP watchdog..." >> $LOG_FILE

while true
do
    scan_procs
    check_grabber
    check_rtsp
    check_rmm
    check_mqttv4
    sleep $INTERVAL
done
