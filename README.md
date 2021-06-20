# dhcpDialog
  <a href="./LICENSE"><img src="https://img.shields.io/github/license/Greenlandicsmiley/dhcpDialog?color=Green&style=flat-square"></a>
  <a href="https://github.com/Greenlandicsmiley/dhcpDialog/releases"><img src="https://img.shields.io/github/v/tag/Greenlandicsmiley/dhcpDialog?color=Green&style=flat-square"></a>

Bash script for managing (IPv4) ISC dhcp server scopes with Dialog as an interface.

## Requirements:

Coreutils, Bash, Dialog, ISC dhcp server not necessarily needed.

## Manual intervention:

### serviceRestart: line 22

Insert a copy command to the serviceRestart() function.

Insert a service restart command for the dhcpd service. Edit it according to your distribution.

### Installation (makefile underway)

Default: Make a directory somewhere accessible, then copy/clone the main github repository and start using the script.

Custom: Set the file path variables in the script, remember they should not end with a /. A proper conf file is underway.

Add to .bash_profile to execute the script, so anyone who logs in is greeted with the interface, instead of needing to run the script manually.

Add 'include "/etc/dhcpDialog.conf";' at the end of the dhcpd configuration file (or in the middle).


## Why would anyone need/use this?

Some teams are scared to use the terminal, so I made this script to make it easier to manage DHCP scopes. So instead of using commands like nano /etc/dhcpd.conf (Nano should already be easy to use), you get to use the dialog interface. This is a good way to introduce Linux to others.


## Upcoming changes

IP scope range usage, view leases specific to networks. I need to wrap my head around filtering IP subnets and networks, so give it some time.

I have been trying to implement a range usage menu, but I'm not so good at the math to do it. I have to think about it for a longer time. I also got a job, so I'm not putting as much focus on this project.

I will also create a version that can manage multiple servers, I'm thinking of doing it with SSH using SSH keys. If anyone looking at this can give me some other ideas than SSH, then feel free.
