#!/bin/bash

# ... (pkill commands and setup remain the same) ...

# Clean up previous sessions
pkill -9 xfce4; pkill -9 xfwm4; pkill -9 Xvfb; pkill -9 Xvnc; pkill -9 x11vnc; pkill -9 websockify; pkill -9 dbus-launch; pkill -9 dbus-daemon
sudo rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1
sudo fuser -k 5900/tcp 5901/tcp 6080/tcp
mkdir -p /tmp/runtime-codespace
chmod 700 /tmp/runtime-codespace

export XDG_RUNTIME_DIR=/tmp/runtime-codespace
export DISPLAY=:1

# Start Xvnc in the background
Xvnc :1 -geometry 1280x720 -depth 24 -rfbport 5901 -rfbauth ~/.vnc/passwd -localhost no -ac &
VNC_PID=$! # Capture the VNC PID
sleep 3

# Start dbus and XFCE (these usually run as long as the session is active)
eval $(dbus-launch --sh-syntax --exit-with-session)
startxfce4 &
sleep 3

# Start websockify in the background
websockify --web /usr/share/webapps/novnc 6080 localhost:5901 &
WEBSOCK_PID=$! # Capture the websockify PID

echo "VNC server running as PID $VNC_PID, Websockify running as PID $WEBSOCK_PID"

# Wait for either of the main processes to terminate (prevents script from exiting)
wait -n $VNC_PID $WEBSOCK_PID

