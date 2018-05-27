 #!/bin/bash

 ##
 # Expand /readwrite partition and filesystem. The filesystem must be last fs on the disk.
 # A normal centro image have the following partition table.  
 # /<blockdev>1 - /boot
 # /<blockdev>2 - / 
 # /<blockdev>3 - /readwrite
 # This script will expand /readwrite to the size of the disk. 
 # See: #https://github.com/RPi-Distro/raspi-config
do_expand_readwritefs() {
  #Note sure where this symlink is supposed to come from.
  #if ! [ -h /dev/readwrite ]; then
  #  whiptail --msgbox "/dev/readwrite does not exist or is not a symlink. Don't know how to expand" 20 60 2
  #  return 0
  #fi

  #RW_PART=$(readlink /dev/readwrite)
  #PART_NUM=${RW_PART#mmcblk0p}
  #if [ "$PART_NUM" = "$RW_PART" ]; then
  #  whiptail --msgbox "/dev/readwrite is not an SD card. Don't know how to expand" 20 60 2
  #  return 0
  #fi

  # NOTE: the NOOBS partition layout confuses parted. For now, let's only 
  # agree to work with a sufficiently simple partition layout

  #if [ "$PART_NUM" -ne 3 ]; then
  #  whiptail --msgbox "Your partition layout is not currently supported by this tool. You are probably using NOOBS, in which case your root filesystem is already expanded anyway." 20 60 2
  #  return 0
  #fi
  PART_NUM=3
  LAST_PART_NUM=$(parted /dev/mmcblk0 -ms unit s p | tail -n 1 | cut -f 1 -d:)

  #if [ "$LAST_PART_NUM" != "$PART_NUM" ]; then
  #  whiptail --msgbox "/dev/readwrite is not the last partition. Don't know how to expand" 20 60 2
  #  return 0
  #fi

  # Get the starting offset of the readwrite partition
  PART_START=$(parted /dev/mmcblk0 -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d:)
  [ "$PART_START" ] || return 1
  # Return value will likely be error for fdisk as it fails to reload the
  # partition table because the root fs is mounted
  echo $PART_START
  echo ${PART_START//s}
  fdisk /dev/mmcblk0 <<EOF
p
d
$PART_NUM
F
n
p
3
${PART_START//s}

p
w
EOF
  ASK_TO_REBOOT=1

  # now set up an init.d script
cat <<\EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 2 3 4 5 S
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs /dev/readwrite &&
    rm /etc/init.d/resize2fs_once &&
    update-rc.d resize2fs_once remove &&
    log_end_msg $?
    ;;
  *)
    echo "Usage: $0 start" >&2
    exit 3
    ;;
esac
EOF
  chmod +x /etc/init.d/resize2fs_once &&
  update-rc.d resize2fs_once defaults &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "/readwrite partition has been resized.\nThe filesystem will be enlarged upon the next reboot" 20 60 2
  fi
}

#Check for root
if [[ $EUID > 0 ]]; then
  echo "Please run as root user"
  exit 1
fi
#Do expand
echo "Expanding root filesystem"
do_expand_rootfs
echo "REBOOTING NOW..."
sleep 3
reboot
