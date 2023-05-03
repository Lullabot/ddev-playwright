#!/usr/bin/env bash
#ddev-generated

START_XVFB=true
SE_START_NO_VNC=true
NO_VNC_PORT=7900
VNC_PORT=5900
#
# IMPORTANT: Change this file only in directory NodeBase!

if [ "${START_XVFB:-$SE_START_XVFB}" = true ] ; then
  if [ "${START_NO_VNC:-$SE_START_NO_VNC}" = true ] ; then
    /opt/bin/noVNC/utils/novnc_proxy --listen ${NO_VNC_PORT:-$SE_NO_VNC_PORT} --vnc localhost:${VNC_PORT:-$SE_VNC_PORT}
  else
    echo "noVNC won't start because SE_START_NO_VNC is false."
  fi
else
  echo "noVNC won't start because Xvfb is configured to not start."
fi
