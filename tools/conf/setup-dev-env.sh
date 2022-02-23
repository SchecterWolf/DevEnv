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

# OPTIONS vars
HOST_IS_PI=0

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

# Install dev binaries
sudo apt install build-essential git vim meld xclip screen notify-osd gitk git-gui
sudo apt autoremove

# Copy over the bashrc
CHANGED_BASHRC=0
if ! diff $HOME/.bashrc $DEV_DIR/tools/conf/bashrc &>/dev/null ; then
    echo "Installing dev bashrc"
    set -x
    cp $DEV_DIR/tools/conf/bashrc $HOME/.bashrc
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
if ! diff $HOME/.vimrc $DEV_DIR/tools/conf/vimrc ; then
    echo "Installing dev vimrc"
    set -x
    cp $DEV_DIR/tools/conf/vimrc $HOME/.vimrc
    { set +x; } 2>/dev/null

    echo "Installing vim plugins"
    vim -c "PluginInstall" -c "qa!"
fi

# Raspberry pi specific environment setup
if [ "$HOST_IS_PI" -eq 1 ]; then
    echo "Setting up some extra things for raspberry pi host"

    set -x
    # Microcontroller udev setup
    if [ ! -f "/usr/local/sbin/$UDEV_MOUNT_SCRIPT" ]; then
        sudo ln -s $DEV_DIR/tools/udev/$UDEV_MOUNT_SCRIPT /usr/local/sbin/

        # Make sure the mount script is owned by root, since the script will be called by root (udev)
        sudo chown root:root $DEV_DIR/tools/udev/$UDEV_MOUNT_SCRIPT
        sudo chmod 744 $DEV_DIR/tools/udev/$UDEV_MOUNT_SCRIPT
    fi
    if [ ! -f "/etc/udev/rules.d/$UDEV_RULE" ]; then
        sudo cp $DEV_DIR/tools/udev/$UDEV_RULE /etc/udev/rules.d/
        sudo chown root:root /etc/udev/rules.d/$UDEV_RULE
        sudo chmod 644 /etc/udev/rules.d/$UDEV_RULE
    fi
    { set +x; } 2>/dev/null
fi

# Print reminders
if [ "$CHANGED_BASHRC" -eq 1 ]; then
    echo "bashrc was changed! to apply new changes, make sure to run 'source ~/.bashrc'"
fi
