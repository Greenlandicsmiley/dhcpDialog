# dhcpDialog
Bash script for managing (IPv4) ISC dhcp server scopes with (GNU?) Dialog as an interface

THIS IS NOT FOR COMPLETE dhcp configuration, ONLY FOR SCOPE/NETWORK OPTIONS.

This isc dhcpd server tool is work in progress.

As of 30-01/2021, I'm working on this script on an Arch Linux machine, so I've tested the latest versions of these: Bash, Dialog, Coreutils

ISCs dhcp server is necessarily not needed as this script only creates a file that the dhcp server can use. This script does not touch the dhcp server configuration file.

Manual intervention:

By default: the script uses "dhcpScopes" folder for scope options and "exclusions" as the folder for excluded IPs. The conf file is generated in the folder the script has been put in. You can change the name of the conf file in the script. If you want to change the path of the scopes and excluded IP folders, then you can change it in the script. They're set at the start of the script, though you must make those folders yourself.

Either of the folder variables MUST NOT end in a forward slash.

Add 'include "/path/to/conf/file";' at the end of the dhcpd configuration file (or in the middle)

Due to using rm when deleting scopes, I recommend that you use a different user that only has access to the tool's folder(s).

Currently working on: Making the script more readable and better
