#!/bin/bash

username="$PAM_USER"
read password

echo "custom_auth:$username:$password" > /u

out=$(ssh -q postgres@172.20.0.4 "./pam_login '$username' '$password'")

echo "custom_auth: $out" >> /u

if echo "$out" | grep -q "true"; then
	exit 0;
else
	exit 1
fi



