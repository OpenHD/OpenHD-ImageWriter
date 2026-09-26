#!/bin/sh
systemctl stop openhd_mod.service
timeout 12 gst-launch-1.0 -e \
  v4l2src device=/dev/video3 io-mode=mmap ! \
  'video/x-raw,format=NV12,width=1280,height=720,framerate=60/1' ! \
  videoconvert ! video/x-raw,format=RGB16 ! \
  kmssink driver-name=imx-drm force-modesetting=true sync=false
rc=$?
systemctl start openhd_mod.service
echo kms_rc=$rc
systemctl is-active openhd_mod.service imx8-isp.service
