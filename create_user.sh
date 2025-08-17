#!/bin/bash
username="$PAM_USER"
out=$(ssh -q postgres@172.20.0.4 "./pam_check '$username' ")

echo "create_user: $out" >> /u

if echo "$out" | grep -q "true"; then
	echo "create_user: $username" > /u
	if ! id "$username" &>/dev/null; then
    		adduser --disabled-password --gecos "" "$username";
    		passwd -d "$username";
	fi
	exit 0;
fi

