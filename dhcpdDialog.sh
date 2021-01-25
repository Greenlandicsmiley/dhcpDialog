#!/bin/bash

scopeFolder="dhcpdRanges"

exclusionsFolder="exclusionsFolder"
exclusionsFile="$exclusionsFolder/s$subnet.n$netmask"
currentScope="$scopeFolder/s$subnet.n$netmask"

#Functions
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
    optionResult=$(dialog --inputbox "$(echo $option | cut -d':' -f1)" 0 0 2>&1 1>&3) #An input box to get user input for the chosen option
    exitcode=$?
    exec 3>&-
    if ! [[ -z $optionResult ]]; then
        case $option in
        *single) #Checks if the option is supposed to be single value
            lineString="option $(echo $option | cut -d":" -f2) $optionResult" #Variable to keep the code short and more understandable
            if $(grep -q "$(echo $option | cut -d":" -f2) " $currentScope); then #Checks if the option already exists in the scope file
                optionLine=$(grep -n "$(echo $option | cut -d":" -f2) " $currentScope | cut -d":" -f1) #Gets the line number for the option
                sed -i "${optionLine}s|.*|${lineString};|" $currentScope #Replaces the entire line with the desired value
            else
                curvedLineNumber=$(grep -n "}" $currentScope | cut -d":" -f1) #Gets the line number of }
                sed -i "${curvedLineNumber}s|.*|${lineString};\n}|" $currentScope #Replaces the entire line with the desired option to be added and adds } at the end of the file
            fi
            ;;
        *multi) #Checks if the option is supposed to have multiple values
            lineString="option $(echo $option | cut -d':' -f2) $optionResult" #Variable to keep the code short and more understandable 
            if $(grep -q "$(echo $option | cut -d":" -f2) " $currentScope); then #Checks if the option already exists
                optionLine=$(grep -n "$(echo $option | cut -d":" -f2) " $currentScope | cut -d":" -f1) #Gets the line number of the desired option to be added on
                sed -i "${optionLine}s|;|, ${optionResult};|" $currentScope #Replaces the existing semicolon with the desired value
            else
                curvedLineNumber=$(grep -n "}" $currentScope | cut -d":" -f1) #Gets the line number of }
                sed -i "${curvedLineNumber}s|.*|${lineString};\n}|" $currentScope #Replaces the entire line with the desired option to be added and places a } at the end of the file
            fi
            ;;
        *quotes) #Checks if the option is supposed to be in quotes
            lineString="option $(echo $option | cut -d":" -f2) \"$optionResult\"" #Variable to keep the code short and more understandable
            if $(grep -q "$(echo $option | cut -d":" -f2) " $currentScope); then #Checks if the option already exists
                optionLine=$(grep -n "$(echo $option | cut -d":" -f2) " $currentScope | cut -d":" -f1) #Gets the line number of the option
                sed -i "${optionLine}s|.*|${lineString};|" $currentScope #Replaces the entire line with the desired value: Reason for replacing the entire line: Most options where quotes are needed are usually single value. Will add support for multiple values if requested. You can also add it youself ;) it's open source anyway
            else
                curvedLineNumber=$(grep -n "}" $currentScope | cut -d":" -f1) #Gets the line number of }
                sed -i "${curvedLineNumber}s|.*|${lineString};\n}|" $currentScope #Replaces the entire line with the desired option to be added and places a } at the end of the file
            fi
            ;;
        esac
    fi
}

