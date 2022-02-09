#!/bin/bash

print_usage() {
cat << EOF >&2
Description:
Raspberry Pi SD card utility tools. This script makes "out-of-band" changes to the Raspberry Pi OS
configuration file. Typically using 'raspi-config' natively on the Pi is preffered, however some
things need to be configured before first boot

Usage: $(basename "$0") [OPTIONS]

Options:
    -s, --enable-serial     Enable the serial console
EOF
exit 1
}

ENABLE_SERIAL=0

PI_OS_CONFIG_FILE="/media/$USER/boot/config.txt"

# https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
POSITIONAL_PARAMS=""
while (( "$#" )); do
    case "$1" in
        -s| --enable-serial)
            ENABLE_SERIAL=1
            shift
            ;;
		--help|-*|--*=) # unsupported flags
			print_usage
			exit 1
			;;
		*) # preserve positional arguments
			POSITIONAL_PARAMS="$POSITIONAL_PARAMS $1"
			shift
			;;
	esac
done
eval set -- "$POSITIONAL_PARAMS"

if [ "$ENABLE_SERIAL" -eq 1 ]; then
    echo "Enabling serial console for the Raspberry Pi OS"
    echo "If unable to connect over serial USB, make sure the correct drivers are installed."
    echo "If this a VM, the host will need the drivers installed."

    set -x
    echo "" >> $PI_OS_CONFIG_FILE
    echo "enable_uart=1" >> $PI_OS_CONFIG_FILE
    { set +x; } 2>/dev/null
fi
