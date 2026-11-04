#!/bin/sh

# 0.4.1

# Allow-list (ADR-0004): this script starts only these services. Adding one means adding it here in the same diff.
#   dispatch + patched rmm (ADR-0008), ntpd, httpd, dropbear, mqttv4, mqtt-config, conf2mqtt.sh,
#   h264grabber (low), rRTSPServer and wd_rtsp.sh (the watchdog starts rRTSPServer), crond,
#   mqtt_advertise/startup.sh, check_update.sh.
# Dropped for this camera: cloud branch, ONVIF, FTP, telnetd, FTP upload, wpa/firmware upgrade hooks,
#   cloudAPI copies, framefinder (binary absent).
# Still to go in a later step: the hourly clean_records.sh cron and check_update.sh (TSK-004 criterion 1).

CONF_FILE="etc/system.conf"

if [ -d "/tmp/sd/yi-hack-v5" ]; then
        YI_HACK_PREFIX="/tmp/sd/yi-hack-v5"
elif [ -d "/home/yi-hack-v5" ]; then
        YI_HACK_PREFIX="/home/yi-hack-v5"
fi

YI_HACK_VER=$(cat /tmp/sd/yi-hack-v5/version)
MODEL_SUFFIX=$(cat /home/app/.camver)

YI_HACK_UPGRADE_PATH="/tmp/sd/$MODEL_SUFFIX"

get_config()
{
    key=$1
    grep -w $1 $YI_HACK_PREFIX/$CONF_FILE | cut -d "=" -f2 | awk 'NR==1 {print; exit}'
}

export LD_LIBRARY_PATH=/lib:/usr/lib:/home/lib:/home/app/locallib:/home/hisiko/hisilib:/tmp/sd/yi-hack-v5/lib:/home/yi-hack-v5/lib
export PATH=/usr/bin:/usr/sbin:/bin:/sbin:/home/base/tools:/home/yi-hack-v5/bin:/home/app/localbin:/home/base:/tmp/sd/yi-hack-v5/bin:/tmp/sd/yi-hack-v5/sbin:/tmp/sd/yi-hack-v5/usr/bin:/tmp/sd/yi-hack-v5/usr/sbin:/home/yi-hack-v5/sbin

#if [ ! -L "/var/run/utmp" ]; then
#  ln -sf /dev/null /var/run/utmp
#fi

#reversing symlinks
if [ -L "/var/run/utmp" ]; then
  rm /var/run/utmp
  reboot
fi

if [ ! -L "~/.ash_history" ]; then
  ln -sf /dev/null ~/.ash_history
fi

if [ ! -L "/home/yi-hack-v5/.ash_history" ]; then
  ln -sf /dev/null /home/yi-hack-v5/.ash_history
fi

ulimit -s 1024
mkdir /dev/shm

# Remove core files, if any
rm -f $YI_HACK_PREFIX/bin/core
rm -f $YI_HACK_PREFIX/www/cgi-bin/core

touch /tmp/httpd.conf

# Manual Wi-Fi config
if [ -f /tmp/sd/recover/configure_wifi.cfg ]; then
	mv /tmp/sd/recover/configure_wifi.cfg /tmp/configure_wifi.cfg
	sync
	sh $YI_HACK_PREFIX/script/configure_wifi.sh
fi

if [ -f "/tmp/sd/recover/mtdblock2_recover.bin" ]; then
	sync
	sh $YI_HACK_PREFIX/script/configure_wifi.sh
fi
$YI_HACK_PREFIX/script/check_conf.sh

hostname -F $YI_HACK_PREFIX/etc/hostname

export TZ=$(get_config TIMEZONE)

if [[ $(get_config SWAP_FILE) == "yes" ]] || [[ $MODEL_SUFFIX == "yi_dome" ]] || [[ $MODEL_SUFFIX == "yi_home" ]] ; then
    SD_PRESENT=$(mount | grep mmc | grep -c ^)
    if [[ $SD_PRESENT -ge 1 ]]; then
        if [[ -f /tmp/sd/swapfile ]]; then
            swapon /tmp/sd/swapfile
        else
            dd if=/dev/zero of=/tmp/sd/swapfile bs=1M count=64
            chmod 0600 /tmp/sd/swapfile
            mkswap /tmp/sd/swapfile
            swapon /tmp/sd/swapfile
        fi
        sysctl -w vm.dirty_background_ratio=2
        sysctl -w vm.dirty_ratio=5
        sysctl -w vm.dirty_writeback_centisecs=100
        sysctl -w vm.dirty_expire_centisecs=500
        sysctl -w vm.vfs_cache_pressure=200
        sysctl -w vm.swappiness=60
        sysctl -w vm.laptop_mode=5
    fi
