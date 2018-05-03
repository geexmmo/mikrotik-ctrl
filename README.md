# mikrotik-ctrl
![avg mikrotik user](https://user-images.githubusercontent.com/606292/39509018-7efb9818-4e06-11e8-9b6e-92308a20c05b.png)

# Requirements
* fairly modern bash
* ftp enabled on devices (one time requirement to deploy keys, later on only ssh will be used)
* ssh-server enabled
* modern RouterOS/SwitchOS

# Basic usage
###### Executing script
Set executable bit on **mikrotik-crtl.sh** with `chmod +x mikrotik-crtl.sh` and run it with `sh mikrotik-crtl.sh` or `./mikrotik-crtl.sh` </br>
Script will ask you for login credentials and IP address of device you wish to manage and deploy RSA keys</br>

You can specify IP address or populate ip.txt file with ip addresses that will be used</br>

On devices - sepatate user will be created, this user will be named as login you specified while running script with addition of `_ssh` to user name</br>

Later you can use ssh passwordless login using your ~/.ssh/id_rsa key with this user name. ex: `admin`**_ssh**`@10.10.10.10`

###### payload.txt file
**payload.txt** contains list of commands that will be executed on selected host or group of hosts from **ip.txt**

###### ip.txt file
You can populate **ip.txt** file in directory where script is placed with IP addresses of devices that will receive keys and commands to execute from **payload.txt** file.

###### autologin-enabled-devices.txt file
This file contains IP's of devices that scritps had previously deployed keys to, this devices is ignored wher key-check phase is run</br>

# Examples
**Simple SNMP configuration provisioning**
>File ip.txt is populated with:
```
10.1.2.100
10.1.2.101
10.1.2.102
10.1.2.103
```

>File payload.txt contains:
```
/snmp community set [ find default=yes ] addresses=10.1.2.2/32
/snmp set contact=geexmmo enabled=yes location=branch-server-room trap-version=2
```
Result:
Mikrotik devices will now accept SNMP collector from my Zabbix instance on 10.1.2.2