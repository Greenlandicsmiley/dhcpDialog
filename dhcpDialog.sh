#!/bin/bash

dialog --msgbox "This is a script for development, please do not use this" 0 0

#File paths
actualPath=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
scopeFolder="$actualPath/dhcpScopes"
confFile="$actualPath/dhcpDialog.conf"
exclusionsFolder="$actualPath/exclusions"
LICENSE="$actualPath/LICENSE"

#Arrays
hashKeys=("subnet-mask" "routers" "domain-name-servers" "domain-name" "broadcast-address" "static-routes" "ntp-servers" "tftp-server-name" "bootfile-name")

declare -A optionKeytoName
optionKeytoName=(["subnet-mask"]="Subnet_mask" ["routers"]="Router(s)" ["domain-name-servers"]="DNS_server(s)" ["domain-name"]="Domain_name" ["broadcast-address"]="Broadcast_address" ["static-routes"]="Static_route(s)" ["ntp-servers"]="NTP_server(s)" ["tftp-server-name"]="TFTP_server(s)" ["bootfile-name"]="Boot_file_name")

#Functions
ipAddition() {
    rangeStart="$(echo "$IP" | cut -d":" -f2 | cut -d"." -f1-3).$(expr $(echo $rangeStart | cut -d"." -f4) + 1)" #Adds 1 to last octet of IP, if it results in 256, then it is passed down to 3rd octet. 
    if [[ $(echo $rangeStart | cut -d"." -f4 ) -ge 256 ]]; then
        rangeStart="$(echo $rangeStart | cut -d"." -f1-2).$(expr $(echo $rangeStart | cut -d"." -f3) + 1).0"
    fi
    if [[ $(echo $rangeStart | cut -d"." -f3 ) -ge 256 ]]; then
        rangeStart="$(echo $rangeStart | cut -d"." -f1).$(expr $(echo $rangeStart | cut -d"." -f2) + 1).0.$(echo $rangeStart | cut -d"." -f4)"
    fi
    if [[ $(echo $rangeStart | cut -d"." -f2 ) -ge 256 ]]; then
        rangeStart="$(expr $(echo $rangeStart | cut -d"." -f1) + 1).0.$(echo $rangeStart | cut -d"." -f3-4)"
    fi
    if [[ $(echo $rangeStart | cut -d"." -f1 ) -ge 256 ]]; then
        rangeStart="255.$(echo $rangeStart | cut -d"." -f2-4)"
    fi
}

ipSubtraction() {
    rangeEnd="$(echo "$IP" | cut -d":" -f2 | cut -d"." -f1-3).$(expr $(echo $rangeEnd | cut -d"." -f4) - 1)" #Subtracts 1 to last octet of IP, if it results in -1, then it is passed down to 3rd octet
    if [[ $(echo $rangeEnd | cut -d"." -f4) -le -1 ]]; then
        rangeEnd="$(echo $rangeEnd | cut -d"." -f1-2).$(expr $(echo $rangeEnd | cut -d"." -f3) - 1).255"
    fi
    if [[ $(echo $rangeEnd | cut -d"." -f3) -le -1 ]]; then
        rangeEnd="$(echo $rangeEnd | cut -d"." -f1).$(expr $(echo $rangeEnd | cut -d"." -f2) - 1).255.$(echo $rangeEnd | cut -d"." -f4)"
    fi
    if [[ $(echo $rangeEnd | cut -d"." -f2) -le -1 ]]; then
        rangeEnd="$(expr $(echo $rangeEnd | cut -d"." -f1) - 1).255.$(echo $rangeEnd | cut -d"." -f3-4)"
    fi
    if [[ $(echo $rangeEnd | cut -d"." -f1) -le -1 ]]; then
        rangeEnd="0.$(echo $rangeEnd | cut -d"." -f2-4)"
    fi
}

