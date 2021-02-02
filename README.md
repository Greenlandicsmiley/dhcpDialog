# dhcpDialog
Bash script for managing (IPv4) ISC dhcp server scopes with (GNU?) Dialog as an interface.

This isc dhcpd server tool is work in progress.

**What's needed?**

As of 30-01/2021, I'm working on this script on an Arch Linux machine, so I've tested the latest versions of these: Bash, Dialog, Coreutils.

ISCs dhcp server is necessarily not needed as this script only creates a file that the dhcp server can use. This script does not touch the dhcp server configuration file.

**Manual intervention:**

If not using default folder path: Make the folders where you want to make them, and then set the paths in the script (remember to remove $actualPath from the folder variables). Folder variables must not end with a /.

If using default: The script uses "dhcpScopes" folder for scope options and "exclusions" as the folder for excluded IPs. The conf file is generated in the folder the script has been put in. You can change the name of the conf file in the script. 

Create a user with a home folder, then download and move dhcpDialog to the users home folder. This is recommended due to using rm when deleting scopes. I do not trust my own abilities with coding to trust deleting files.

Add to .bashrc to execute the script, so anyone who logs in is greeted with the interface, instead of needing to run the script manually.

Add 'include "/path/to/conf/file";' at the end of the dhcpd configuration file (or in the middle).



**Currently working on**: Making the script more readable and better. Update from the interface on different distros (you can already add that yourself).

**Why would anyone need/use this?**

Some teams are scared to use the terminal, so I made this script to make it easier to manage DHCP scopes. So instead of using commands like nano /etc/dhcpd.conf, you get to use the dialog interface. This is a good way to introduce Linux to others.
