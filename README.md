# dhcpdDialog
Bash script for managing dhcpd with (GNU) Dialog

This isc dhcpd server tool is work in progress.

PREREQUISITES:

Dialog (Tested with v1:1.3_20201126-1 on Arch)

Bash (Tested with v5.1.004-1 on Arch)

A folder for actual scope options (Currently you have to specify which folder it is in the script)

A folder for IP exclusions (You have to specify which folder it is in the script. MUST BE SEPARATE FROM scope options)

A conf file to group together the scope options that the user running the script has access to

Add "include "/path/to/file";" at the end of the dhcpd configuration file

THIS IS NOT FOR COMPLETE dhcpd configuration, ONLY FOR SCOPE/NETWORK OPTIONS.