dialogInputbox() {
    exec 3>&1
    optionResult=$(dialog --inputbox "$optionName" 0 0 2>&1 1>&3) #An input box to get user input for the chosen option
    exec 3>&-
    if ! [[ -z $optionResult ]]; then
        if $(grep -q "$optionCode " $currentScope); then #Checks if the option already exists in the scope file
            if [[ $optionMode == "multi" ]]; then #Checks if the option can have multiple values.
                sed -i "/${optionCode} /s_;_, ${optionResult};_" $currentScope #Replaces the existing semicolon with the desired value and adds a semicolon
            elif [[ $optionMode == "quotes" ]]; then
                sed -i "/${optionCode} /s_.*_    option ${optionCode} \"${optionResult}\";_" $currentScope
            else
                sed -i "/${optionCode} /s_.*_    option ${optionCode} ${optionResult};_" $currentScope #Replaces the entire line with the desired value
            fi
        elif [[ $optionMode == "quotes" ]]; then
            sed -i "/}/s_.*_    option ${optionCode} \"${optionResult}\";\n}_" $currentScope
        else
            sed -i "/}/s_.*_    option ${optionCode} ${optionResult};\n}_" $currentScope #Replaces the entire line with the desired option to be added and adds } at the end of the file
        fi
        cat $scopeFolder/s*.n* > $confFile #Generates the configuration file
    fi
}

dialogMainMenu() {
    while [[ $mainMenuResult != "Exit" ]]; do
        exec 3>&1
        mainMenuResult=$(dialog --menu "Options" 0 0 0 \
        1 "Edit scope(s)" \
        2 "Add scope(s)" \
        3 "Delete scope(s)" \
        4 "About" \
        5 "View the entire license" \
        "Exit" "" 2>&1 1>&3)
        exec 3>&-
        case $mainMenuResult in
        1)
            availableScopes=""
            for file in $(dir $scopeFolder); do
                availableScopes+="$file . "
            done
            availableScopes+="Cancel . "
            exec 3>&1
            editChooseScope=$(dialog --menu "Which scope do you want to edit?" 0 0 0 $availableScopes 2>&1 1>&3)
            exec 3>&-
            currentScope="$scopeFolder/$editChooseScope"
            if ! [[ -z $editChooseScope || $editChooseScope == "Cancel" ]]; then
                if ! [[ $editChooseScope == "example" ]]; then
                    subnet=$(echo $editChooseScope | cut -d"." -f1-4 | sed "s_s__g")
                    netmask=$(echo $editChooseScope | cut -d"." -f5-8 | sed "s_n__g")
                    dialogEditMenu
                else
                    menuItems=""
                    for key in ${hashKeys[@]}; do #Iterates through hashKeys and adds menu items using associative/hash arrays according to the keys
                        if ! $(grep -q "$key " $currentScope); then
                            menuItems+="${optionKeytoName[$key]} . "
                        else
                            menuItems+="${optionKeytoName[$key]} $(grep "$key " $currentScope | cut -d" " -f7-20 | sed "s_;__g" | sed "s_ _\__g") "
                        fi
                    done
                    menuItems+="Exclude_an_IP . "
                    menuItems+="Set_scope_range . "
                    menuItems+="Back . "
                    dialog --menu "Example: the menu buttons do nothing" 0 0 0 $menuItems
                fi
            fi
            ;;
        2)
            exec 3>&1
            networkResult=$(dialog --inputbox "Which network do you want to add? Example: 192.168.1.0 255.255.255.0" 0 0 2>&1 1>&3)
            exec 3>&-
            if ! [[ -z $networkResult ]];then #Checks if the input is empty
                subnet=$(echo $networkResult | cut -d" " -f1) #Sets the current subnet to what the user put in
                netmask=$(echo $networkResult | cut -d" " -f2) #Sets the current netmask to what the user put in
                currentScope="$scopeFolder/s$subnet.n$netmask" #Sets the file path for the scope file
                echo -e "subnet $subnet netmask $netmask{\n}" > $currentScope #Places the subnet and netmask info into the file
                dialogEditMenu
            fi
            ;;
        3)
            if ! [[ -z $(dir $scopeFolder) ]]; then
                fileNumber=1 #Sets the file number to 1 to populate the dialog msgbox
                filesOutput=($(dir $scopeFolder)) #Makes an array of files that are in scopeFolder
                scopeFiles=""
                for file in ${filesOutput[*]}; do #Repeatedly adds items to arrays to dynamically create a checklist box
                    scopeFiles+="$file $fileNumber off "
                    let "fileNumber += 1"
                done
                exec 3>&1
                scopeDelete=($(dialog --checklist "Delete scope(s) - Press space to select" 0 0 0 $scopeFiles 2>&1 1>&3))
                exec 3>&-
                if ! [[ -z $scopeDelete ]]; then
                    exec 3>&1
                    scopeDeleteYN=($(dialog --yesno "Are you sure you want to delete these scopes?: ${scopeDelete[*]}" 0 0 2>&1 1>&3))
                    scopeDeleteYN=$?
                    exec 3>&-
                fi
                if [[ $scopeDeleteYN == "0" ]]; then
                    for fileDelete in ${scopeDelete[*]}; do #Deletes all files that are selected in the checklist box
                        rm "$scopeFolder/$fileDelete"
                        rm "$exclusionsFolder/$fileDelete"
                    done
                fi
                cat $scopeFolder/s*.n* > $confFile #Generates the configuration file
            else
                dialog --msgbox "The dhcp scopes folder is empty!" 0 0
            fi
            ;;
        4)
            dialog --msgbox "This script is for use with managing dhcp scopes.\nCopyright (C) 2021  Thomas Petersen/Greenlandicsmiley\n\nThis program is free software: you can redistribute it and/or modify\nit under the terms of the GNU General Public License as published by\nthe free Software Foundation, either version 3 of the License, or\n(at your option) any later version.\n\nThis program is distributed in the hope that it will be useful,\nbut WITHOUT ANY WARRANTY; without even the implied warranty of\nMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\nGNU General Public License for more details.\nYou should have received a copy of the GNU General Public License\nalong with this program.  If not, see <https://www.gnu.org/licenses/>.\n\nContact the author via email: greenlandicsmiley@gmail.com\nor via reddit: www.reddit.com/user/Greenlandicsmiley" 0 0 #Copyright notice and
            ;;
        5)
            dialog --textbox $LICENSE 0 0
            ;;
        esac
    done
}

