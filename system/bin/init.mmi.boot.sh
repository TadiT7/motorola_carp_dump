#!/system/bin/sh

# Get the hardware ID
hardware_id=$(getprop ro.boot.hwrev)

#BOM ID	Product
#0	Wingboard
#1	Wingboard
#2	Wingboard
#3	Wingboard
#4	Large
#5	Large
#6	Large
#7	Small
#8	Small
#9	Small
#10	Sport Small
#11	Sport Small
#12	Sport Small
#13	Sport Large
#14	Sport Large
#15	Sport Large

# For Dali Small 267 dpi (with BOM ID 7 8 9 A B C), set the density to 260
if [[ "789ABC" == *${hardware_id:4:1}* ]]; then
        setprop ro.sf.lcd_density 260
else
# Default is Dali Large 233 dpi, and the density is set to 240
	setprop ro.sf.lcd_density 240
fi

# Set barcode to ro.trackid
barcode=$(cat /proc/config/barcode/ascii 2>/dev/null)
if [ ! -z "$barcode" ]; then
    setprop ro.trackid $barcode
fi
unset barcode

# Set up bluetooth mac address file
bt_mac=$(cat /proc/config/bt_mac/ascii 2>/dev/null)
if [ ! -z "$bt_mac" ]; then
    bdaddr="/persist/bt/bdaddr.txt"
    if [ ! -f "$bdaddr" ]; then
        echo "${bt_mac:0:2}:${bt_mac:2:2}:${bt_mac:4:2}:${bt_mac:6:2}:${bt_mac:8:2}:${bt_mac:10:2}" > $bdaddr
        chmod 0644 $bdaddr
    fi
fi
unset bt_mac

# Set md5 of /oem/personalization.json to ro.mot.customize_md5
temp_string=$(md5sum /oem/personalization.json)
tokens=( $temp_string )
customize_md5=$(echo ${tokens[0]})
if [ ! -z "$customize_md5" ]; then
    setprop ro.mot.customize_md5 $customize_md5
fi
unset customize_md5

# Set md5 of /oem/oem.prop to ro.mot.oemprop_md5
temp_string=$(md5sum /oem/oem.prop)
tokens=( $temp_string )
oemprop_md5=$(echo ${tokens[0]})
if [ ! -z "$oemprop_md5" ]; then
    setprop ro.mot.oemprop_md5 $oemprop_md5
fi
unset oemprop_md5
