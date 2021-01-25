# dhcpdDialog
Bash script for managing dhcpd scopes with (GNU) Dialog

THIS IS NOT FOR COMPLETE dhcpd configuration, ONLY FOR SCOPE/NETWORK OPTIONS.

This isc dhcpd server tool is work in progress.

DEPENDENCIES (That I know so far):

Dialog (Tested with v1:1.3_20201126-1 on Arch)

Bash (Tested with v5.1.004-1 on Arch)

Manual intervention:

By default: the script uses "dhcpdScopes" for scope options and "exclusions" as the folder for excluded IPs. If using defaults, then place the script in it's own folder (the user chooses where) and make the two folders where the script has been put in. The conf file is generated in the folder the script has been put in. You can change the name of the conf file in the script. If you want to change the path of the scopes and excluded IP folders, then you can change it in the script. They're set at the start of the script.

Either of the folder variables MUST NOT end in a forward slash.

Add "include "/path/to/confFile";" at the end of the dhcpd configuration file (or in the middle)