dialogEditMenu() {
menuResult="." #To avoid soft lock of next line, sometimes it can result in a "back" or "" (empty) which means it wonuldn't run the function
while ! [[ $menuResult == "Back" || $menuResult == "" ]]; do
    menuItems=""
    for key in ${hashKeys[@]}; do #Iterates through hashKeys and adds menu items using associative/hash arrays according to the keys
        if ! $(grep -q "$key " $currentScope); then
            menuItems+="${optionKeytoName[$key]} . "
        else
            menuItems+="${optionKeytoName[$key]} $(grep "$key " $currentScope | cut -d" " -f7-20 | sed "s_;__g" | sed "s_ _\__g") "
        fi
    done
    menuItems+="Exclude_an_IP . "
    if ! $(grep -q "X" "$exclusionsFolder/s$subnet.n$netmask"); then #Reason for just X and not including Z (end of a scope): I am assuming Z is already included with X
        menuItems+="Set_scope_range . "
    else
        menuItems+="Change_scope_range Start:$(grep "X" "$exclusionsFolder/s$subnet.n$netmask" | cut -d":" -f2)_End:$(grep "Z" "$exclusionsFolder/s$subnet.n$netmask" | cut -d":" -f2) "
    fi
    menuItems+="Back . "
    exec 3>&1
    menuResult=$(dialog --menu "Options" 0 0 0 $menuItems 2>&1 1>&3)
    exec 3>&-
    optionMode="" #To avoid some options having unwanted option modes like subnet-mask being a multi option or a quotes option
    case $menuResult in
    "Subnet_mask")
        optionName="Subnet mask"
        optionCode="subnet-mask"
        if ! $(grep -q "subnet-mask" $currentScope); then
            dialogInputbox
        else
            editMenuMode
        fi
        ;;
    "Router(s)")
        optionName="Router(s)"
        optionCode="routers"
        optionMode="multi"
        if ! $(grep -q "routers" $currentScope); then
            dialogInputbox
        else
            editMenuMode
        fi
        ;;
    "DNS_server(s)")
        optionName="DNS servers"
        optionCode="domain-name-servers"
        optionMode="multi"
        if ! $(grep -q "domain-name-servers" $currentScope); then
            dialogInputbox
        else
            editMenuMode
        fi
        ;;
    "Domain_name")
        optionName="Domain name"
        optionCode="domain-name"
        optionMode="quotes"
        if ! $(grep -q "domain-name " $currentScope); then
            dialogInputbox
        else
            editMenuMode
        fi
        ;;
    "Broadcast_address")
        optionName="Broadcast address"
        optionCode="broadcast-address"
        if ! $(grep -q "broadcast-address" $currentScope); then 
            dialogInputbox
        else
            editMenuMode
        fi
        ;;
    "Static_route(s)")
        optionName="Static route(s)"
        optionCode="static-routes"
        optionMode="multi"
        if ! $(grep -q "static-routes" $currentScope); then
            dialogInputbox
        else
            editMenuMode
        fi
        ;;
    "NTP_server(s)")
        optionName="NTP server(s)"
        optionCode="ntp-servers"
        optionMode="multi"
        if ! $(grep -q "ntp-servers" $currentScope); then
            dialogInputbox
        else
            editMenuMode
        fi
        ;;
    "TFTP_server_name")
        optionName="TFTP server"
        optionCode="tftp-server-name"
        optionMode="quotes"
        if ! $(grep -q "tftp-server-name" $currentScope); then
            dialogInputbox
        else
            editMenuMode
        fi
        ;;
    "Bootfile_name")
        optionName="Boot file name"
        optionCode="bootfile-name"
        optionMode="quotes"
        if ! $(grep -q "bootfile-name" $currentScope); then
            dialogInputbox
        else
            editMenuMode
        fi
        ;;
    "Exclude_an_IP")
        exclusionsFile="$exclusionsFolder/s$subnet.n$netmask"
        if $(grep -q "X:" $exclusionsFile) && $(grep -q "Z:" $exclusionsFile); then #Checks if a scope range has been set
            exec 3>&1
            excluding=$(dialog --inputbox "Which IP do you want to exclude?" 0 0 2>&1 1>&3)
            exec 3>&-
            exclusionAdd $excluding #Adds an IP to be excluded in the scopes
        else
            dialog --msgbox "Please set a scope range first" 0 0
        fi
        ;;
    "Set_scope_range"|"Change_scope_range")
        exclusionsFile="$exclusionsFolder/s$subnet.n$netmask" #Sets the file path for the exclusions file
        exec 3>&1
        scopeRange=$(dialog --inputbox "What range do you want? Example: 192.168.1.1 192.168.1.255" 0 0 2>&1 1>&3)
        exec 3>&-
        if ! $( -z $scopeRange); then
            if $(grep -q "X:" $exclusionsFile); then #Checks if the user has already added a scope range
                replaceLine=$(echo $scopeRange | cut -d" " -f1) #Sets the variable to the first IP the user has put in the input box
                sed -i "/X/s|.*|X:${replaceLine}|" $exclusionsFile #Replaces the entire line with the desired scope range start
            else
                echo "X:$(echo $scopeRange | cut -d" " -f1)" >> $exclusionsFile #Puts the first IP the user has put in the input box at the end of the exclusions file
            fi
            if $(grep -q "Z:" $exclusionsFile); then #Same with previous
                replaceLine=$(echo $scopeRange | cut -d" " -f2)
                sed -i "/Z/s_.*_Z:${replaceLine}_" $exclusionsFile
            else
                echo "Z:$(echo $scopeRange | cut -d" " -f2)" >> $exclusionsFile
            fi
            scopeGenerate
        fi
        ;;
    esac
    cat $scopeFolder/s*.n* > $confFile
