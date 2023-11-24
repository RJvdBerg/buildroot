#!/bin/bash

#Vars
HIDE_CTRL_C="Y"
TOOL_VERSION="0.2a"
FLASHOS_ROOT_BLOCKDEVICE=""
FLASHOS_WIN_BLOCKDEVICE=""
FLASHOS_FLASH_TARGET=""
FLASHOS_FLASH_IMAGE=""
FLASHOS_FLASH_WIPE=""

#functions
function addLines() {
#Add lines to output.
echo "----------------------------------------------------------------------------------------------------------"
}


function ctrlcTrap(){
echo "--- CTRL-C abort invoked. Shutting down system... ---"
exitClean
}

function stopScriptFailPoweroff(){
echo
echo
echo "ERR: flashOS-flashtool has encountered an error. Press CTRL-C to shutdown the system."
echo
echo
addLines
while true
do
sleep 5
done
}

function exitClean(){
echo
echo
echo "-- Thank you for using flashOS. --"
echo
addLines
sleep 2
poweroff -d 1
while true
do
sleep 5
done
}

#Check if programs are available on system for use by script.
function doProgramCheck(){
echo "INFO: Checking system utility availability..."

if ! [ -x "$(command -v dd)" ];
then
  echo "ERR: 'dd' is not installed." >&2
  stopScriptFailPoweroff
else
echo "INFO: 'dd' util found."
fi

if ! [ -x "$(command -v mount)" ];
then
  echo "ERR: 'mount' is not installed." >&2
  stopScriptFailPoweroff
else
echo "INFO: 'mount' util found."
fi

if ! [ -x "$(command -v stty)" ];
then
  echo "ERR: 'stty' is not installed." >&2
  stopScriptFailPoweroff
else
echo "INFO: 'stty' util found."
fi


if ! [ -x "$(command -v lsblk)" ];
then
  echo "ERR: 'lsblk' is not installed." >&2
  stopScriptFailPoweroff
else
echo "INFO: 'lsblk' util found."
fi

if ! [ -x "$(command -v head)" ];
then
  echo "ERR: 'head' is not installed." >&2
  stopScriptFailPoweroff
else
echo "INFO: 'head' util found."
fi

}

