#!/bin/bash

# This script assumes that the ardui-cli is in the Dev/tools folder and the adafruit config file
# is in Dev/tools/conf

print_usage() {
	cat << EOF >&2
Description:
Utility for making building arduino sketches and installing them onto adafruit compatibile boards
Note: The arduino main sketch must be named the same as the sketch dir.

Usage: $(basename "$0") <target board flag> </abs/path/to/sketch/dir/> [OPTIONS]

Required:
	-b, --board 	Target board
			   Supported boards:
			      itsybitsy52840
 			      trinket_m0
				  pico

Options:
	-I, --init 		Installs the supported arduino boards to the tool
	-L, --list-boards 	Lists the install microcontroller boards

	-l, --load-libs 	Load the libraries defined in deps.txt to the tool
				(Thats located in the same dir as the arduino sketch)
	-u, --upload 		Upload the sketch after its been compiled
	-p, --prod 		Production build (-DNDEBUG)
						[Cant seem to get this to work]
EOF
exit 1
}

# Adafruit arduino config file
ARDUINO_CLI_VENDOR_CONF="$HOME/Dev/tools/conf/arduino-cli.yaml"

# Board port name. This seems to be where ubuntu default "mounts" the arduino boards
PORT_NAME="/dev/ttyACM0"

# Local libs (AKA non-3rd party libs)
LOCAL_LIBS="--build-property build.extra_flags=-I$HOME/Dev/lib/local/"

INIT_CLI=0
LOAD_LIBS=0
LIST_BOARDS=0
INSTALL_PARAMS=""
TARGET_BOARD=""
BUILD_PROPS=""

# https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
POSITIONAL_PARAMS=""
while (( "$#" )); do
	case "$1" in
		-b|--board)
			TARGET_BOARD=$2
			shift 2
			;;
		-I|--init)
			INIT_CLI=1
			shift
			;;
		-L| --list-boards)
			LIST_BOARDS=1
			shift
			;;
		-l| --load-libs)
			LOAD_LIBS=1
			shift
			;;
		-u| --upload)
			INSTALL_PARAMS="-u -p $PORT_NAME"
			shift
			;;
		-p| --prod)
			BUILD_PROPS='--build-property build.extra_flags+="-DNDEBUG"'
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

SKETCH_DIR=$1
ARDUINO_DEPS_FILE="${SKETCH_DIR}/deps.txt"
ARDUINO_BOARD_FILE="${SKETCH_DIR}/board.txt"

# These args are for init or info only. They run then exit the script (IE no compilation)
SHORT_CIRCUIT=0

set -e

# Installs arduino core support for the boards we have
if [ "$INIT_CLI" -eq 1 ]; then
	set -x
	arduino-cli update --config-file $ARDUINO_CLI_VENDOR_CONF
	arduino-cli core update-index --config-file $ARDUINO_CLI_VENDOR_CONF
	# Boards with the nRF52 module
	arduino-cli core install adafruit:nrf52 --config-file $ARDUINO_CLI_VENDOR_CONF
	# ARM Cortex-M0+ boards
	arduino-cli core install arduino:samd --config-file $ARDUINO_CLI_VENDOR_CONF
	arduino-cli core install adafruit:samd --config-file $ARDUINO_CLI_VENDOR_CONF
	# Raspberry PI RP2040 boards
	arduino-cli core install rp2040:rp2040 --config-file $ARDUINO_CLI_VENDOR_CONF

    # Pupgrade
    arduino-cli core upgrade --config-file $ARDUINO_CLI_VENDOR_CONF

	{ set +x; } 2>/dev/null

	echo ""
	LIST_BOARDS=1
	SHORT_CIRCUIT=1
fi

# Show installed boards list
if [ "$LIST_BOARDS" -eq 1 ]; then
	#arduino-cli core list
    arduino-cli board listall
	SHORT_CIRCUIT=1
fi

# Exit script after terminal behavior runs
if [ "$SHORT_CIRCUIT" -eq 1 ]; then
	exit 0
fi

# Check board file
if [ -f "$ARDUINO_BOARD_FILE" ] && [ -z $TARGET_BOARD ]; then
    TARGET_BOARD=$(head -n 1 $ARDUINO_BOARD_FILE)
fi

# Check Required params
if [ -z $SKETCH_DIR ]; then
	echo "Missing arduino sketch dirname"
	print_usage
fi
if [ -z $TARGET_BOARD ]; then
	echo "Missing target board"
	print_usage
fi

# Install the arduino library dependencies
if [ -f "$ARDUINO_DEPS_FILE" ] && [ "$LOAD_LIBS" -eq 1 ]; then
	IFS=$'\r\n' GLOBIGNORE='*' command eval  'ary_lib_deps=($(cat $ARDUINO_DEPS_FILE))'
	for lib in "${ary_lib_deps[@]}"
	do
		# Skipping comments
		first_char=${lib::1}

		if [ "$first_char" != "#" ]; then
			set -x
			arduino-cli lib install "$lib" --config-file $ARDUINO_CLI_VENDOR_CONF
			{ set +x; } 2>/dev/null
		fi
	done
fi

# Get the board "FQBN"
FQBN=$(arduino-cli board listall | grep "$TARGET_BOARD " | awk '{print $NF}')
if [ -z $FQBN ]; then
	echo "Could not find the target board \"$TARGET_BOARD\". It may not be installed."
	echo "re-run with '-I' to install the arduino board"
	echo "or add the board support to this script"
	exit 1
fi

# Compile arduino sketch and optionally install
set -x
arduino-cli compile -b $FQBN -v $LOCAL_LIBS $INSTALL_PARAMS $BUILD_PROPS
{ set +x; } 2>/dev/null

