#!/bin/bash

# Connect to serial console
# based on:
# https://learn.adafruit.com/welcome-to-circuitpython/advanced-serial-console-on-mac-and-linux

TTY_LOCATION="ttyACM0"

# Location where the ubuntu mounts most adafruit boards by default, for both CPython and arduino
BAUD_RATE=115200

print_usage()
{
	cat << EOF >&2
Description:
Connects a terminal to a microcontroller's serial console

Usage: $(basename "$0") [OPTIONS]

Options:
	-b <rate>			Baud rate (Defaults to 115200)
	-t <file>			TTY file (Defaults to ttyACM0)

EOF
exit 1
}

# https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
POSITIONAL_PARAMS=""
while (( "$#" )); do
	case "$1" in
		-b)
			BAUD_RATE=$2
			shift 2
			;;
		-t)
			TTY_LOCATION=$2
			shift 2
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

SERIAL_TTY="/dev/$TTY_LOCATION"

# Check if we have screen
which screen &> /dev/null
if [ $? -ne 0 ]; then
	echo "Screen manager not found. Need to install"
	sudo apt install screen
fi

# Check if we belong in the required group
GROUP=$(ls -l $SERIAL_TTY | awk '{print $4}')
if [[ "$(groups)" != *"$GROUP"* ]]; then
	echo "User $(whoami) is not in group $GROUP, need to add"
	sudo usermod -a -G $GROUP $(whoami)
	echo "User added to group, need to re-login for changes to take affect"

	# Connect to serial out
	sudo runuser -u $(whoami) -- screen $SERIAL_TTY $BAUD_RATE
else
	# Connect to serial out
	screen $SERIAL_TTY $BAUD_RATE
fi
