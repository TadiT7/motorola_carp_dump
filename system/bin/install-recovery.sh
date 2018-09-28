#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/platform/msm_sdcc.1/by-name/recovery:10397696:1e0d00e378ea63c4950abd453959b6bfaeb75be9; then
  applypatch -b /system/etc/recovery-resource.dat EMMC:/dev/block/platform/msm_sdcc.1/by-name/boot:9441280:0dc422eeb812c01d4ee6bd4d3dc620c188dedf25 EMMC:/dev/block/platform/msm_sdcc.1/by-name/recovery 1e0d00e378ea63c4950abd453959b6bfaeb75be9 10397696 0dc422eeb812c01d4ee6bd4d3dc620c188dedf25:/system/recovery-from-boot.p && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi
