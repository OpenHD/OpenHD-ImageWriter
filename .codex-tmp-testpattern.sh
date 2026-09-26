#!/bin/sh
systemctl stop openhd_mod.service
v4l2-ctl -d /dev/v4l-subdev1 --set-ctrl=test_pattern=1
timeout 10 gst-launch-1.0 -q v4l2src device=/dev/video3 io-mode=mmap ! 'video/x-raw,format=NV12,width=1280,height=720,framerate=60/1' ! videoconvert ! video/x-raw,format=RGB16 ! kmssink driver-name=imx-drm force-modesetting=true sync=false
rc=$?
v4l2-ctl -d /dev/v4l-subdev1 --set-ctrl=test_pattern=0
systemctl start openhd_mod.service
echo testpattern_rc=$rc
systemctl is-active openhd_mod.service imx8-isp.service
