 #!/bin/bash

 ##
 # Expand root filesystem. The filesystem must be last fs on the disk.
 # A normal pi image have the following partition table.  
 # /<blockdev>1 - /boot
 # /<blockdev>2 - / 
 # This script will expand root tot he size of the disk. 
 # See: #https://github.com/RPi-Distro/raspi-config

do_expand_rootfs() {

  ROOT_PART=$(readlink /dev/root)
  PART_NUM=${ROOT_PART#mmcblk0p}


  LAST_PART_NUM=$(parted /dev/mmcblk0 -ms unit s p | tail -n 1 | cut -f 1 -d:)


  # Get the starting offset of the root partition
  PART_START=$(parted /dev/mmcblk0 -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d:)
  [ "$PART_START" ] || return 1
  # Return value will likely be error for fdisk as it fails to reload the
  # partition table because the root fs is mounted
  fdisk /dev/mmcblk0 <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF

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
    resize2fs /dev/root &&
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
  update-rc.d resize2fs_once defaults 
}

update_cmdtxt() {
  sed -i "s#init=/usr/bin/filesystem_scripts/expand_readwritefs.sh##" "/boot/cmdline.txt"
}

#Check for root
if [[ $EUID > 0 ]]; then
  echo "Please run as root user"
  exit 1
fi
#Do expand
echo "Expanding root filesystem"
do_expand_rootfs
update_cmdtxt
echo "REBOOTING NOW..."
sleep 3
reboot
