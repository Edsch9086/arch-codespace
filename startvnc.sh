#!/bin/bash

# --- 1. Cleanup previous sessions ---
pkill -9 xfce4 xfwm4 Xvfb Xvnc x11vnc websockify dbus-launch dbus-daemon pulseaudio ffmpeg
sudo rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 /tmp/.ICE-unix
sudo fuser -k 5900/tcp 5901/tcp 6080/tcp 8080/tcp

# --- 2. Setup VNC Environment ---
mkdir -p /tmp/runtime-codespace
chmod 700 /tmp/runtime-codespace
export XDG_RUNTIME_DIR=/tmp/runtime-codespace
export DISPLAY=:1

# Use eval to capture D-Bus session variables into current script environment
eval $(dbus-launch --sh-syntax --exit-with-session)

# --- 3. Start VNC and XFCE ---
Xvnc :1 -geometry 1280x720 -depth 24 -rfbport 5901 -rfbauth ~/.vnc/passwd -localhost no -ac &
sleep 3
startxfce4 &
sleep 3
websockify --web /usr/share/webapps/novnc 6080 localhost:5901 &

# --- 4. Setup and Start Audio Streaming ---

# Configure PulseAudio for user session and dummy sink
mkdir -p ~/.config/pulse
# Clear old config first to be safe, then copy fresh
rm -f ~/.config/pulse/default.pa
cp /etc/pulse/default.pa ~/.config/pulse/default.pa

echo "load-module module-dummy-sink" >> ~/.config/pulse/default.pa
# Ensure network access is loaded for localhost access
echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;$(hostname -I | awk '{print $1}')/24" >> ~/.config/pulse/default.pa
sed -i 's/;exit-idle-time = 20/exit-idle-time = -1/' ~/.config/pulse/daemon.conf

# Start the PulseAudio daemon
pulseaudio --start --exit-idle-time=-1 &
sleep 3
pulseaudio --check

# Dynamically find the exact monitor source name for the dummy sink
# We search for the string "auto_null.monitor"
AUDIO_SOURCE=$(pactl list short sources | grep "auto_null.monitor" | awk '{print $2}')
echo "Audio source found: $AUDIO_SOURCE"

# Start ffmpeg as an HTTP server with the CORRECT URL syntax
# This binds to port 8080, which you MUST port forward in Codespaces
ffmpeg -hide_banner -loglevel info -f pulse -i "$AUDIO_SOURCE" -ac 2 -acodec libmp3lame -ab 128k -ar 44100 -f mp3 -listen 1 -re -use_timeline http://0.0.0.0:8080/stream.mp3 &

