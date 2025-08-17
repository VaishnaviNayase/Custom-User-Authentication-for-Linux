auth       optional   pam_faildelay.so  delay=3000000
auth       required   pam_env.so readenv=1
auth       required pam_exec.so /usr/local/bin/create_user.sh
auth       required pam_unix.so nullok
auth       sufficient pam_exec.so expose_authtok /usr/local/bin/custom_auth.sh
auth       include    system-auth

session    sufficient pam_exec.so /usr/local/bin/session_handle.sh

