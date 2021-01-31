#!/bin/bash

actualPath=$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd -P)
scopeFolder="$actualPath/dhcpdScopes"
confFile="$actualPath/dhcpDialog.conf"
exclusionsFolder="$actualPath/exclusions"
LICENSE="$actualPath/LICENSE"

#Functions
debug() { #For checking if script passes a certain line/function
    dialog --msgbox "$1" 0 0 
}

ipAddition () {
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

ipSubtraction () {
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

dialogInputbox () {
    exec 3>&1
    optionResult=$(dialog --inputbox "$optionName" 0 0 2>&1 1>&3) #An input box to get user input for the chosen option
    exec 3>&-
    if ! [[ -z $optionResult ]]; then
        case $optionMode in
        single) #Checks if the option is supposed to be single value
            if $(grep -q "$optionCode " $currentScope); then #Checks if the option already exists in the scope file
                optionLine=$(grep -n "$optionCode " $currentScope | cut -d":" -f1) #Gets the line number for the option
                sed -i "${optionLine}s|.*|    option ${optionCode} ${optionResult};|" $currentScope #Replaces the entire line with the desired value
            else
                curvedLineNumber=$(grep -n "}" $currentScope | cut -d":" -f1) #Gets the line number of }
                sed -i "${curvedLineNumber}s|.*|    option ${optionCode} ${optionResult};\n}|" $currentScope #Replaces the entire line with the desired option to be added and adds } at the end of the file
            fi
            ;;
        multi) #Checks if the option is supposed to have multiple values
            if $(grep -q "$optionCode " $currentScope); then #Checks if the option already exists
                optionLine=$(grep -n "$optionCode " $currentScope | cut -d":" -f1) #Gets the line number of the desired option to be added on
                sed -i "${optionLine}s|;|, ${optionResult};|" $currentScope #Replaces the existing semicolon with the desired value
            else
                curvedLineNumber=$(grep -n "}" $currentScope | cut -d":" -f1) #Gets the line number of }
                sed -i "${curvedLineNumber}s|.*|    option ${optionCode} ${optionResult};\n}|" $currentScope #Replaces the entire line with the desired option to be added and places a } at the end of the file
            fi
            ;;
        quotes) #Checks if the option is supposed to be in quotes
            if $(grep -q "$optionCode " $currentScope); then #Checks if the option already exists
                optionLine=$(grep -n "$optionCode " $currentScope | cut -d":" -f1) #Gets the line number of the option
                sed -i "${optionLine}s|.*|    option ${optionCode} \"${optionResult}\";|" $currentScope #Replaces the entire line with the desired value: Reason for replacing the entire line: Most options where quotes are needed are usually single value. Will add support for multiple values if requested. You can also add it youself ;) it's open source anyway
            else
                curvedLineNumber=$(grep -n "}" $currentScope | cut -d":" -f1) #Gets the line number of }
                sed -i "${curvedLineNumber}s|.*|    option ${optionCode} \"${optionResult}\";\n}|" $currentScope #Replaces the entire line with the desired option to be added and places a } at the end of the file
            fi
            ;;
        esac
        cat $scopeFolder/s*.n* > $confFile
    fi
}

