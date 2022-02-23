#!/bin/bash

# This script attempts to mount microcontrollers in a predictable way between desktop ubuntu and headless
# raspberry pi.
# This is so the scripts in ~/Dev/tools can work without special logic

# use 'tail -f /var/log/messages' to view syslog messages from this script
logger "$(basename "$0") called: $@"

print_usage()
{
cat << EOF >&2
Description:
Script invoked from udev in order to mount and unmount microcontroller usb devices.

Usage: $(basename "$0") <action> <device-path>

action          add - Used when a USB is plugged in
                remove - Used when a USB is unplugged
device-path SD* path of the USB that is plugged in
EOF
exit 1
}

# https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
POSITIONAL_PARAMS=""
while (( "$#" )); do
    case "$1" in
        --help|-*|--*=) # unsupported flags
            print_usage
            ;;
        *) # preserve positional arguments
            POSITIONAL_PARAMS="$POSITIONAL_PARAMS $1"
            shift
            ;;
    esac
done
eval set -- "$POSITIONAL_PARAMS"

ACTION=$1
DEVICE=$2

# Get the user that the device will be mounted under
USR=$(/usr/bin/users | /usr/bin/awk '{print $1;}')

# If no user is logged in, then default to UID 1000
if [ -z "$USR" ]; then
    USR=$(/usr/bin/id -nu 1000)
fi

# Mount location for ubuntu desktop
CONTROLLER_MOUNT_LOCATION="/media/$USR"

# Check required params
if [ -z "$ACTION" ]; then
    >&2 echo "No action specified"
    print_usage
fi
if [ "$ACTION" != "add" ] && [ "$ACTION" != "remove" ]; then
    >&2 echo "Invalid action given"
    print_usage
fi
if [ -z "$DEVICE" ]; then
    >&2 echo "No mount name specified"
    print_usage
fi

if [[ $DEVICE =~ ^sd[a-z]1$ ]]; then
    set -x
    DEVICE="/dev/$DEVICE"

    # Mount USB microcontroller
    if [ "$ACTION" == "add" ]; then
        LABEL_KEY_VALUE=$(/usr/sbin/blkid -o udev $DEVICE | /usr/bin/grep "ID_FS_LABEL=")
        LABEL=$(echo $LABEL_KEY_VALUE | /usr/bin/cut -c '13-')
        MOUNT_DIR="/media/$USR/$LABEL"
        USR_UID=$(/usr/bin/id -u $USR)
        USR_GID=$(/usr/bin/id -g $USR)

        /usr/bin/mkdir -m 664 -p $MOUNT_DIR

        logger "Mounting $DEVICE -> $MOUNT_DIR"
        STD_OUT=$(/usr/bin/mount -v -o umask=000,uid=$USR_UID,gid=$USR_GID $DEVICE $MOUNT_DIR)
        logger "$STD_OUT"
    fi

    # Umount USB microcontroller
    if [ "$ACTION" == "remove" ]; then
        MOUNT_DIR=$(/usr/bin/cat /etc/mtab | grep $DEVICE | awk '{print $2;}')

        logger "Unmounting $DEVICE => $MOUNT_DIR"
        /usr/bin/umount $MOUNT_DIR
        rm -rf $MOUNT_DIR

        # RM the user dir if there are no more mount points
        if [ ! "$(/usr/bin/ls -A /media/pi)" ]; then
            logger "/media/$USR dir is empting, RMing it"
            rm -rf "/media/$USR"
        fi
    fi
fi

