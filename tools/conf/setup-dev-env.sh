#!/bin/bash

# This script assumes its a part of the SchecterWolf/DevEnv repo

print_usage() {
cat << EOF >&2
Description:
This script sets up Schecter's prefered dev environment on virgin machines

Usage: $(basename "$0") [OPTIONS]

    -p, --pi        Use this flag if the Dev environment is being setup on a raspberry pi

EOF
exit 1
}

set -e

# File names
UDEV_MOUNT_SCRIPT="mount-microcontroller-usb.sh"
UDEV_RULE="60-microcontroller-usb.rules"
SYSTEM_UDEV_SERVICE="/lib/systemd/system/systemd-udevd.service"

# OPTIONS vars
HOST_IS_PI=0

# Runtime changes
CHANGED_BASHRC=0
NEEDS_REBOOT=0

# https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
POSITIONAL_PARAMS=""
while (( "$#" )); do
    case "$1" in
        -p|--pi)
            HOST_IS_PI=1
            shift
            ;;
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

DEV_DIR=$HOME/Dev
# Check if using the older dev dir name
if [ -d $HOME/DevEnv ]; then
    DEV_DIR=$HOME/DevEnv
fi

# Paths
DEV_DIR_CONF="$DEV_DIR/tools/conf/"
DEV_DIR_UDEV="$DEV_DIR/tools/udev/"

# Install dev binaries
sudo apt install build-essential git vim meld xclip screen notify-osd gitk git-gui
sudo apt autoremove

# Copy over the bashrc
if ! diff $HOME/.bashrc ${DEV_DIR_CONF}bashrc &>/dev/null ; then
    echo "Installing dev bashrc"
    set -x
    cp ${DEV_DIR_CONF}bashrc $HOME/.bashrc
    { set +x; } 2>/dev/null
    CHANGED_BASHRC=1
fi

# Copying vim vundle plugin
if [ ! -d "$HOME/.vim/bundle/Vundle.vim" ]; then
    echo "Installing vim vundle plugin manager"
    set -x
    git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
    { set +x; } 2>/dev/null
fi

# Install the dev vimrc and vim plugins
if ! diff $HOME/.vimrc ${DEV_DIR_CONF}vimrc ; then
    echo "Installing dev vimrc"
    set -x
    cp ${DEV_DIR_CONF}vimrc $HOME/.vimrc
    { set +x; } 2>/dev/null

    echo "Installing vim plugins"
    vim -c "PluginInstall" -c "qa!"
fi

# Raspberry pi specific environment setup
if [ "$HOST_IS_PI" -eq 1 ]; then
    echo "Setting up some extra things for raspberry pi host"

    UDEV_RULE_FILE="/etc/udev/rules.d/$UDEV_RULE"
    DEV_ENV_MOUNT_SCRIPT=$DEV_DIR_UDEV$UDEV_MOUNT_SCRIPT

    # Microcontroller udev setup
    if [ ! -f "/usr/local/sbin/$UDEV_MOUNT_SCRIPT" ]; then
        set -x
        sudo ln -s $DEV_ENV_MOUNT_SCRIPT /usr/local/sbin/

        # Make sure the mount script is owned by root, since the script will be called by root (udev)
        sudo chown root:root $DEV_ENV_MOUNT_SCRIPT
        sudo chmod 744 $DEV_ENV_MOUNT_SCRIPT
        { set +x; } 2>/dev/null
    fi
    if [ ! -f "$UDEV_RULE_FILE" ]; then
        set -x
        sudo cp $DEV_DIR_UDEV$UDEV_RULE /etc/udev/rules.d/
        sudo chown root:root $UDEV_RULE_FILE
        sudo chmod 644 $UDEV_RULE_FILE
        { set +x; } 2>/dev/null
    fi

    # systemd-udevd runs in its own file system, which are not reflected on the main host file system
    if ! grep "PrivateMounts=no" $SYSTEM_UDEV_SERVICE ; then
        set -x
        # If this doesnt work see:
        # https://unix.stackexchange.com/questions/152485/mount-is-not-executed-when-called-by-udev/154318#154318
        /usr/bin/sed -i 's/PrivateMounts=.*/PrivateMounts=no/' $SYSTEM_UDEV_SERVICE
        NEEDS_REBOOT=1
        { set +x; } 2>/dev/null
    fi
fi

# Print reminders
if [ "$CHANGED_BASHRC" -eq 1 ]; then
    echo "bashrc was changed! to apply new changes, make sure to run 'source ~/.bashrc'"
fi

# Trigger restart if needed
if [ "$NEEDS_REBOOT" -eq 1 ]; then
    echo "Device need to be rebooted, press any key to continue"
fi

