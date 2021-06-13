# dhcpDialog
Bash script for managing (IPv4) ISC dhcp server scopes with Dialog as an interface.

**What's needed?**

Tested on latest versions of: Coreutils, Bash, Dialog.

ISCs dhcp server is necessarily not needed as this script only creates a file that the dhcp server can use. This script does not touch the dhcp server configuration file.

**Manual intervention:**

There's a function called serviceRestart starting at line 22 that generates a config file. Due to user permissions the dhcpd service cannot access the contents of the configuration file, so I have inserted an example command that copies the configuration file to /etc/dhcpDialog.conf. You can either use it or use a different file path/command. There is also an example command that restarts the dhcpd systemd service, you should also change that according to your distro.

If not using default folder path: Make the folders where you want to make them, and then set the paths in the script (remember to remove $actualPath from the folder variables). Folder variables must not end with a /.

If using default: The script uses "dhcpScopes" folder for scope options and "exclusions" as the folder for excluded IPs. The conf file is generated in the folder the script has been put in. You can change the path/name of the conf file in the script. 

Create a user with a home folder, then download and move dhcpDialog to the users home folder. This is recommended due to using rm when deleting scopes. I do not trust my own abilities with coding to trust deleting files.

Add to .bashrc to execute the script, so anyone who logs in is greeted with the interface, instead of needing to run the script manually.

Add 'include "/path/to/conf/file";' at the end of the dhcpd configuration file (or in the middle).



**Why would anyone need/use this?**

Some teams are scared to use the terminal, so I made this script to make it easier to manage DHCP scopes. So instead of using commands like nano /etc/dhcpd.conf (Nano should already be easy to use), you get to use the dialog interface. This is a good way to introduce Linux to others.


**Upcoming changes**

IP scope range usage, view leases specific to networks. I need to wrap my head around filtering IP subnets and networks, so give it some time.

I have been trying to implement a range usage menu, but I'm not so good at the math to do it. I have to think about it for a longer time. I also got a job, so I'm not putting as much focus on this project.

I will also create a version that can manage multiple servers, I'm thinking of doing it with SSH using SSH keys. If anyone looking at this can give me some other ideas than SSH, then feel free.
