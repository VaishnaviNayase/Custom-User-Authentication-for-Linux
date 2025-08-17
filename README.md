-- all the pam related scripts and configurations are present in the vm image
-- everything has to be run in root user 
run start script
if have to add new user then 
	cp users_base -> target
	add entry to install script with tap and a unique mac address
	run install script
	new client will have an IP of 172.20.0.2 
	ssh into root@172.20.0.2
	vi /etc/network/interfaces(change ip 172.20.0.2 -> 172.20.0.<something_unique>
	run systemctl restart networking
	ssh again with the new ip with ssh root@<new_assigned_ip>
	run ssh-keygen without passphrase or make sure you remember the passphrase otherwise
	run ssh-copy-id postgres@172.20.0.4
	enter the password 1234v
	now the login will work as per the postgres
else
	run install script
fi
## Note 
	if the server is down then login is not possible
