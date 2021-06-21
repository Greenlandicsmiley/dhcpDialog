# DEVELOPMENT ONLY
<a href="./LICENSE"><img src="https://img.shields.io/github/license/Greenlandicsmiley/dhcpDialog?color=Green&style=flat-square"></a>
<a href="https://github.com/Greenlandicsmiley/dhcpDialog/releases"><img src="https://img.shields.io/github/v/tag/Greenlandicsmiley/dhcpDialog?color=Green&label=version&style=flat-square"></a>
<img src="https://img.shields.io/github/languages/top/Greenlandicsmiley/dhcpDialog?color=Green&style=flat-square">
<img src="https://img.shields.io/github/last-commit/Greenlandicsmiley/dhcpDialog/main?color=Green&style=flat-square"> 

An interactive isc dhcp server scope management utility written in Bash using Dialog as an interface.

## Requirements:

Coreutils, Bash, Dialog, ISC dhcp server not necessarily needed.

Bash version requirement currently unknown.

## Installation

Download the latest release
- https://github.com/Greenlandicsmiley/dhcpDialog/releases/latest

To install the script
- Make configure executable
- Run `./configure`
- Run `make install` inside the script directory to install the script.

**NOTE:** You may have to run `make install` as root.

## Why would anyone need/use this?

Some teams are scared to use the terminal, so I made this script to make it easier to manage DHCP scopes. So instead of using commands like nano /etc/dhcpd.conf (Nano should already be easy to use), you get to use the dialog interface. This is a good way to introduce Linux to others.


## Upcoming changes

IP scope range usage, view leases specific to networks. I need to wrap my head around filtering IP subnets and networks, so give it some time.

I have been trying to implement a range usage menu, but I'm not so good at the math to do it. I have to think about it for a longer time. I also got a job, so I'm not putting as much focus on this project.

I will also create a version that can manage multiple servers, I'm thinking of doing it with SSH using SSH keys. If anyone looking at this can give me some other ideas than SSH, then feel free.