dialogMainMenu () {
while [[ $mainMenuResult != "Exit" ]]; do
    exec 3>&1
    mainMenuResult=$(dialog --menu "Options" 0 0 0 \
    1 "Edit scope(s) (CURRENTLY NOT AVAILABLE)" \
    2 "Add scope(s)" \
    3 "Delete scope(s) (CURRENTLY NOT AVAILABLE)" \
    "Exit" "" 2>&1 1>&3)
    mainMenuExitCode=$?
    exec 3>&-
    case $mainMenuResult in
    1)
        ;;
    2)
        exec 3>&1
        networkResult=$(dialog --inputbox "Which network do you want to add? Example: 192.168.1.0 255.255.255.0" 0 0 2>&1 1>&3)
        exec 3>&-
        if ! [[ -z $networkResult ]]; then
            subnet=$(echo $networkResult | cut -d" " -f1) #Sets the current subnet to what the user put in
            netmask=$(echo $networkResult | cut -d" " -f2) #Sets the current netmask to what the user put in
            currentScope="$scopeFolder/s$subnet.n$netmask" #Sets the file path for the scope file
            rm $currentScope #Deletes the scope file to prevent the user from adding on to an existing scope file
            echo -e "subnet $subnet netmask $netmask{\n}" >> $currentScope #Places the subnet and netmask info into the file
            dialogAddMenu
        fi
        ;;
    3)
        ;;
    esac
done
}

dialogAddMenu () {
while [[ $menuResult != "Back" ]]; do
    exec 3>&1
    menuResult=$(dialog --menu "Options" 0 0 0 \
    1 "Subnet mask" \
    3 "Router(s)" \
    4 "Time server(s)" \
    6 "DNS server(s)" \
    15 "Domain name" \
    28 "Broadcast address" \
    33 "Static route(s)" \
    42 "NTP server(s)" \
    66 "TFTP server(s)" \
    67 "Boot file name" \
    9999 "Exclude an IP" \
    "Set scope range" "" \
    "Back" "" 2>&1 1>&3)
    exec 3>&-
    case $menuResult in
    1)
        option="Subnet mask:subnet-mask:single" #One variable with multiple values to reduce variable count. Keeps the code short and readable
        dialogInputbox
        ;;
    3)
        option="Router(s):routers:single"
        dialogInputbox
        ;;
    4)
        option="Time server(s):time-servers:multi"
        dialogInputbox
        ;;
    6)
        option="DNS servers:domain-name-servers:multi"
        dialogInputbox
        ;;
    15)
        option="Domain name:domain-name:quotes"
        dialogInputbox
        ;;
    28)
        option="Broadcast address:broadcast-address:single"
        dialogInputbox
        ;;
    33)
        option="Static route(s):static-routes:multi"
        dialogInputbox
        ;;
    42)
        option="NTP server(s):ntp-servers:multi"
        dialogInputbox
        ;;
    66)
        option="TFTP server:tftp-server-name:quotes"
        dialogInputbox
        ;;
    67)
        option="Boot file name:bootfile-name:quotes"
        dialogInputbox
        ;;
    9999)
        if $(grep -q "X:" $exclusionsFile) && $(grep -q "Z:" $exclusionsFile); then #Checks if a scope range has been set
            exec 3>&1
            excluding=$(dialog --inputbox "Which IP do you want to exclude?" 0 0 2>&1 1>&3)
            exec 3>&-
            exclusionAdd $excluding #Adds an IP to be excluded in the scopes
        else
            dialog --msgbox "Please set a scope range first" 0 0
        fi
        ;;
    "Set scope range")
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
            echo "range $rangeStart $rangeEnd;" >> $currentScope #Adds a range to the end of the scope file
            rangeStart=$(echo "$IP" | cut -d":" -f2) #Sets the starting range for the next excluded IP/end of scope and adds it by one
            ipAddition
        fi
        ;;
    Z:*)
        rangeEnd=$(echo "$IP" | cut -d":" -f2) #Sets the ending range
        if [[ $rangeStart < $rangeEnd || $rangeStart == $rangeEnd ]]; then #Checks if the starting less than or equal to the ending range
            range="range $rangeStart $rangeEnd;" #Sets the range
            echo -e "$range\n}" >> $currentScope #Adds the range to the end of the scope file along with a }
        fi
        ;;
    esac
done
}

dialogMainMenu
