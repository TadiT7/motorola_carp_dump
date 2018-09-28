#!/system/bin/sh
persist_usb_config=`getprop persist.sys.usb.config`
persist_mmi_config=`getprop persist.mmi.usb.config`
bootmode=`getprop ro.bootmode`

echo "mmi-usb-sh: persist.mmi.usb.config=\"$persist_mmi_config\" persist.sys.usb.config=\"$persist_usb_config\" bootmode=\"$bootmode\""

if [ "$bootmode" == "bp-tools" ]; then
    if [ "$persist_usb_config" != "diag,adb" ]; then
        setprop persist.mmi.usb.config $persist_usb_config
    fi
    setprop persist.sys.usb.config "diag,adb"
else
    if [ "$persist_mmi_config" != "" ]; then
        setprop persist.sys.usb.config $persist_mmi_config
        setprop persist.mmi.usb.config ""
    fi
fi
