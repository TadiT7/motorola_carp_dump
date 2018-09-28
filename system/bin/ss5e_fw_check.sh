#!/system/bin/sh
# -------------------------------------------------------------------
# OVERVIEW:
#
# SS5E firmware is located at /system/etc/firmware/gps in format
# of .bin. This script will be invoked by init.smelt.rc and flashes
# the firmware into SS5E. A persistent property SS5E_FW_VER_PROPERTY
# will be updated with the firmware version upon success.
#
# When the board is fresh from factory, firmware will be flashed based on
# an empty SS5E_FW_VER_PROPERTY. It happens at the "Flashing Station"
# in the factory. Before GPS TM8 is executed in "Board Test Station", factory
# receipe will check the persistent property SS5E_FW_VER_PROPERTY to ensure
# firmware is flashed.
#
# In the field, firmware will be flashed at power-up when a new
# version of firmware is stored at /system/etc/firmware/gps by BOTA.
#
# Example of firmware file name:
#     5.7.5-P1.GCC_SG1-DRI-2-A.bin
#
# Firmware is also read from SS5V at each GPS_Start(). It can also be used
# to stored into SS5E_FW_VER_PROPERTY.
#
# Example of firmware version read from SS5E:
#     5xp__5.7.5-P1.GCC_SG1-DRI-2-A+5xpt_5.7.5-P1.KCC
#
# Where:
#
# Product ID: 		5xp_
# SW version: 		(5.7.5) - (major.minor.subminor)
# Build Phase: 		P for production
# Build Number: 	1
# Extra identifier:	GCC_SG1-DRI-2-A+5xpt_5.7.5-P1.KCC
#
# Note:
# Firmware flashing typically takes 20-30 seconds depending on the firmware
# file size. While flashing, SS5E is placed in a boot mode, where all GPS
# requests from HAL will be rejected.
#
# Note:
# The script will check if the HWREV is below certain threashold, if true, an older 
# firmware w/o external LNA will be flashed from /system/etc/firmware/gps/old_hw/. 
#
# BOM to Product Map
# -------------------------
# BOM Rev  Product
# -------------------------
#    [0]  = "Wing"
#    [1]  = "Wing"
#    [2]  = "Wing"
#    [3]  = "Wing"
#    [4]  = "Large"
#    [5]  = "Large"
#    [6]  = "Large"
#    [7]  = "Small"
#    [8]  = "Small"
#    [9]  = "Small"
#    [10] = "Sport Small"
#    [11] = "Sport Small"
#    [12] = "Sport Small"
#    [13] = "Sport Large"
#    [14] = "Sport Large"
#    [15] = "Sport Large"
#
# Refer to: https://docs.google.com/spreadsheets/
#           d/1XE1J2S1v5bKosDIaC0FtyIQKXF-oQEDKib7id-ZDzpw/edit#gid=494070959
# ----------------------------------------------------------------------------

SS5E_FW_VER_PROPERTY=persist.ss5e.firmware_version
SS5E_FW_PROGRESS_PROPERTY=hw.ss5e.update_done
NEW_SS5E_FW_FILE_PATH="/system/etc/firmware/gps"
FLASHING_SPI_BAUD_RATE=4500000  # bps
BOM_SMALL_SPORT=( 10 11 12 )    # refer to BOM to Product Map above
BOM_WING=( 0 1 2 3 )            # refer to BOM to Product Map above

HWREV0=0  # non-sport edition. does not require firmware flashing
HWREV1=1  # initial firmware
HWREV2=2  # firmware configured for external LNA

# global default to non-sport
gps_hwrev=$HWREV0

function power_up_ssv5_in_boot() {

	# Turn on regulator
	echo 1 > /sys/devices/0.ssv_gps/enable_regulator

	echo "Turn on SS5E in boot mode ..."
	echo 1 > /sys/devices/0.ssv_gps/gps_boot_select/value
	echo 0 > /sys/devices/0.ssv_gps/gps_reset/value
	sleep 0.1
	echo 1 > /sys/devices/0.ssv_gps/gps_reset/value
	echo 1 > /sys/devices/0.ssv_gps/gps_on_off/value

	echo "Wait for SS5E to be on ..."
	host_wakeup=0
	timeout=50
	while [ $host_wakeup -ne 1 ] && [ $timeout -gt 0 ]; do
		host_wakeup=`cat /sys/devices/0.ssv_gps/gps_host_wakeup/value`
		((timeout--))
		sleep 0.1
	done

	if [ $timeout -eq 0 ]; then
		setprop $SS5E_FW_PROGRESS_PROPERTY "Timeout on turning on GPS"
		exit 1
	fi
}

