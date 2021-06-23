#!/bin/bash

#VERSION:201

dialog --msgbox "DEVELOPMENT ONLY" 0 0

#File paths
optFolder="/opt/dhcpDialog"

scopeFolder="$optFolder/dhcpScopes"
exclusionsFolder="$optFolder/exclusions"
dhcpdConfFile="$optFolder/dhcpd.conf"
LICENSE="$optFolder/LICENSE"
CONTRIBUTION="$optFolder/CONTRIBUTING.md"
ABOUT="$optFolder/ABOUT"
leasesFile="leasesFileReplace"
activeLeasesFile="$optFolder/active.leases"
#serversFile="$optFolder/servers.list" will be activated later

#Arrays
hashKeys=("subnet-mask" "routers" "domain-name-servers" "domain-name" "broadcast-address" "static-routes" "ntp-servers" "tftp-server-name" "bootfile-name")

declare -A optionKeytoName
optionKeytoName=(["subnet-mask"]="Subnet_mask" ["routers"]="Router(s)" ["domain-name-servers"]="DNS_server(s)" ["domain-name"]="Domain_name" ["broadcast-address"]="Broadcast_address" ["static-routes"]="Static_route(s)" ["ntp-servers"]="NTP_server(s)" ["tftp-server-name"]="TFTP_server(s)" ["bootfile-name"]="Boot_file_name")
declare -A optionNametoKey
optionNametoKey=(["Subnet_mask"]="subnet-mask" ["Router(s)"]="routers" ["DNS_server(s)"]="domain-name-servers" ["Domain_name"]="domain-name" ["Broadcast_address"]="broadcast-address" ["Static_route(s)"]="static-routes" ["NTP_server(s)"]="ntp-servers" ["TFTP_server(s)"]="tftp-server-name" ["Boot_file_name"]="bootfile-name")