dialogMainMenu () {
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
        exec 3>&1
        editChooseScope=$(dialog --menu "Which scope do you want to edit?" 0 0 0 $availableScopes 2>&1 1>&3)
        exec 3>&-
        currentScope="$scopeFolder/$editChooseScope"
        subnet=$(echo $editChooseScope | cut -d"." -f1-4 | sed "s_s__g")
        netmask=$(echo $editChooseScope | cut -d"." -f5-8 | sed "s_n__g")
        optionEdit="" #To avoid softlocking the editing menu
        while ! [[ $optionEdit == "Back" ]]; do
            optionEditList="" #The list gets generated every time to keep the menu updated
            for option in $(cat $currentScope | grep option | cut -d" " -f6); do
                case $option in
                    subnet-mask)
                        editName="Subnet_mask"
                        ;;
                    routers)
                        editName="Router(s)"
                        ;;
                    time-servers)
                        editName="Time_server(s)"
                        ;;
                    domain-name-servers)
                        editName="DNS_server(s)"
                        ;;
                    domain-name)
                        editName="Domain_name"
                        ;;
                    broadcast-address)
                        editName="Broadcast_address"
                        ;;
                    static-routes)
                        editName="Static_route(s)"
                        ;;
                    ntp-servers)
                        editName="NTP_server(s)"
                        ;;
                    tftp-server-name)
                        editName="TFTP_server(s)"
                        ;;
                    bootfile-name)
                        editName="Boot_file_name"
                        ;;
                esac
                editValue=$(grep "$option " $currentScope | cut -d" " -f7-20 | sed "s_ __g")
                optionEditList+="$editName $editValue "
            done
            optionEditList+="Add_an_option 1 "
            optionEditList+="Back 1"
            exec 3>&1
            optionEdit=$(dialog --menu "Options" 0 0 0 $optionEditList 2>&1 1>&3)
            exec 3>&-
            case $optionEdit in
                    "Subnet_mask")
                        optionEdit="subnet-mask"
                        ;;
                    "Router(s)")
                        optionEdit="routers"
                        ;;
                    "Time_server(s)")
                        optionEdit="time-servers"
                        ;;
                    "DNS_server(s)")
                        optionEdit="domain-name-servers"
                        ;;
                    "Domain_name")
                        optionEdit="domain-name"
                        ;;
                    "Broadcast_address")
                        optionEdit="broadcast-address"
                        ;;
                    "Static_route(s)")
                        optionEdit="static-routes"
                        ;;
                    "NTP_server(s)")
                        optionEdit="ntp-servers"
                        ;;
                    "TFTP_server(s)")
                        optionEdit="tftp-server-name"
                        ;;
                    "Boot_file_name")
                        optionEdit="bootfile-name"
                        ;;
                esac
            if ! [[ $optionEdit == "Back" || $optionEdit == "Add_an_option" ]]; then
                exec 3>&1
                optionEditMode=$(dialog --menu "What do you want to do?" 0 0 0 "1" "Edit" "2" "Delete" "3" "Cancel" 2>&1 1>&3)
                exec 3>&-
                case $optionEditMode in
                    1)
                        inputInit=$(grep $optionEdit $currentScope | cut -d" " -f7-20 | tr -d ";")
                        exec 3>&1
                        optionEditInput=$(dialog --inputbox $optionEdit 0 0 $inputInit 2>&1 1>&3)
                        exec 3>&-
                        optionEditLine="$(grep -n $optionEdit $currentScope | cut -d":" -f1)"
                        sed -i "${optionEditLine}s|.*|    option ${optionEdit} ${optionEditInput};|" $currentScope
                        ;;
                    2)
                        exec 3>&1
                        optionEditInput=$(dialog --yesno "Are you sure you want to delete $optionEdit?" 0 0 2>&1 1>&3)
                        optionEditInput=$?
                        exec 3>&-
                        case $optionEditInput in
                            0)
                                cat $currentScope | grep -v "$optionEdit " > "$currentScope.temp"
                                mv "$currentScope.temp" $currentScope
                                ;;
                            1)
                                ;;
                        esac
                        ;;
                esac
            elif [[ $optionEdit == "Add_an_option" ]]; then
                dialogAddMenu
            fi
        done
        ;;
    2)
        exec 3>&1
        networkResult=$(dialog --inputbox "Which network do you want to add? Example: 192.168.1.0 255.255.255.0" 0 0 2>&1 1>&3)
        exec 3>&-
        if ! [[ -z $networkResult ]];then #Checks if the input is empty
            subnet=$(echo $networkResult | cut -d" " -f1) #Sets the current subnet to what the user put in
            netmask=$(echo $networkResult | cut -d" " -f2) #Sets the current netmask to what the user put in
            currentScope="$scopeFolder/s$subnet.n$netmask" #Sets the file path for the scope file
            rm $currentScope #Deletes the scope file to prevent the user from adding on to an existing scope file
            echo -e "subnet $subnet netmask $netmask{\n}" >> $currentScope #Places the subnet and netmask info into the file
            dialogAddMenu
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
            scopeDelete=($(dialog --checklist "Delete scope(s)" 0 0 0 $scopeFiles 2>&1 1>&3))
            exec 3>&-
            exec 3>&1
            scopeDeleteYN=($(dialog --yesno "Are you sure you want to delete these scopes?: ${scopeDelete[*]}" 0 0 2>&1 1>&3))
            scopeDeleteYN=$?
            exec 3>&-
            if [[ $scopeDeleteYN == "0" ]]; then
                for fileDelete in ${scopeDelete[*]}; do #Deletes all files that are selected in the checklist box
                    rm "$scopeFolder/$fileDelete"
                done
            fi
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