function power_down_ssv5() {

	echo "Restore BOOT_SELECT pin and turn off SS5E ..."
	echo 0 > /sys/devices/0.ssv_gps/gps_boot_select/value
	# toggle reset pin so SS5e latches in the new BOOT_SELECT status
	echo 0 > /sys/devices/0.ssv_gps/gps_reset/value
	sleep 0.1
	echo 1 > /sys/devices/0.ssv_gps/gps_reset/value
	echo 0 > /sys/devices/0.ssv_gps/gps_on_off/value

	echo "Wait for SS5E to go off ..."
	host_wakeup=1
	timeout=50
	while [ $host_wakeup -ne 0 ] && [ $timeout -gt 0 ]; do
		host_wakeup=`cat /sys/devices/0.ssv_gps/gps_host_wakeup/value`
		((timeout--))
		sleep 0.1
	done

	# Turn off regulator
	echo 0 > /sys/devices/0.ssv_gps/enable_regulator

	if [ $timeout -eq 0 ]; then
		setprop $SS5E_FW_PROGRESS_PROPERTY "Timeout on turning off GPS"
		exit 2
	fi
}

function flash_fw() {

	power_up_ssv5_in_boot
	sleep 3

	if [ ! -e "/system/bin/gps_prgflash" ]; then
		setprop $SS5E_FW_PROGRESS_PROPERTY "/system/bin/gps_prgflash does not exist"
		exit 3
	fi

	/system/bin/gps_prgflash $1 $FLASHING_SPI_BAUD_RATE 

	# check flashing result
	if [ $? -ne 0 ]; then
		setprop $SS5E_FW_PROGRESS_PROPERTY "gps_prgflash failed"
		exit 4
	fi

	power_down_ssv5

	# update the firmware version here. factory script will
	# check this to ensure firmware is flashed.
	setprop $SS5E_FW_VER_PROPERTY $2
}

function check_hwrev() {

	gps_hwrev=$HWREV0

	hwrev=`getprop ro.boot.hwrev`

	if [ -z $hwrev ]; then
		setprop $SS5E_FW_PROGRESS_PROPERTY "Can't find HW revision"
		exit 5
	fi

	pcb=$((hwrev >> 8))
	bom=$((hwrev & 0xff))

        # only small sport and wing need GPS firmware
	bom_need_flash=("${BOM_SMALL_SPORT[*]}" "${BOM_WING[*]}")

	need_flash=0
	# check if it is small sport or wing
	for i in ${bom_need_flash[*]};
	do
		if [ $i -eq $bom ] ; then
			need_flash=1
			break
		fi
	done

	if [ $need_flash -eq 1 ]; then
        	# set to default hwrev
		gps_hwrev=$HWREV2 

        	# check for hwrev1
		if [ $pcb -lt $((0x09)) ]; then
			gps_hwrev=$HWREV1
		elif [ $pcb -eq $((0x09)) ] && ([ $bom -eq $((0x0A)) ] || [ $bom -eq $((0x0B)) ]); then
			gps_hwrev=$HWREV1
		fi
	else
        	# non sport-small. do not flash firmware.
		setprop $SS5E_FW_PROGRESS_PROPERTY "HW does not require firmware flashing"
		exit 6
	fi

	# it returns result in global $gps_hwrev
}


#################
# Main Exection 
#################

# configure rising edge
echo rising > /sys/devices/0.ssv_gps/gps_irq/edge

if [ -f /data/aplogd/bootindex ]; then

	bootindex=`cat /data/aplogd/bootindex`

	if [ $bootindex -gt 0 ]; then ((bootindex--)) fi

	if [ -f /data/location/core_log.bin ]; then
		mv /data/location/core_log.bin /data/aplogd/core_log_$bootindex.bin
	fi

	if [ -f /data/location/csr_gnss_log.txt ]; then
		mv /data/location/csr_gnss_log.txt /data/aplogd/csr_gnss_log_$bootindex.txt
	fi
fi

# start firmware check and update
setprop $SS5E_FW_PROGRESS_PROPERTY "Start firmware flashing"

# it will populate $gps_hwrev
check_hwrev

if [ $gps_hwrev -eq $HWREV1 ]; then
	NEW_SS5E_FW_FILE_PATH=$NEW_SS5E_FW_FILE_PATH'/hwrev1'
fi

for file in `ls $NEW_SS5E_FW_FILE_PATH | grep '\.bin$'`;
do
done

if [ ! -z $file ]; then

	# remove file extension
	new_fw_ver=${file%*.*}

	if [[ `getprop $SS5E_FW_VER_PROPERTY` = *$new_fw_ver* ]]
	then
		setprop $SS5E_FW_PROGRESS_PROPERTY "Firmware is up to date"
	else
		flash_fw $NEW_SS5E_FW_FILE_PATH/$file $new_fw_ver
		setprop $SS5E_FW_PROGRESS_PROPERTY "New firmware flashed"
	fi
else
	setprop $SS5E_FW_PROGRESS_PROPERTY "Firmware file not found"
	exit 7
fi

