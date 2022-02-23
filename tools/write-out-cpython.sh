#!/bin/bash

print_usage() {
	cat << EOF >&2
Description:
Copies a source python file into an adafruit microcontroller as the "main" program.
Will copy all other python files in the same directory as the main python file into the
microcontroller.
Will copy required libraries listed in "requirements.txt" into the microcontroller.

Usage: $(basename "$0") </abs/path/code-file> [OPTIONS]

    -c, --compile-mpy       Compile python files to *.mpy before copying them to the
					controller
    -l, --load-libs         Load the libraries defined in the requirements.txt file
					(Thats located in the same dir as the code-file)
    -a, --accessories-load  Load the other python files in the same directory as the
					main py file
    -r, --reset-lib         Hard reset the library dir on the microcontroller
EOF
exit 1
}

# Drive name (https://learn.adafruit.com/welcome-to-circuitpython/the-circuitpy-drive)
DRIVE_NAME="CIRCUITPY"

# Code main file (Same link as above)
CODE_MAIN_FILE="code.py"

# This is just where ubuntu happens to mount disk drives
MOUNT_LOCATION="/media/$USER/$DRIVE_NAME/"

# (https://learn.adafruit.com/welcome-to-circuitpython/circuitpython-libraries)
LIB_SAVE_LOCATION="${MOUNT_LOCATION}lib/"

SAVE_LOCATION="${MOUNT_LOCATION}$CODE_MAIN_FILE"
LIB_SRC_LOCATION="$HOME/Dev/lib/"

RESET_LIBS=0
BUILD_MPY=0
LOAD_ACCESSORIES=0
LOAD_LIBS=0

# https://medium.com/@Drew_Stokes/bash-argument-parsing-54f3b81a6a8f
POSITIONAL_PARAMS=""
while (( "$#" )); do
	case "$1" in
		-c|--compile-mpy)
			MY_FLAG=1
			shift
			;;
		-a| --accessories-load)
			LOAD_ACCESSORIES=1
			shift
			;;
		-l| --load-libs)
			LOAD_LIBS=1
			shift
			;;
		-r| --reset-lib)
			RESET_LIBS=1
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

SAVE_FILE=$1
REQUIRED_LIBS_FILE=$(dirname $SAVE_FILE)"/requirements.txt"

if [ -z $SAVE_FILE ]; then
	print_usage
fi

set -e

# Make sure the microcontroller dir exists before continuing
if [ ! -d "$MOUNT_LOCATION" ]; then
    >&2 echo "Mount location does not exist: $MOUNT_LOCATION"
    exit 1
fi

copy_py() {
	if [ "$BUILD_MPY" -eq 1 ]; then
		set -x
		/usr/local/bin/mpy-cross $1
		{ set +x; } 2>/dev/null
		MPY=$(echo $1 | sed s/\.py/\.mpy/)
		set -x
		cp $MPY $2
		{ set +x; } 2>/dev/null
	else
		set -x
		cp $1 $2
		{ set +x; } 2>/dev/null
	fi
}

# Clear the lib folder if indicated
if [ "$RESET_LIBS" -eq 1 ]; then
	set -x
	rm -rf "${LIB_SAVE_LOCATION}"
	mkdir "${LIB_SAVE_LOCATION}"
    rm -rf ${MOUNT_LOCATION}*.py
	{ set +x; } 2>/dev/null
fi

# Copy the libraries
if [ -f "$REQUIRED_LIBS_FILE" ] && [ "$LOAD_LIBS" -eq 1 ]; then
	# Make sure the lib dir exists on the microconrtoller
	if [ ! -d "$LIB_SAVE_LOCATION" ]; then
		set -x
		mkdir -p $LIB_SAVE_LOCATION
		{ set +x; } 2>/dev/null
	fi

	# Add each indvidual lib
	ARY_REQUIRED_LIBS=($(cat $REQUIRED_LIBS_FILE))
	for LIB in "${ARY_REQUIRED_LIBS[@]}"
	do
		# Some libraries are nested, so we need to preserve the dir structure
		# I do this by iterating through the dirs and adding the ones that contain __init__.*
		module_path=""
		lib_dir_path=$(dirname $LIB)
		CONT=1
		while [ $CONT -eq 1 ]
		do
			if ! compgen -G "${LIB_SRC_LOCATION}${lib_dir_path}/__init__.*" > /dev/null; then
				CONT=0
			else
				if [ ! -z $module_path ]; then
					module_path="/$module_path"
				fi
				pop=$(echo ${lib_dir_path} | awk -F / '{print $(NF)}')
				module_path="${pop}${module_path}"
				lib_dir_path=$(echo $lib_dir_path | sed "s/\/$pop//")
			fi
		done
		if [ ! -z $module_path ]; then
			mkdir -p "${LIB_SAVE_LOCATION}${module_path}"

			# Copy all the module __init__ files
			mod_dirs=""
			ary_mod_dirs=($(echo $module_path | sed 's/\//\n/'))
			for MOD_DIR in "${ary_mod_dirs[@]}"
			do
				mod_dirs="${mod_dirs}/${MOD_DIR}"

				src="${LIB_SRC_LOCATION}${lib_dir_path}/${mod_dirs}/__init__.*" # IDK why I have to do this....
				dst="${LIB_SAVE_LOCATION}${mod_dirs}/"
				set -x
				/usr/bin/find $src -exec cp {} $dst \;
				{ set +x; } 2>/dev/null
			done

			module_path="${module_path}/"
		fi

		# Finally cp the lib
		lib_file=$(basename $LIB)
		CP_FLAGS=""
		if [ -d "${LIB_SRC_LOCATION}${LIB}" ]; then
			CP_FLAGS="-r"
		fi
		set -x
		cp $CP_FLAGS "${LIB_SRC_LOCATION}${LIB}" "${LIB_SAVE_LOCATION}${module_path}${lib_file}"
		{ set +x; } 2>/dev/null
	done
fi

# Copy the supporting python files to the microcontroller
# TODO JMT Depending on how I want to organize the dev dir, I might want to create another file
# 	that lists the additional python files from dev src that I'd want to copy over.
# 	For now, I'll just cp all python files in the same dir as the main py file
if [ "$LOAD_ACCESSORIES" -eq 1 ]; then
	echo "Copying the supporting files"
	ARY_SUPPORT_FILES=($(find $(dirname $SAVE_FILE) -name '*.py'))
	for PY in "${ARY_SUPPORT_FILES[@]}"
	do
		if [ "$PY" != $SAVE_FILE ]; then
			copy_py $PY $MOUNT_LOCATION
		fi
	done
fi

# Finally, copy the main py file to the microcontroller
echo "Copying main py"
copy_py $SAVE_FILE $SAVE_LOCATION
set -x
sync
{ set +x; } 2>/dev/null

echo "Successfully loaded program to microcontroller"