dialogAddMenu () {
menuResult="" #To avoid soft lock of next line :)
while ! [[ $menuResult == "Back" ]]; do
    menuItems=""
    if ! $(grep -q "subnet-mask" $currentScope); then
        menuItems+="1 Subnet_mask "
    fi
    if ! $(grep -q "routers" $currentScope); then
        menuItems+="3 Router(s) "
    fi
    if ! $(grep -q "time-servers" $currentScope); then
        menuItems+="4 Time_server(s) "
    fi
    if ! $(grep -q "domain-name-servers" $currentScope); then
        menuItems+="6 DNS_server(s) "
    fi
    if ! $(grep -q "domain-name " $currentScope); then
        menuItems+="15 Domain_name "
    fi
    if ! $(grep -q "broadcast-address" $currentScope); then
        menuItems+="28 Broadcast_address "
    fi
    if ! $(grep -q "static-routes" $currentScope); then
        menuItems+="33 Static_route(s) "
    fi
    if ! $(grep -q "ntp-servers" $currentScope); then
        menuItems+="42 NTP_server(s) "
    fi
    if ! $(grep -q "tftp-server-name" $currentScope); then
        menuItems+="66 TFTP_server_name "
    fi
    if ! $(grep -q "bootfile-name" $currentScope); then
        menuItems+="67 Bootfile_name "
    fi
    menuItems+="Exclude_an_IP . "
    menuItems+="Set_scope_range . "
    menuItems+="Back . "
    exec 3>&1
    menuResult=$(dialog --menu "Options" 0 0 0 $menuItems 2>&1 1>&3)
    exec 3>&-
    case $menuResult in
    1)
        optionName="Subnet mask"
        optionCode="subnet-mask"
        optionMode="single"
        dialogInputbox
        ;;
    3)
        optionName="Router(s)"
        optionCode="routers"
        optionMode="single"
        dialogInputbox
        ;;
    4)
        optionName="Time server(s)"
        optionCode="time-servers"
        optionMode="multi"
        dialogInputbox
        ;;
    6)
        optionName="DNS servers"
        optionCode="domain-name-servers"
        optionMode="multi"
        dialogInputbox
        ;;
    15)
        optionName="Domain name"
        optionCode="domain-name"
        optionMode="quotes"
        dialogInputbox
        ;;
    28)
        optionName="Broadcast address"
        optionCode="broadcast-address"
        optionMode="single"
        dialogInputbox
        ;;
    33)
        optionName="Static route(s)"
        optionCode="static-routes"
        optionMode="multi"
        dialogInputbox
        ;;
    42)
        optionName="NTP server(s)"
        optionCode="ntp-servers"
        optionMode="multi"
        dialogInputbox
        ;;
    66)
        optionName="TFTP server"
        optionCode="tftp-server-name"
        optionMode="quotes"
        dialogInputbox
        ;;
    67)
        optionName="Boot file name"
        optionCode="bootfile-name"
        optionMode="quotes"
        dialogInputbox
        ;;
    "Exclude_an_IP")
        if $(grep -q "X:" $exclusionsFile) && $(grep -q "Z:" $exclusionsFile); then #Checks if a scope range has been set
            exec 3>&1
            excluding=$(dialog --inputbox "Which IP do you want to exclude?" 0 0 2>&1 1>&3)
            exec 3>&-
            exclusionAdd $excluding #Adds an IP to be excluded in the scopes
        else
            dialog --msgbox "Please set a scope range first" 0 0
        fi
        ;;
    "Set_scope_range")
        exclusionsFile="$exclusionsFolder/s$subnet.n$netmask" #Sets the file path for the exclusions file
        exec 3>&1
        scopeRange=$(dialog --inputbox "What range do you want? Example: 192.168.1.1 192.168.1.255" 0 0 2>&1 1>&3)
        exec 3>&-
        if $(grep -q "X:" $exclusionsFile); then #Checks if the user has already added a scope range
            xLine=$(grep -n "X:" $exclusionsFile | cut -d":" -f1) #Gets the line number for start of scope range
            replaceLine=$(echo $scopeRange | cut -d" " -f1) #Sets the variable to the first IP the user has put in the input box
            sed -i "${xLine}s|.*|X:${replaceLine}|" $exclusionsFile #Replaces the entire line with the desired scope range start
        else
            echo "X:$(echo $scopeRange | cut -d" " -f1)" >> $exclusionsFile #Puts the first IP the user has put in the input box at the end of the exclusions file
        fi
        if $(grep -q "Z:" $exclusionsFile); then #Same with previous
            zLine=$(grep -n "Z:" $exclusionsFile | cut -d":" -f1)
            replaceLine=$(echo $scopeRange | cut -d" " -f2)
            sed -i "${zLine}s|.*|Z:${replaceLine}|" $exclusionsFile
        else
            echo "Z:$(echo $scopeRange | cut -d" " -f2)" >> $exclusionsFile
        fi
        scopeGenerate
        ;;
    esac
done
}

exclusionAdd () {
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

scopeGenerate () { #This function generates scope ranges according to excluded IPs in the exclusions file
exclusionsFile="$exclusionsFolder/s$subnet.n$netmask" #Sets the file path for the exclusions file
currentScope="$scopeFolder/s$subnet.n$netmask" #Sets the file path for the scope file
sort -t . -k 3,3n -k 4,4n -o $exclusionsFile $exclusionsFile #Sorts the exclusions file and outputs it to the exclusions file to not confuse the generator
echo $(sed "$(grep -n "X:" $exclusionsFile | cut -d":" -f1),$(grep -n "Z:" $exclusionsFile | cut -d":" -f1)!d" $exclusionsFile) > $exclusionsFile #Removes IPs that are outside the scope
sed -i "s| |\n|g" $exclusionsFile #Replaces spaces with newline
for IP in $(cat $exclusionsFile)
do
    case $IP in
    X:*) #Checks if the current IP being processed is starting range
        cat $currentScope | grep -v "range\|}" > "$currentScope.temp" #Filters out ranges from scope file to a temporary file
        mv "$currentScope.temp" $currentScope #Moves the temporary file to scope file
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
        if [[ $rangeStart < $rangeEnd || $rangeStart == $rangeEnd ]]; then #Checks if the starting less than or equal to the ending range
            echo -e "    range $rangeStart $rangeEnd;\n}" >> $currentScope #Adds the range to the end of the scope file along with a }
        fi
        ;;
    esac
done
}

dialogMainMenu