done
}

editMenuMode() {
    if ! [[ $optionMode == "multi" ]]; then
        optionEditModeMenuItems="1 Edit 2 Delete 3 Cancel"
    else
        optionEditModeMenuItems="1 Edit 2 Add_an_option 3 Delete 4 Cancel"
    fi
    exec 3>&1
    optionEditMode=$(dialog --menu "What do you want to do?" 0 0 0 $optionEditModeMenuItems 2>&1 1>&3)
    exec 3>&-
    if [[ $optionEditMode == "1" ]]; then
        exec 3>&1
        optionEditInput=$(dialog --inputbox "Edit $(echo $optionName | tr '[:upper:]' '[:lower:]')" 0 0 "$(grep "$optionCode " $currentScope | cut -d" " -f7-20 | sed "s_;__g")" 2>&1 1>&3)
        exec 3>&-
        sed -i "/${optionCode} /s_.*_    option ${optionCode} ${optionEditInput};_" $currentScope
    elif [[ $optionEditMode == "2" && $optionMode == "multi" ]]; then
        dialogInputbox
    elif [[ $optionEditMode == "2" ]]; then
        exec 3>&1
        optionEditInput=$(dialog --yesno "Are you sure you want to delete $optionEdit?" 0 0 2>&1 1>&3)
        optionEditInput=$?
        exec 3>&-
        if [[ $optionEditInput -eq "0" ]]; then
            sed -i "/${optionCode} /d" $currentScope
        fi
    fi
}