function checkAssets(){
echo "INFO: Checking flashOS-flashtool assets..."
if [[ $FLASHOS_FLASH_TARGET == "" ]];
then
	echo 'ERR: flashOS-flashtool flash target is not set in config.txt! Example: FLASHOS_FLASH_TARGET="nvme0n1"'
	stopScriptFailPoweroff
else
	if [[ "$FLASHOS_FLASH_TARGET" == *"/dev/" ]];
	then
		PREFIX_REMOVE="\/dev\/"
		FLASHOS_FLASH_TARGET_STRIPPED=${FLASHOS_FLASH_TARGET/#$PREFIX_REMOVE}
		echo "WARN: flashOS-flashtool FLASHOS_FLASH_TARGET is: $FLASHOS_FLASH_TARGET, should only contain this: $FLASHOS_FLASH_TARGET_STRIPPED"
		FLASHOS_FLASH_TARGET=$FLASHOS_FLASH_TARGET_STRIPPED
	fi

	if [[ -e "/dev/$FLASHOS_FLASH_TARGET" ]]; then
		echo "INFO: flashOS-flashtool flashing target: /dev/$FLASHOS_FLASH_TARGET, has been found on the system."
	else
		echo "ERR: flashOS-flashtool flashing target: /dev/$FLASHOS_FLASH_TARGET has not been found on the system."
		stopScriptFailPoweroff
	fi
fi

if [[ $FLASHOS_FLASH_IMAGE == "" ]];
then
        echo 'ERR: flashOS-flashtool image source is not set in config.txt! Example: FLASHOS_FLASH_IMAGE="disk.img"'
        stopScriptFailPoweroff
else
        if [[ -f "/media/flashOS/$FLASHOS_FLASH_IMAGE" ]]; then
                echo "INFO: flashOS-flashtool image source: $FLASHOS_FLASH_IMAGE, has been found on the Windows partition."
        else
                echo "ERR: flashOS-flashtool image source is missing, please make sure that the image is present on the Windows partition, and that the filename is correct. (case-sensitive)"
                stopScriptFailPoweroff
	fi
fi

if [[ $FLASHOS_FLASH_WIPE == "" ]];
then
	echo "INFO: Target disk wipe operation not supported yet, will only be available in later versions of flashOS-flashtool."
else
	echo "INFO: Target disk wipe operation not supported yet, will only be available in later versions of flashOS-flashtool."
fi

}


function loadAssets(){
if [[ -e "/media/flashOS/config.txt" ]];
then
	echo "INFO: Found flashOS-flashtool config, loading configuration..."
	source /media/flashOS/config.txt
	checkAssets
else
	echo "ERR: Could not find the config.txt file on the Windows partition of flashOS."
	echo "ERR: Please verify that you have the config.txt file present, otherwise, please contact support."
	stopScriptFailPoweroff
fi
}


function checkWinPartition(){
if [[ -e "/media/flashOS/" ]];
then
	echo "INFO: flashOS-flashtool assets folder found, checking if the Windows partition of flashOS has been mounted..."
	VAR_CHECK_MOUNT=$(mount -t vfat | head -n 1 | awk '{print $1}')
	if [[ "$VAR_CHECK_MOUNT" == "" ]];
	then
		echo "WARN: Unable to find the Windows partition mounted, trying to mount manually..."
		mount -t vfat /dev/$FLASHOS_WIN_BLOCKDEVICE /media/flashOS/
		if [[ $? -eq 0 ]]; then
			echo "INFO: Windows partition is mounted, checking..."
			checkWinPartition
		else
			echo "ERR: Unable to mount the Windows partition manually."
			stopScriptFailPoweroff
		fi
	else
		#Verify if the right partition has been mounted...
		if [[ "$VAR_CHECK_MOUNT" == "/dev/$FLASHOS_WIN_BLOCKDEVICE" ]];
		then
			echo "INFO: Windows partition is mounted, and correct assigned one as flashOS expected."
			loadAssets
		else
			echo "ERR: The mounted Windows partition is not the same one as flashOS expected. Please report this error to support."
			stopScriptFailPoweroff
		fi
	fi
else
	echo "INFO: flashOS-flashtool assets folder not found, creating mountpoint and mounting Windows partition..."
	mkdir -p /media/flashOS

	#TODO, has to change dynamically, depending on the Buildroot system!
	mount -t vfat /dev/$FLASHOS_WIN_BLOCKDEVICE /media/flashOS/
	if [[ $? -eq 0 ]];
	then
		echo "INFO: Seems like the Windows partition has been mounted, checking..."
	else
		echo "ERR: Unable to mount the Windows partition of flashOS, please contact support if this occurs again..."
		stopScriptFailPoweroff
	fi
	checkWinPartition
fi
}


function getflashOSRootBlockDevice(){

FLASHOS_ROOT_BLOCKDEVICE=$(lsblk -oMOUNTPOINT,PKNAME -rn | awk '$1 ~ /^\/$/ { print $2 }')
if [[ "$FLASHOS_ROOT_BLOCKDEVICE" == "" ]];
then
	echo "ERR: Could not find flashOS root blockdevice name."
	stopScriptFailPoweroff
else
	echo "INFO: Found flashOS root blockdevice name: /dev/$FLASHOS_ROOT_BLOCKDEVICE"
fi
}

function getFlashOSWinBlockDevice(){
FLASHOS_WIN_GET=$(lsblk -o NAME,FSTYPE,PARTLABEL -rn)
while IFS= read -r line;
do
	WIN_DISK_TYPE_GET=$(echo $line | awk '{print $2}')
	if [[ "$WIN_DISK_TYPE_GET" == "vfat" ]];
	then
		WIN_DISK_LABEL_GET=$(echo $line | awk '{print $3}')
		if [[ "$WIN_DISK_LABEL_GET" == "foswinpart" ]];
		then
			FLASHOS_WIN_BLOCKDEVICE=`echo $line | awk '{print $1}'`
		fi
	fi
done <<< "$FLASHOS_WIN_GET"

if [[ "$FLASHOS_WIN_BLOCKDEVICE" == "" ]];
then
echo "ERR: Could not find flashOS windows partition blockdevice name."
stopScriptFailPoweroff
else
echo "INFO: Found flashOS windows partition blockdevice name: /dev/$FLASHOS_WIN_BLOCKDEVICE"
fi
}

function flashImage(){
#Start flashing procedure
echo "INFO: Starting flashing procedure..."
echo "DEBUG: dd if=/media/flashOS/$FLASHOS_FLASH_IMAGE of=/dev/$FLASHOS_FLASH_TARGET bs=32M status=progress"
dd if=/media/flashOS/$FLASHOS_FLASH_IMAGE of=/dev/$FLASHOS_FLASH_TARGET bs=32M status=progress
if [[ $? -eq 0 ]]; then
echo "INFO: Flashing seems successful."
else
echo "ERR: Flashing failed, please report the dd program output to support. Press Ctrl-C to shut down the system."
while true
do
sleep 5
done
fi
}

function checkTargetSource(){
echo "INFO: Checking target device..."
TARGET_DISK_SIZE=$(lsblk -bno SIZE /dev/$FLASHOS_FLASH_TARGET | head -1)
SOURCE_IMAGE_SIZE=$(ls -nl /media/flashOS/$FLASHOS_FLASH_IMAGE | awk '{print $5}')

sleep 0.5
if [[ "$SOURCE_IMAGE_SIZE" -gt "$TARGET_DISK_SIZE" ]];
then
	echo "ERR: The target disk is smaller than the source image. Please ensure that the image is smaller in size, or get a bigger target disk."
	stopScriptFailPoweroff
fi


if [[ "$FLASHOS_FLASH_TARGET" == *"$FLASHOS_ROOT_BLOCKDEVICE" ]];
then
	echo "ERR: flashOS-flashtool cannot flash the image onto flashOS's own disk drive."
	stopScriptFailPoweroff
else
	sleep 0.5
	echo "INFO: The flashing process will now start in 10 seconds... Procedure can now be aborted using CTRL-C."
	sleep 10
	flashImage
fi
}


#Part where script initialise the variables, and do some sanity checks....
function prepare_system(){
echo "INFO: Preparing system..."
doProgramCheck
sleep 0.5

if [[ "$HIDE_CTRL_C" == "Y" ]];
then
	stty -echoctl
fi

#get the root block device from which flashOS is running from:
getflashOSRootBlockDevice

#get the windows partition of flashOS blockdevice
getFlashOSWinBlockDevice

sleep 0.5
#Check windows partition, load and checks the assets.
checkWinPartition

sleep 0.5
#do quick sanity checks for clashes, and start flashing if all checks passed.
checkTargetSource

}

function welcome(){
addLines
echo "Welcome to flashOS (fOS) flashing utility!"
echo "WARNING: This version is in very early stages, so everything is not accounted for. You have been warned."
echo "fOS-flashtool version: $TOOL_VERSION"
addLines
}


#Clear the screen
clear
echo "Starting the script in 5..."
sleep 5
clear
#script execution.
trap ctrlcTrap SIGINT
welcome
sleep 0.5
prepare_system
sleep 0.5
exitClean
