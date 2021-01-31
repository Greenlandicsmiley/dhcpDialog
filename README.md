# dhcpDialog
Bash script for managing (IPv4) dhcpd scopes with (GNU?) Dialog

THIS IS NOT FOR COMPLETE dhcp configuration, ONLY FOR SCOPE/NETWORK OPTIONS.

This isc dhcpd server tool is work in progress.

Dependencies (That I know so far):

Dialog (Tested with v1:1.3_20201126-1 on Arch)

Bash (Tested with v5.1.004-1 on Arch)

ISCs dhcp server is necessarily not needed as this script only creates a file that the dhcp server can use. This script does not touch the dhcp server configuration file.

Manual intervention:

By default: the script uses "dhcpdScopes" folder for scope options and "exclusions" as the folder for excluded IPs. The conf file is generated in the folder the script has been put in. You can change the name of the conf file in the script. If you want to change the path of the scopes and excluded IP folders, then you can change it in the script. They're set at the start of the script, though you must make those folders yourself.

Either of the folder variables MUST NOT end in a forward slash.

Add 'include "/path/to/conf/file";' at the end of the dhcpd configuration file (or in the middle)

Due to using rm when deleting scopes, I recommend that you use a different user that only has access to the tool's folder(s).

Currently working on: Editing, deleting, using relative path correctly