exclusionAdd() {
    exclusionsFile="$exclusionsFolder/s$subnet.n$netmask" #Sets the file path for the exclusions file
    if $(grep -q $1 $exclusionsFile); then #Checks if the IP is already excluded
        dialog --msgbox "That IP is already excluded!" 0 0
    else
        if [[ $(echo $1 | cut -d"." -f1) -gt 255 || $(echo $1 | cut -d"." -f2) -gt 255 || $(echo $1 | cut -d"." -f3) -gt 255 || $(echo $1 | cut -d"." -f4) -gt 255 ]]; then #Checks if the IP is valid
            dialog --msgbox "$1 is invalid!!" 0 0
        elif [[ $(echo $1 | cut -d"." -f1) -lt 0 || $(echo $1 | cut -d"." -f2) -lt 0 || $(echo $1 | cut -d"." -f3) -lt 0 || $(echo $1 | cut -d"." -f4) -lt 0 ]]; then #Checks if the iP is valid
            dialog --msgbox "$1 is invalid!" 0 0 
        else
            echo "Y:$1" >> $exclusionsFile #Puts excluded IP at the end of the file
            scopeGenerate
        fi
    fi
}

scopeGenerate() { #This function generates scope ranges according to excluded IPs in the exclusions file
    exclusionsFile="$exclusionsFolder/s$subnet.n$netmask" #Sets the file path for the exclusions file
    currentScope="$scopeFolder/s$subnet.n$netmask" #Sets the file path for the scope file
    sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n -o $exclusionsFile $exclusionsFile #Sorts the exclusions file and outputs it to the exclusions file to not confuse the generator
    sed -i "/X/,/Z/!d" $exclusionsFile #Removes IPs that are outside the scope
    sed -i "s_ _\n_g" $exclusionsFile #Replaces spaces with newline
    for IP in $(cat $exclusionsFile); do
        case $IP in
        X:*) #Checks if the current IP being processed is starting range
            sed -i "/range/d" $currentScope
            sed -i "/}/d" $currentScope
            rangeStart=$(echo "$IP" | cut -d":" -f2) #Sets the starting range
            ;;
        Y:*)
            if [[ $rangeStart == $(echo $IP | cut -d":" -f2) ]]; then #Checks if the IP being processed is excluded and adds 1 to not include it in ranges
                ipAddition
            else
                rangeEnd=$(echo "$IP" | cut -d":" -f2) #Sets the ending range and subtracts by one to not include the excluded IP
                ipSubtraction
                echo "    range $rangeStart $rangeEnd;" >> $currentScope #Adds a range to the end of the scope file
                rangeStart=$(echo "$IP" | cut -d":" -f2) #Sets the starting range for the next excluded IP/end of scope and adds it by one
                ipAddition
            fi
            ;;
        Z:*)
            rangeEnd=$(echo "$IP" | cut -d":" -f2) #Sets the ending range
            printf -v ip1 "%03d" $(echo $rangeStart | cut -d"." -f1) #Workaround for bug when setting a scope range like 10.1.0.5 10.1.0.15 where the script thinks 10.1.0.5 is bigger than 10.1.0.15
            printf -v ip2 "%03d" $(echo $rangeStart | cut -d"." -f2)
            printf -v ip3 "%03d" $(echo $rangeStart | cut -d"." -f3)
            printf -v ip4 "%03d" $(echo $rangeStart | cut -d"." -f4)
            rangeStart2="$ip1$ip2$ip3$ip4"
            printf -v ip5 "%03d" $(echo $rangeEnd | cut -d"." -f1)
            printf -v ip6 "%03d" $(echo $rangeEnd | cut -d"." -f2)
            printf -v ip7 "%03d" $(echo $rangeEnd | cut -d"." -f3)
            printf -v ip8 "%03d" $(echo $rangeEnd | cut -d"." -f4)
            rangeEnd2="$ip5$ip6$ip7$ip8" #End of workaround
            if [[ $rangeStart2 < $rangeEnd2 || $rangeStart2 == $rangeEnd2 ]]; then #Checks if the starting less than or equal to the ending range
                echo -e "    range $rangeStart $rangeEnd;\n}" >> $currentScope #Adds the range to the end of the scope file along with a }
            fi
            ;;
        esac
    done
    cat $scopeFolder/s*.n* > $confFile #Generates the configuration file
}

dialogMainMenu