#Non-menu functions go here
serviceRestart() {
    scopeDirCount=($(ls $scopeFolder/s*))
    exclusionsDirCount=($(ls $exclusionsFolder/s*))
    if [[ ${#scopeDirCount[@]} -ge 1 && ${#exclusionsDirCount[@]} -ge 1 ]]; then
        cat $scopeFolder/s*.n* > $dhcpdConfFile
    else
        echo "" > $dhcpdConfFile
    fi
    #service
}

ipAddition() {                                                                                                   #Function for adding IPs by 1
    rangeStart="${rangeStart%.*}.$(( ${rangeStart#*.*.*.} + 1))"                                                 #Get 1st 3 octets, add 1 to 4th
    [[ ${rangeStart#*.*.*.} -ge 256 ]] && \                                                                      #Check if 4th octet is ge to 256
        rangeStart="${rangeStart%.*.*}.$(( $(echo "$rangeStart" | cut -d"." -f3) + 1)).0"                        #Get 1st 2 octets, add 1 to 3rd, then set last to 0
    [[ $(echo "$rangeStart" | cut -d"." -f3 ) -ge 256 ]] && \                                                    #Check if 3rd octet is ge to 256
        rangeStart="${rangeStart%.*.*.*}.$(( $(echo "$rangeStart" | cut -d"." -f2) + 1)).0.${rangeStart#*.*.*.}" #Get 1st octet, add 1 to 2nd, set 3rd to 0, then get 4th
    [[ $(echo "$rangeStart" | cut -d"." -f2 ) -ge 256 ]] && \                                                    #Check if 2nd octet is ge to 256
        rangeStart="$(( ${rangeStart%.*.*.*} + 1)).0.${rangeStart#*.*.}"                                         #Add 1 to 1st octet, set 2nd to 0, then get last 2
    [[ ${rangeStart%.*.*.*} -ge 256 ]] && \                                                                      #Check if 1st octet is ge to 256
        rangeStart="255.${rangeStart#*.}"                                                                        #Set 1st octet to 255, then get last 3
}

ipSubtraction() {                                                                                                #Function for subtracting IPs by 1
    rangeEnd="${rangeEnd%.*}.$(( ${rangeEnd#*.*.*.} - 1))"                                                       #Get 1st 3 octets, subtract 4th by 1
    [[ ${rangeEnd%.*.*.*} -le -1 ]] && \                                                                         #Check if 4th octet is le to -1
        rangeEnd="${rangeEnd%.*.*}.$(( $(echo "$rangeEnd" | cut -d"." -f3) - 1)).255"                            #Get 1st 2 octets, subtract 3rd by 1, then set 4th to 255
    [[ $(echo "$rangeEnd" | cut -d"." -f3) -le -1 ]] && \                                                        #Check if 3rd octet is le to -1
        rangeEnd="${rangeEnd%.*.*.*}.$(( $(echo "$rangeEnd" | cut -d"." -f2) - 1)).255.${rangeEnd#*.*.*.}"       #Get 1st octet, subtract 2nd by 1, set 3rd to 255, then get last
    [[ $(echo "$rangeEnd" | cut -d"." -f2) -le -1 ]] && \                                                        #Check if 2nd octet is le to -1
        rangeEnd="$(( ${rangeEnd%.*.*.*} - 1)).255.${rangeEnd#*.*.}"                                             #Subtract 1st octet by 1, set 2nd to 255, then get last 2
    [[ ${rangeEnd#*.*.*.} -le -1 ]] && \                                                                         #Check if 1st octet is le to -1
        rangeEnd="0.${rangeEnd#*.}"                                                                              #Set 1st octet to 0, then get last 3
}

inputBoxOrEditMode() {                                                #For checking if a selected option should be edited or added
    if ! grep -q "$1 " "$currentScope"; then                          #Checks if option exists already ##FIXME: Confirm if an extra test is necessary here
        dialogInputbox                                                #Deploys the menu for adding options
    else
        editMenuMode                                                  #Deploys the menu for editing options
    fi
}

exclusionAdd() {
    exclusionsFile="$exclusionsFolder/s$subnet.n$netmask"   #Sets the file path for the exclusions file
    if grep -q "$1" "$exclusionsFile"; then                   #Checks if the IP is already excluded
        dialog --msgbox "That IP is already excluded!" 0 0
    else
        echo "Y:$1" >> "$exclusionsFile"                    #Puts excluded IP at the end of the file
        scopeGenerate                                       #Filters out invalid IPs as well as generates the scope into dhcpd.conf
    fi
}

scopeGenerate() {                                                                    #Filters out invalid IPs from exclusion and generates scope range
    exclusionsFile="$exclusionsFolder/s$subnet.n$netmask"                            #File path for exclusions
    currentScope="$scopeFolder/s$subnet.n$netmask"                                   #File path for scope options
    sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n -o "$exclusionsFile" "$exclusionsFile" #Sorts the IPs by ascending
    sed -i "/X/,/Z/!d" "$exclusionsFile"                                             #Removes IPs that are outside the scope
    sed -i "s_ _\n_g" "$exclusionsFile"                                              #Replaces spaces with newline
    for IP in $(cat "$exclusionsFile"); do
        case $IP in
        "X:"*)                                                                         #Checks if IP is start of scope
            sed -i "/range/d" "$currentScope"                                        #Removes every instance of range
            sed -i "/}/d" "$currentScope"                                            #Removes } from scope options
            rangeStart=${IP#*:}                                                      #Sets the starting range
        ;;
        "Y:"*)
            if [[ $rangeStart == "${IP#*:}" ]]; then                                 #Checks if the IP is excluded
                ipAddition                                                           #IP arithmetic :p
            else
                rangeEnd=${IP#*:}                                                    #Sets the ending range and subtracts by one to not include the excluded IP
                ipSubtraction                                                        #IP arithmetic :p
                echo "    range $rangeStart $rangeEnd;" >> "$currentScope"           #Adds new scope range to scope options
                rangeStart=${IP#*:}                                                 #Sets the starting range for the next excluded IP/end of scope and adds it by one
                ipAddition
            fi
        ;;
        "Z:"*)
            rangeEnd=${IP#*:}                                                       #Sets the ending range
            printf -v ip1 "%03d" "$(echo $rangeStart | cut -d"." -f1)"
            printf -v ip2 "%03d" "$(echo $rangeStart | cut -d"." -f2)"
            printf -v ip3 "%03d" "$(echo $rangeStart | cut -d"." -f3)"
            printf -v ip4 "%03d" "$(echo $rangeStart | cut -d"." -f4)"
            rangeStart2="$ip1$ip2$ip3$ip4"                                           #Sets 2nd range start to compare 2nd range end
            printf -v ip5 "%03d" "$(echo $rangeEnd | cut -d"." -f1)"
            printf -v ip6 "%03d" "$(echo $rangeEnd | cut -d"." -f2)"
            printf -v ip7 "%03d" "$(echo $rangeEnd | cut -d"." -f3)"
            printf -v ip8 "%03d" "$(echo $rangeEnd | cut -d"." -f4)"
            rangeEnd2="$ip5$ip6$ip7$ip8"                                             #Sets 2nd range end to compare 2nd range start
            if [[ $rangeStart2 < $rangeEnd2 || $rangeStart2 == "$rangeEnd2" ]]; then #Checks if starting range is less than ending range or if starting range is equal to ending range
                echo -e "    range $rangeStart $rangeEnd;\n}" >> "$currentScope"     #Adds the range to the end of the scope file along with a }
            fi
        ;;
        esac
    done
    serviceRestart                                                                   #Restarts the dhcp server
}

#Menu functions go under here
dialogMainMenu() {
    while [[ $mainMenuResult != "Exit" ]]; do
        exec 3>&1
        mainMenuResult=$(dialog --menu "Options" 0 0 0 \
        1 "Edit scope(s)" \
        2 "Add scope(s)" \
        3 "Delete scope(s)" \
        4 "View leases" \
        5 "About" \
        6 "Contribution" \
        7 "View the entire license" \
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
                if [[ $editChooseScope != "example" ]]; then
                    subnet=${editChooseScope%.*.*.*.*}
                    subnet=${subnet/s/}
                    netmask=${editChooseScope#*.*.*.*.}
                    netmask=${netmask/n/}
                    dialogEditMenu
                else
                    menuItems=""
                    for key in "${hashKeys[@]}"; do #Iterates through hashKeys and adds menu items using associative/hash arrays according to the keys
                        if ! grep -q "$key " "$currentScope"; then
                            menuItems+="${optionKeytoName[$key]} . "
                        else
                            menuItem="$(grep "$key " "$currentScope" | tr -s " ")"
                            menuItem="${menuItem# * * }"
                            menuItem="${menuItem//;}"
                            menuItem="${menuItem// /_}"
                            menuItems+="${optionKeytoName[$key]} $menuItem "
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
            if ! [[ -z $networkResult ]]; then                                #Checks if the input is not empty
                subnet=${networkResult% *}                                    #Gets the first value of the input
                netmask=${networkResult#* }                                   #Gets the second value of the input
                currentScope="$scopeFolder/s$subnet.n$netmask"                #Sets the file path for the scope file
                echo -e "subnet $subnet netmask $netmask{\n}" > "$currentScope" #Places the subnet and netmask info into the file
                touch "$exclusionsFolder/s$subnet.n$netmask"
                dialogEditMenu
            fi
        ;;
        3)
            if ! [[ -z $(dir $scopeFolder) ]]; then
                filesOutput=($(dir $scopeFolder)) #Makes an array of files that are in scopeFolder
                scopeFiles=""
                for file in ${filesOutput[*]}; do #Repeatedly adds items to arrays to dynamically create a checklist box
                    scopeFiles+="$file . off "
                done
                exec 3>&1
                scopeDelete=($(dialog --checklist "Delete scope(s) - Press space to select." 0 0 0 $scopeFiles 2>&1 1>&3))
                exec 3>&-
                if ! [[ -z "${scopeDelete[*]}" ]]; then
                    exec 3>&1
                    scopeDeleteYN=$(dialog --yesno "Are you sure you want to delete these scopes?: ${scopeDelete[*]}" 0 0 2>&1 1>&3)
                    scopeDeleteYN=$?
                    exec 3>&-
                fi
                if [[ $scopeDeleteYN == "0" ]]; then
                    for fileDelete in ${scopeDelete[*]}; do #Deletes all files that are selected in the checklist box
                        rm "$scopeFolder/$fileDelete"
                        rm "$exclusionsFolder/$fileDelete"
                    done
                fi
                serviceRestart
            else
                dialog --msgbox "There are no dhcp scopes!" 0 0
            fi
        ;;
        4)
            echo "" > $activeLeasesFile #Clear the active leases file
            leasesDump=$(grep -n "lease.*{\|}" $leasesFile) #Create a dump of all the logged leases in /var/lib/dhcp/dhcpd.leases
            leasesDump=${leasesDump//lease /}
            leasesDump=${leasesDump// \{/}
            leasesDump=${leasesDump//\} /\},}
            leasesDump=${leasesDump// /:}
            leasesDump=${leasesDump//,/ }
            for lease in $leasesDump; do #Go through all the leases
                if [[ $(echo "$lease" | cut -d":" -f1) == $(grep -n "lease $(echo "$lease" | cut -d":" -f2)" $leasesFile | tail -n 1 | cut -d":" -f1) ]]; then #Check if the current lease being check is the latest
                    startLine=$(echo "$lease" | cut -d":" -f1) #Get the starting line number of the lease
                    endLine=$(echo "$lease" | cut -d":" -f3) #Get the ending line number of the lease
                    for activeLease in $(grep -n "binding state active" "$leasesFile" | cut -d":" -f1); do #Go through all leases active leases
                        if [[ $activeLease -gt $startLine && $activeLease -lt $endLine ]]; then #Check if the lease being checked is an active lease
                            sed -n "${startLine},${endLine}p" "$leasesFile" >> "$activeLeasesFile" #Output the lease into a file
                            leasesMenu+="${lease#*:} . " #Add the lease to a dialog menu
                        fi
                    done
                fi
            done
            sed -i "1d" $activeLeasesFile #Delete the first line of active leases file to look nicer
            leasesDump=$(grep -n "lease.*{\|}" "$activeLeasesFile") #Create a dump of all the logged leases in the latest.leases file
            leasesDump=${leasesDump//lease /}
            leasesDump=${leasesDump// \{/}
            leasesDump=${leasesDump//\} /\},}
            leasesDump=${leasesDump// /:}
            leasesDump=${leasesDump//,/ }
            exec 3>&1
            leaseMenu=$(dialog --no-cancel --menu "View active leases" 0 0 0 $leasesMenu 2>&1 1>&3) #Menu for viewing leases inside a dialog menu
            exec 3>&-
            for lease in $leasesDump; do #Go through all leases in the latest.leases file
                if [[ $(echo "$lease" | cut -d":" -f2) == "$leaseMenu" ]]; then
                    startLine=$(echo "$lease" | cut -d":" -f1) #Get the starting line number of the lease
                    endLine=$(echo "$lease" | cut -d":" -f3) #Get the ending line number of the lease
                fi
            done
            dialog --msgbox "$(sed -n "${startLine},${endLine}p" $activeLeasesFile)" 0 0 #Display the selected lease
        ;;
        5)
            dialog --textbox $ABOUT 0 0 #Copyright notice and author contact information
        ;;
        6)
            dialog --textbox $CONTRIBUTION 0 0 #Copy of contribution rules
        ;;
        7)
            dialog --textbox $LICENSE 0 0 #Copy of GPL3.0 license
        ;;
        esac
    done
}

dialogEditMenu() {
menuResult="." #To avoid soft lock of next line, sometimes it can result in a "back" or "" (empty) which means it wonuldn't run the function
while ! [[ $menuResult == "Back" || $menuResult == "" ]]; do
    menuItems=""
    menuItem=""
    for key in "${hashKeys[@]}"; do #Iterates through hashKeys and adds menu items using associative/hash arrays according to the keys
        if ! grep -q "$key " "$currentScope"; then
            menuItems+="${optionKeytoName[$key]} . "
        else
            menuItem="$(grep "$key " "$currentScope" | tr -s " ")"
            menuItem="${menuItem# * * }"
            menuItem="${menuItem//;}"
            menuItem="${menuItem// /_}"
            menuItems+="${optionKeytoName[$key]} $menuItem "
        fi
    done
    menuItems+="Manage_excluded_IPs . "
    if ! grep -q "X" "$exclusionsFolder/s$subnet.n$netmask"; then #Reason for just X and not including Z (end of a scope): I am assuming Z is already included with X
        menuItems+="Set_scope_range . "
    else
        startValue="$(grep "X:" "$exclusionsFolder/s$subnet.n$netmask")"
        endValue="$(grep "Z:" "$exclusionsFolder/s$subnet.n$netmask")"
        menuItems+="Change_scope_range Start:${startValue#*:}_End:${endValue#*:} "
    fi
    menuItems+="Back . "
    exec 3>&1
    menuResult=$(dialog --menu "Options" 0 0 0 $menuItems 2>&1 1>&3)
    exec 3>&-
    optionMode="" #Clears the option mode
    case $menuResult in
    "Subnet_mask"|"Broadcast_address")
        optionName="${menuResult//_/ }"
        optionCode="${optionNametoKey[$menuResult]}"
        inputBoxOrEditMode "$optionCode"
    ;;
    "Router(s)"|"DNS_server(s)"|"Static_route(s)"|"NTP_server(s)")
        optionName="${menuResult//_/ }"
        optionCode="${optionNametoKey[$menuResult]}"
        optionMode="multi"
        inputBoxOrEditMode "$optionCode"
    ;;
    "Domain_name"|"TFTP_server_name"|"Bootfile_name")
        optionName="${menuResult//_/ }"
        optionCode="${optionNametoKey[$menuResult]}"
        optionMode="quotes"
        inputBoxOrEditMode "$optionCode"
    ;;
    "Manage_excluded_IPs")
        exclusionsFile="$exclusionsFolder/s$subnet.n$netmask"
        if grep -q "X:" "$exclusionsFile" && grep -q "Z:" "$exclusionsFile"; then #Checks if a scope range has been set
            exec 3>&1
            excludeOrView=$(dialog --menu "Manage exclusion list" 0 0 0 "1" "Exclude an IP" "2" "View or edit the list" 2>&1 1>&3)
            exec 3>&-
            if [[ $excludeOrView == "1" ]]; then
                exec 3>&1
                excluding=$(dialog --inputbox "Which IP do you want to exclude?" 0 0 2>&1 1>&3)
                exec 3>&-
                exclusionAdd "$excluding" #Adds an IP to be excluded in the scopes
            else
                if grep -q "Y:" "$exclusionsFile"; then
                    exclusionList=""
                    for IP in $(grep "Y:" "$exclusionsFile" | tr -d "Y:"); do
                        exclusionList+="$IP . off"
                    done
                    exec 3>&1
                    removeIPList=($(dialog --checklist "View or remove IPs from exclusion" 0 0 0 $exclusionList 2>&1 1>&3))
                    exec 3>&-
                    if ! [[ -z "${removeIPList[*]}" ]]; then
                        exec 3>&1
                        removeIPYN=$(dialog --yesno "Are you sure you want to remove these IPs from exlcusion?: ${removeIPList[*]}" 0 0 2>&1 1>&3)
                        removeIPYN=$?
                        exec 3>&-
                    fi
                    if [[ $removeIPYN == "0" ]]; then
                        for IP in ${removeIPList[*]}; do #Deletes all files that are selected in the checklist box
                            sed -i "/${IP}/d" "$exclusionsFile"
                        done
                    fi
                    scopeGenerate
                fi
            fi
        else
            dialog --msgbox "Please set a scope range first" 0 0
        fi
    ;;
    "Set_scope_range"|"Change_scope_range")
        exclusionsFile="$exclusionsFolder/s$subnet.n$netmask" #Sets the file path for the exclusions file
        exec 3>&1
        scopeRange=$(dialog --inputbox "What range do you want? Example: 192.168.1.1 192.168.1.255. Leave empty to delete." 0 0 2>&1 1>&3)
        exec 3>&-
        if ! [[ -z $scopeRange ]]; then
            if grep -q "X:" "$exclusionsFile"; then #Checks if the user has already added a scope range
                replaceLine=${scopeRange% *} #Sets the variable to the first IP the user has put in the input box
                sed -i "/X/s|.*|X:${replaceLine}|" "$exclusionsFile" #Replaces the entire line with the desired scope range start
            else
                echo "X:${scopeRange% *}" >> "$exclusionsFile" #Puts the first IP the user has put in the input box at the end of the exclusions file
            fi
            if grep -q "Z:" "$exclusionsFile"; then #Same with previous
                replaceLine=${scopeRange#* }
                sed -i "/Z/s_.*_Z:${replaceLine}_" "$exclusionsFile"
            else
                echo "Z:${scopeRange#* }" >> "$exclusionsFile"
            fi
            scopeGenerate
        else
            sed -i "/X:/d" "$exclusionsFile"
            sed -i "/Z:/d" "$exclusionsFile"
        fi
    ;;
    esac
    serviceRestart
done
}

dialogInputbox() {
    exec 3>&1
    optionResult=$(dialog --inputbox "$optionName" 0 0 2>&1 1>&3) #An input box to get user input for the chosen option
    exec 3>&-
    if ! [[ -z $optionResult ]]; then
        if grep -q "$optionCode " "$currentScope"; then #Checks if the option already exists in the scope file
            if [[ $optionMode == "multi" ]]; then #Checks if the option can have multiple values.
                sed -i "/${optionCode} /s_;_, ${optionResult};_" "$currentScope" #Replaces the existing semicolon with the desired value and adds a semicolon
            elif [[ $optionMode == "quotes" ]]; then
                sed -i "/${optionCode} /s_.*_    option ${optionCode} \"${optionResult}\";_" "$currentScope"
            else
                sed -i "/${optionCode} /s_.*_    option ${optionCode} ${optionResult};_" "$currentScope" #Replaces the entire line with the desired value
            fi
        elif [[ $optionMode == "quotes" ]]; then
            sed -i "/}/s_.*_    option ${optionCode} \"${optionResult}\";\n}_" "$currentScope"
        else
            sed -i "/}/s_.*_    option ${optionCode} ${optionResult};\n}_" "$currentScope" #Replaces the entire line with the desired option to be added and adds } at the end of the file
        fi
        serviceRestart
    fi
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
        inputInit="$(grep "$optionCode " "$currentScope" | tr -s " ")"
        inputInit="${inputInit#* * }"
        inputInit="${inputInit//;}"
        exec 3>&1
        optionEditInput=$(dialog --inputbox "Edit ${optionName,,}" 0 0 "$inputInit" 2>&1 1>&3)
        exec 3>&-
        sed -i "/${optionCode} /s_.*_    option ${optionCode} ${optionEditInput};_" "$currentScope"
    elif [[ $optionEditMode == "2" && $optionMode == "multi" ]]; then
        dialogInputbox
    elif [[ $optionEditMode == "2" ]] || [[ $optionEditMode == "3" && $optionMode == "multi" ]]; then
        exec 3>&1
        optionEditInput=$(dialog --yesno "Are you sure you want to delete $optionCode?" 0 0 2>&1 1>&3)
        optionEditInput=$?
        exec 3>&-
        if [[ $optionEditInput -eq "0" ]]; then
            sed -i "/${optionCode} /d" "$currentScope"
        fi
    fi
}

if [[ $1 == "--uninstall" ]]; then
    rm -rf /opt/dhcpDialog
    rm /usr/bin/dhcpDialog
else
    dialogMainMenu
fi
