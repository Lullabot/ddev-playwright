#!/usr/bin/env bash
#ddev-generated
#
# IMPORTANT: Change this file only in directory NodeBase!

set -x

START_XVFB=true
# VNC_NO_PASSWORD=true
DISPLAY=:99.0
VNC_PORT=5900

if [ "${START_XVFB:-$SE_START_XVFB}" = true ] ; then
  # Centering wallpaper
#  for i in $(seq 1 10)
#  do
#    sleep 0.5
#    echo "Centering wallpaper"
#    /usr/bin/fbsetbg -c /usr/share/images/fluxbox/ubuntu-light.png
#    if [ $? -eq 0 ]; then
#      break
#    fi
#  done

  VNC_NO_PASSWORD=${VNC_NO_PASSWORD:-$SE_VNC_NO_PASSWORD}
  if [ ! -z $VNC_NO_PASSWORD ]; then
      echo "Starting VNC server without password authentication"
      X11VNC_OPTS=
  else
      X11VNC_OPTS=-usepw
  fi

  VNC_VIEW_ONLY=${VNC_VIEW_ONLY:-$SE_VNC_VIEW_ONLY}
  if [ ! -z $VNC_VIEW_ONLY ]; then
      echo "Starting VNC server with viewonly option"
      X11VNC_OPTS="${X11VNC_OPTS} -viewonly"
  fi

  for i in $(seq 1 10)
  do
    sleep 1
    xdpyinfo -display ${DISPLAY} >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      break
    fi
    echo "Waiting for Xvfb..."
  done

  x11vnc ${X11VNC_OPTS} -forever -shared -rfbport ${VNC_PORT:-$SE_VNC_PORT} -rfbportv6 ${VNC_PORT:-$SE_VNC_PORT} -display ${DISPLAY}
else
  echo "Vnc won't start because Xvfb is configured to not start."
fi