fi

if [[ x$(get_config USERNAME) != "x" ]] ; then
    USERNAME=$(get_config USERNAME)
    PASSWORD=$(get_config PASSWORD)
    echo "/:$USERNAME:$PASSWORD" >> /tmp/httpd.conf
    chmod 0600 /tmp/httpd.conf
fi

if [[ x$(get_config SSH_PASSWORD) != "x" ]] ; then
    SSH_PASSWORD=$(get_config SSH_PASSWORD)
#    PASSWORD_MD5="$(echo "${SSH_PASSWORD}" | mkpasswd --method=des --stdin)"
    echo root:$SSH_PASSWORD | chpasswd --md5
#    cp -f "/etc/passwd" "/tmp/sd/yi-hack-v5/etc/passwd"
#    sed -i 's|^root::|root:'${PASSWORD_MD5}':|g' "/etc/passwd"
#    sed -i 's|/root|/tmp/sd/yi-hack-v5|g' "/etc/passwd"
#    mount --bind "/tmp/sd/yi-hack-v5/etc/passwd" "/etc/passwd"
#    cp -f "/etc/shadow" "/tmp/sd/yi-hack-v5/etc/shadow"
#    sed -i 's|^root::|root:'${PASSWORD_MD5}':|g' "/etc/shadow"
#    mount --bind "/tmp/sd/yi-hack-v5/etc/shadow" "/etc/shadow"
fi

case $(get_config RTSP_PORT) in
    ''|*[!0-9]*) RTSP_PORT=554 ;;
    *) RTSP_PORT=$(get_config RTSP_PORT) ;;
esac
case $(get_config HTTPD_PORT) in
    ''|*[!0-9]*) HTTPD_PORT=80 ;;
    *) HTTPD_PORT=$(get_config HTTPD_PORT) ;;
esac

# Copy library files for older versions (just in case the below firmware check is failed)
if [ ! -d "/home/yi-hack-v5/lib" ]; then
        mkdir -p "/home/yi-hack-v5/lib"
        cp -a /tmp/sd/yi-hack-v5/lib/. /home/yi-hack-v5/lib/
fi

# Version Firmware Check
if [ -f "/home/yi-hack-v5/version" ]; then
  version=$(cat /home/yi-hack-v5/version)
  if [[ "$version" != "0.4.1" ]]; then
    echo "Your baseline $version (rootfs and home partitions) is incorrect. Ignore if you are using a pre-release version. Please refer to https://github.com/alienatedsec/yi-hack-v5/discussions/267"
    echo "Your baseline $version (rootfs and home partitions) is incorrect, Ignore if you are using a pre-release version. Please refer to https://github.com/alienatedsec/yi-hack-v5/discussions/267" > "/tmp/sd/hackerror.txt"
  fi
else
  echo "Version file does not exist. Your SD card is not FAT32 to load the latest firmware correctly. Go to https://github.com/alienatedsec/yi-hack-v5/discussions/267"
  echo "Version file does not exist. Your SD card is not FAT32 to load the latest firmware correctly. Go to https://github.com/alienatedsec/yi-hack-v5/discussions/267" > "/tmp/sd/fat32error.txt"
fi

if [[ $(get_config NTPD) == "yes" ]] ; then
    # Wait until all the other processes have been initialized
    sleep 5 && ntpd -p $(get_config NTP_SERVER) &
fi

    (
        cd /home/app
        killall dispatch
        LD_PRELOAD=/home/yi-hack-v5/lib/ipc_multiplex.so ./dispatch &
        sleep 3
        if [[ $(get_config TIME_OSD) == "yes" ]] ; then
            echo -ne '\x01\x00\x00\x00' | dd of=/tmp/mmap.info bs=1 seek=0 count=4 conv=notrunc
        fi
        LD_LIBRARY_PATH="/home/yi-hack-v5/lib:/lib:/home/lib:/home/app/locallib:/home/hisiko/hisilib" /tmp/sd/yi-dome-hack/rmm-no-audio/rmm &
		sleep 8
		sleep 4
    )

if [[ $(get_config HTTPD) == "yes" ]] ; then
    mkdir -p /tmp/sd/record
    mkdir -p /tmp/sd/yi-hack-v5/www/record
    mount --bind /tmp/sd/record /tmp/sd/yi-hack-v5/www/record
    httpd -p $HTTPD_PORT -h $YI_HACK_PREFIX/www/ -c /tmp/httpd.conf
fi

