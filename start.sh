#!/bin/bash
# Script dies on error
set -e

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Script directory information
echo "Script `basename "$0"` and additional files located in `dirname "$0"`"
cd "$(dirname "$0")"

#ExecuteOnHost_output_enabled=true
id_rsa_pub_path=~/.ssh/id_rsa.pub
auto_rsc_file=./key-import.auto.rsc
payload_file=./payload.txt
payload_sysinfo="/system identity print"
id_rsa_pub_basename=$(basename $id_rsa_pub_path)

# Check if id_rsa.pub file exists in standart directory, generate one if not existing
function CheckKeysAvailable {
	if [ ! -e $id_rsa_pub_path ]; then
		echo -e "${YELLOW}No id_rsa.pub file found in ~/.ssh/${NC}"
		read -p "Would you like to generate a new one? (Y/n)" no_id_rsa_pub
			case $no_id_rsa_pub in
			y|Y|Yes) echo "Yes";ssh-keygen -t rsa;;
			n|N|No) echo -e "${RED}No${NC}";exit;;
			*) echo "${YELLOW}Assuming YES${NC}";ssh-keygen -t rsa;;
			esac
	fi
	}

# Get user connection credentials and host information to deploy keys
function GetUserCreds {
	# Get and verify user login to be non-zero string
	while [ -z $login ]; do
		read -rp "Mikrotik login: " login
	done
	read -rp "Password: " -s password
	# Prompt device ip or use ip.txt if no input received 
	read -p "`echo $'\n '`Device IP address or [ENTER] for devices in ip.txt: `echo $'\n> '`" ip
	length=${#ip}
	if test $length = 0
		then echo -e "Using ip.txt to get host addresses\n"
		mapfile ip < ./ip.txt
		else echo "Deployig keys on $ip"
	fi
	CheckSSHKeysInstalled $login $ip
	}

# Add new $user_ssh account and import public keys
function CheckSSHKeysInstalled {
	# Check if IP is already in autologin-enabled-devices.txt file (key deployed)
	mapfile -t autologin_array < autologin-enabled-devices.txt
	# Getting base name for rsa key to include it in Mikrotik import command
	for host in ${ip[@]}
		do
			#echo "Checking $host in IP array"
			for ip_line in ${autologin_array[@]}
    			do
        			if ( test $ip_line = $host )
        				then
							key_was_deployed=true
							break							
        				else
							key_was_deployed=false
        			fi
    		done
			if test "$key_was_deployed" != "true"
				then
					sleep 0.5
					echo -e "${RED}Key not found for: $host, key will be deployed${NC}"
					#echo -e "Can pass login: $login pass: $password host: $host"
					DeploySSHKeys $login $password $host
				else
					echo -e "(autologin-enabled-devices.txt)\n${GREEN}Key found for: $host, executing commands...${NC}"
					ExecuteOnHost $login $host
			fi
		done
	}

function DeploySSHKeys {
	#$1 - login
	#$2 - password
	#$3 - device ip
	# Copying and renaming key on local machine to current directory
	id_rsa_copy_path="./$1_ssh.$id_rsa_pub_basename"
	cp $id_rsa_pub_path $id_rsa_copy_path
	# Generating random password because logins with pubkey just can't log-in with password auth
	randompass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
	# Generating Mikrotik import-key command
	# we sould add another account just for pubkey automated logins
	echo "/user add name=$1_ssh group=full disabled=no password=$randompass comment=\"automated login, created from management script\"" >  $auto_rsc_file
	# '${id_rsa_copy_path#"./"' strips leading './'' from filename
	echo "/user ssh-keys import public-key-file=${id_rsa_copy_path#"./"} user=$1_ssh" >> $auto_rsc_file
	# FTP connection to upload keys and auto.rsc file
ftp -n -i <<-EOF
		open $3
		user $1 $2
		cd /
		put $id_rsa_copy_path
		put $auto_rsc_file
		bye
	EOF
	echo -e "Key installed for ${GREEN}$1_ssh@$3${NC}!"
	echo $host >> autologin-enabled-devices.txt
	ExecuteOnHost $1 $3
}

# Execute commands in payload.txt
function ExecuteOnHost {
	#$1 - login
	#$2 - device ip
	mapfile -t payload_generator < $payload_file
	# Adds '/system identity print' as first payload command
	payload_final=$payload_sysinfo$'\n'
	# Reads payload.txt by one line and appends newline character at end of line
	for payload_line in "${payload_generator[@]}"
    	do
        	payload_final+="$payload_line"$'\n'
    	done
	echo  "Execution output:"
	ssh $1\_ssh@$2 "$payload_final"
	}
CheckKeysAvailable
GetUserCreds
exit
