#!/bin/bash

USER_NAME="$PAM_USER"
USER_HOME="/home/$USER_NAME"

echo "session_handle:$USER_NAME" >> /u

if [ ! -d "$USER_HOME" ]; then
    mkdir -p "$USER_HOME"
    cp -r /etc/skel/. "$USER_HOME"
    chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"
    echo "session_handle:Created home dir for $USER_NAME" >> /u
fi
exit 0