if [[ $(get_config SSHD) == "yes" ]] ; then
mkdir -p $YI_HACK_PREFIX/etc/dropbear
    if [ ! -f $YI_HACK_PREFIX/etc/dropbear/dropbear_ecdsa_host_key ]; then
        dropbearkey -t ecdsa -f /tmp/dropbear_ecdsa_host_key
        mv /tmp/dropbear_ecdsa_host_key $YI_HACK_PREFIX/etc/dropbear/
    fi
    chmod 0600 $YI_HACK_PREFIX/etc/dropbear/*
    dropbear -R -B
fi

mqttv4 &

if [[ $(get_config MQTT) == "yes" ]] ; then
    mqtt-config &
    $YI_HACK_PREFIX/script/conf2mqtt.sh &
fi

if [[ $RTSP_PORT != "554" ]] ; then
    D_RTSP_PORT=:$RTSP_PORT
fi

if [[ $HTTPD_PORT != "80" ]] ; then
    D_HTTPD_PORT=:$HTTPD_PORT
fi

if [[ $(get_config SNAPSHOT) == "no" ]] ; then
    touch /tmp/snapshot.disabled
fi

if [[ $(get_config SNAPSHOT_LOW) == "yes" ]] ; then
    touch /tmp/snapshot.low
fi

RRTSP_MODEL=$MODEL_SUFFIX
RRTSP_RES=$(get_config RTSP_STREAM)
RRTSP_AUDIO=$(get_config RTSP_AUDIO)
RRTSP_PORT=$(get_config RTSP_PORT)
RRTSP_USER=$USERNAME
RRTSP_PWD=$PASSWORD

# some non-working functions to be added later

if [[ $(get_config RTSP) == "yes" ]] ; then

    if [[ $MODEL_SUFFIX == "yi_dome" ]] || [[ $MODEL_SUFFIX == "yi_home" ]] ; then
        HIGHWIDTH="1280"
        HIGHHEIGHT="720"
    else
        HIGHWIDTH="1920"
        HIGHHEIGHT="1080"
    fi
# The below section (except ONVIF) to be also copied to service.sh
    if [[ $(get_config RTSP_AUDIO) == "yes" ]]; then
        h264grabber -r audio -m $MODEL_SUFFIX -f &
    fi
    if [[ $(get_config RTSP_STREAM) == "low" ]]; then
        h264grabber -r low -m $MODEL_SUFFIX -f &
    fi
    if [[ $(get_config RTSP_STREAM) == "high" ]]; then
        h264grabber -r high -m $MODEL_SUFFIX -f &
    fi
    if [[ $(get_config RTSP_STREAM) == "both" ]]; then
         h264grabber -r low -m $MODEL_SUFFIX -f &
         h264grabber -r high -m $MODEL_SUFFIX -f &
    rRTSPServer -r $RRTSP_RES -a $RRTSP_AUDIO -p $RRTSP_PORT -u $RRTSP_USER -w $RRTSP_PWD &
    fi
#Seems to be killing the resource - fixed via #153
    $YI_HACK_PREFIX/script/wd_rtsp.sh &
#The above section (except ONVIF) to be also copied to service.sh
fi

# Add crontab
CRONTAB=$(get_config CRONTAB)
FREE_SPACE=$(get_config FREE_SPACE)
mkdir -p /var/spool/cron/crontabs/
if [ ! -z "$CRONTAB" ]; then
    echo "$CRONTAB" > /var/spool/cron/crontabs/root
fi
if [ "$FREE_SPACE" != "0" ]; then
    echo "0 * * * * /tmp/sd/yi-hack-v5/script/clean_records.sh $FREE_SPACE" > /var/spool/cron/crontabs/root
fi

/usr/sbin/crond -c /var/spool/cron/crontabs/

# Add MQTT Advertise
if [ -f "$YI_HACK_PREFIX/script/mqtt_advertise/startup.sh" ]; then
    $YI_HACK_PREFIX/script/mqtt_advertise/startup.sh
fi

# Remove log files written to SD on boot containing the WiFi password
#rm -f "/tmp/sd/log/log_first_login.tar.gz"
#rm -f "/tmp/sd/log/log_login.tar.gz"
#rm -f "/tmp/sd/log/log_p2p_clr.tar.gz"
#rm -f "/tmp/sd/log/log_wifi_connected.tar.gz"

if [ -f "/tmp/sd/yi-hack-v5/startup.sh" ]; then
    /tmp/sd/yi-hack-v5/startup.sh
fi

# First run on startup, then every day via crond
$YI_HACK_PREFIX/script/check_update.sh

crond -c $YI_HACK_PREFIX/etc/crontabs
