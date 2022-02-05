#!/bin/bash

# Default bootloader links for various boards.
# These should be updated to the most recent whenever they are distributed
DEFAULT_nRF52840="https://downloads.circuitpython.org/bin/itsybitsy_nrf52840_express/en_US/adafruit-circuitpython-itsybitsy_nrf52840_express-en_US-6.1.0.uf2"
DEFAULT_QtPyM0="https://downloads.circuitpython.org/bin/qtpy_m0/en_US/adafruit-circuitpython-qtpy_m0-en_US-6.1.0.uf2"
DEFAULT_TrinketM0="https://downloads.circuitpython.org/bin/trinket_m0/en_US/adafruit-circuitpython-trinket_m0-en_US-6.1.0.uf2"
DEFAULT_Pico="https://downloads.circuitpython.org/bin/raspberry_pi_pico/en_US/adafruit-circuitpython-raspberry_pi_pico-en_US-7.1.1.uf2"

print_usage()
{
	cat << EOF >&2
Description:
Script for installing the adafruit circuitpython booloader onto a microcontroller
that supports it.
The controller flag indicates which board is being used

Usage: $(basename "$0") <Controller flag> <CPython download link>

    -N      NUKEs the controllers flash memory

Controller flags:
    -i      ItsyBitsy
    -q      QT Py
    -t      Trinket
    -p      Raspberry Pi Pico

Example CPython bootloader links:
nRF52840
    $DEFAULT_nRF52840
QtPy M0
    $DEFAULT_QtPyM0
Trinket M0
    $DEFAULT_TrinketM0
Raspberry Pi Pico
    $DEFAULT_Pico

EOF
exit 1
}

DOWNLOAD_LINK=""

# Nuke uf2 file
NUKE_FILE="$HOME/Dev/tools/flash_nuke.uf2"

# Make sure to update the Controller flag options when adding support for a new board
CONTROLLER_NAME=""

NUKE_CONTROLLER=0
DEFAULT_BOOTLOADER_LINK=""


# https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
POSITIONAL_PARAMS=""
while (( "$#" )); do
	case "$1" in
		-i)
			CONTROLLER_NAME="ITSY840BOOT"
            DEFAULT_BOOTLOADER_LINK=$DEFAULT_nRF52840
			shift
			;;
		-q)
			CONTROLLER_NAME="QTPY_BOOT"
            DEFAULT_BOOTLOADER_LINK=$DEFAULT_QtPyM0
			shift
			;;
		-t)
			CONTROLLER_NAME="TRINKETBOOT"
            DEFAULT_BOOTLOADER_LINK=$DEFAULT_TrinketM0
			shift
			;;
        -p)
            CONTROLLER_NAME="RPI-RP2"
            DEFAULT_BOOTLOADER_LINK=$DEFAULT_Pico
            shift
            ;;
        -N)
            NUKE_CONTROLLER=1
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

DOWNLOAD_LINK=$1

# Ubuntu mount location for disk drives
CONTROLLER_MOUNT_LOCATION="/media/$USER/$CONTROLLER_NAME/"

# Verify we have the needed information
if [ -z "$DOWNLOAD_LINK" ]; then
    DOWNLOAD_LINK=$DEFAULT_BOOTLOADER_LINK
fi
if [ -z "$CONTROLLER_NAME" ]; then
	echo "Controller flag missing"
	print_usage
fi

# Perform nuke if requested
if [ "$NUKE_CONTROLLER" -eq 1]; then
    echo "Nuking controller: $CONTROLLER_NAME"
    cp $NUKE_FILE $CONTROLLER_MOUNT_LOCATION

    # Wait until the board comes back up
    read -p "Once the board is accessible again, press any key. You may have to re-connect the controller USB."
fi

TMP_FILE=$(mktemp "/tmp/CP-XXXXX.u2f")
set -x
wget $DOWNLOAD_LINK -O $TMP_FILE
{ set +x; } 2>/dev/null

# On adafruit microcontrollers, the user had to double press the on-board reset button
# It will then appear as a mountable disk drive.
# https://learn.adafruit.com/adafruit-itsybitsy-nrf52840-express/circuitpython
read -p "Double-press the on-board reset button, press any key once the board is mounted as an fs.
If there is none, then just skip this step."

set -x
cp -v $TMP_FILE $CONTROLLER_MOUNT_LOCATION
sync
{ set +x; } 2>/dev/null

rm $TMP_FILE
