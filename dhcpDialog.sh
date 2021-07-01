#!/bin/bash

#VERSION:202

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
#serversFile="$optFolder/servers.list"

#Arrays
hashKeys=("subnet-mask" "routers" "domain-name-servers" "domain-name" "broadcast-address" "static-routes" "ntp-servers" "tftp-server-name" "bootfile-name")

declare -A optionKeytoName
optionKeytoName=(["subnet-mask"]="Subnet_mask" ["routers"]="Router(s)" ["domain-name-servers"]="DNS_server(s)" ["domain-name"]="Domain_name" ["broadcast-address"]="Broadcast_address" ["static-routes"]="Static_route(s)" ["ntp-servers"]="NTP_server(s)" ["tftp-server-name"]="TFTP_server(s)" ["bootfile-name"]="Boot_file_name")
declare -A optionNametoKey
optionNametoKey=(["Subnet_mask"]="subnet-mask" ["Router(s)"]="routers" ["DNS_server(s)"]="domain-name-servers" ["Domain_name"]="domain-name" ["Broadcast_address"]="broadcast-address" ["Static_route(s)"]="static-routes" ["NTP_server(s)"]="ntp-servers" ["TFTP_server(s)"]="tftp-server-name" ["Boot_file_name"]="bootfile-name")

#Non-menu functions go here
serviceRestart() {
    cat $scopeFolder/s* > $dhcpdConfFile
    #service
}

ipAddition() {
    range_start_octet_2="${rangeStart#*.}" && range_start_octet_2="${rangeStart%.*.*}"
    range_start_octet_3="${rangeStart#*.*.}" && range_start_octet_3="${rangeStart%.*}"
    rangeStart="${rangeStart%.*}.$(( ${rangeStart#*.*.*.} + 1 ))"
    [[ ${rangeStart#*.*.*.} -ge 256 ]] && \
        rangeStart="${rangeStart%.*.*}.$(( range_start_octet_3 + 1 )).0"
    [[ $range_start_octet_3 -ge 256 ]] && \
        rangeStart="${rangeStart%.*.*.*}.$(( range_start_octet_2 + 1 )).0.${rangeStart#*.*.*.}"
    [[ $range_start_octet_2 -ge 256 ]] && \
        rangeStart="$(( ${rangeStart%.*.*.*} + 1 )).0.${rangeStart#*.*.}"
    [[ ${rangeStart%.*.*.*} -ge 256 ]] && \
        rangeStart="255.${rangeStart#*.}"
}

ipSubtraction() {
    range_end_octet_2="${range_end#*.}" && range_end_octet_2="${range_end%.*.*}"
    range_end_octet_3="${range_end#*.*.}" && range_end_octet_3="${range_end%.*}"
    range_end="${range_end%.*}.$(( ${range_end#*.*.*.} - 1 ))"
    [[ ${range_end#*.*.*.} -le -1 ]] && \
        range_end="${range_end%.*.*}.$(( range_end_octet_3 - 1 )).255"
    [[ $range_end_octet_3 -le -1 ]] && \
        range_end="${range_end%.*.*.*}.$(( range_end_octet_2 - 1 )).255.${range_end#*.*.*.}"
    [[ $range_end_octet_2 -le -1 ]] && \
        range_end="$(( ${range_end%.*.*.*} - 1 )).255.${range_end#*.*.}"
    [[ ${range_end%.*.*.*} -le -1 ]] && \
        range_end="0.${range_end#*.}"
}

inputBoxOrEditMode() {
    grep -q "$1 " "$currentScope" && \
        editMenuMode && return 0
    dialogInputbox
}

scopeGenerate() {            
    if grep -q "X:\\|Z:" "$exclusionsFile"; then                                                       
        exclusionsFile="$exclusionsFolder/s$subnet.n$netmask"
        currentScope="$scopeFolder/s$subnet.n$netmask"
        sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n -o "$exclusionsFile" "$exclusionsFile"
        sed -i "/X/,/Z/!d" "$exclusionsFile"
        for IP in $(< "$exclusionsFile"); do
            case $IP in
            "X:"*)
                sed -i "/range/d" "$currentScope"
                sed -i "/}/d" "$currentScope"
                rangeStart=${IP:2}
            ;;
            "Y:"*)
                if [[ $rangeStart == "${IP:2}" ]]; then
                    ipAddition
                else
                    range_end=${IP:2}
                    ipSubtraction
                    printf "%s" "    range $rangeStart $range_end;" >> "$currentScope"
                    rangeStart=${IP:2}
                    ipAddition
                fi
            ;;
            "Z:"*)
                range_start_octet_2="${range_end#*.*.}" && range_start_octet_2="${range_end%.*.*}"
                range_start_octet_3="${range_end#*.*.}" && range_start_octet_3="${range_end%.*}"
                printf -v range_start_no_dot_1 "%03d%03d" "${range_end#*.*.*.}" "$range_start_octet_2"
                printf -v range_start_no_dot_2 "%03d%03d" "$range_start_octet_3" "${range_end#*.*.*.}"
                range_start_no_dot="$range_start_no_dot_1$range_start_no_dot_2"

                range_end=${IP:2}
                range_end_octet_2="${range_end#*.*.}" && range_start_octet_2="${range_end%.*.*}"
                range_end_octet_3="${range_end#*.*.}" && range_start_octet_3="${range_end%.*}"
                printf -v range_end_no_dot "%03d%03d" "${range_end#*.*.*.}" "$range_end_octet_2"
                printf -v range_end_no_dot "%03d%03d" "$range_end_octet_3" "${range_end#*.*.*.}"
                range_end_no_dot="$range_end_no_dot_1$range_end_no_dot_2"
                [[ $range_start_no_dot -le $range_end_no_dot ]] && \
                    printf "%s" "    range $rangeStart $range_end;\\n}" >> "$currentScope"
            ;;
            esac
        done
    fi
    serviceRestart
}

#Menu functions go here - where Dialog will be invoked
dialogMainMenu() {
    while ! [[ -z "$mainMenuResult" ]]; do
        mainMenuResult="1"
        exec 3>&1
        mainMenuResult=$(dialog --menu "Options" 0 0 0 \
        1 "Edit scope(s)" \
        2 "Add scope(s)" \
        3 "Delete scope(s)" \
        4 "View leases" \
        5 "About" \
        6 "Contribution" \
        7 "View the entire license" 2>&1 1>&3)
        exec 3>&-
        case $mainMenuResult in
        1)
            available_scopes=""
            for scope in $(dir $scopeFolder); do
                available_scopes+="$scope . "
            done
            exec 3>&1
            editChooseScope=$(dialog --menu "Which scope do you want to edit?" 0 0 0 $available_scopes 2>&1 1>&3)
            exec 3>&-
            if ! [[ -z "$editChooseScope" ]]; then
                subnet=${editChooseScope%s_*}
                netmask=${editChooseScope#*_n}
                dialogEditMenu
            fi
        ;;
        2)
            exec 3>&1
            networkResult=$(dialog --inputbox "Which network do you want to add? Example: 192.168.1.0 255.255.255.0" 0 0 2>&1 1>&3)
            exec 3>&-
            if ! [[ -z "$networkResult" ]]; then
                subnet=${networkResult% *}
                netmask=${networkResult#* }
                dialogEditMenu ","
            fi
        ;;
        3)
            if ! [[ -z $(dir $scopeFolder) ]]; then
                filesOutput=($(dir $scopeFolder))
                scopeFiles=""
                for file in ${filesOutput[*]}; do
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
                    for fileDelete in ${scopeDelete[*]}; do
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
            echo "" > $activeLeasesFile
            leasesDump=$(grep -n "lease.*{\\|}" $leasesFile)
            leasesDump=${leasesDump//lease /}
            leasesDump=${leasesDump// \{/}
            leasesDump=${leasesDump//\} /\},}
            leasesDump=${leasesDump// /:}
            leasesDump=${leasesDump//,/ }
            for lease in $leasesDump; do
                if [[ $(echo "$lease" | cut -d":" -f1) == $(grep -n "lease $(echo "$lease" | cut -d":" -f2)" $leasesFile | tail -n 1 | cut -d":" -f1) ]]; then
                    startLine=$(echo "$lease" | cut -d":" -f1)
                    endLine=$(echo "$lease" | cut -d":" -f3)
                    for activeLease in $(grep -n "binding state active" "$leasesFile" | cut -d":" -f1); do
                        if [[ $activeLease -gt $startLine && $activeLease -lt $endLine ]]; then
                            sed -n "${startLine},${endLine}p" "$leasesFile" >> "$activeLeasesFile"
                            leasesMenu+="${lease#*:} . "
                        fi
                    done
                fi
            done
            sed -i "1d" $activeLeasesFile
            leasesDump=$(grep -n "lease.*{\\|}" "$activeLeasesFile")
            leasesDump=${leasesDump//lease /}
            leasesDump=${leasesDump// \{/}
            leasesDump=${leasesDump//\} /\},}
            leasesDump=${leasesDump// /:}
            leasesDump=${leasesDump//,/ }
            exec 3>&1
            leaseMenu=$(dialog --no-cancel --menu "View active leases" 0 0 0 $leasesMenu 2>&1 1>&3)
            exec 3>&-
            for lease in $leasesDump; do
                if [[ $(echo "$lease" | cut -d":" -f2) == "$leaseMenu" ]]; then
                    startLine=$(echo "$lease" | cut -d":" -f1)
                    endLine=$(echo "$lease" | cut -d":" -f3)
                fi
            done
            dialog --msgbox "$(sed -n "${startLine},${endLine}p" $activeLeasesFile)" 0 0
        ;;
        5)
            dialog --textbox $ABOUT 0 0
        ;;
        6)
            dialog --textbox $CONTRIBUTION 0 0
        ;;
        7)
            dialog --textbox $LICENSE 0 0
        ;;
        esac
    done
}

dialogEditMenu() {
menuResult=","
currentScope="$scopeFolder/${subnet}s_n${netmask}"
printf "%s" "subnet $subnet netmask $netmask{\\n}" > "$currentScope"
touch "$exclusionsFolder/${subnet}s_n${netmask}"
exclusionsFile="$exclusionsFolder/${subnet}s_n${netmask}"
while ! [[ -z "$menuResult" ]]; do
    menuItems=""
    menuItem=""
    for key in "${hashKeys[@]}"; do
        menuItem="$(grep "$key " "$currentScope" | tr -s " ")"
        menuItem="${menuItem# * * }"
        menuItem="${menuItem//;}"
        ! grep -q "$key " "$currentScope" && menuItem="."
        menuItems+="${optionKeytoName[$key]} ${menuItem// /_} "
    done
    if grep -q "X:" "$exclusionsFile" && grep -q "Z:" "$exclusionsFile"; then
        menuItems+="Manage_excluded_IPs . "
        startValue="$(grep "X:" "$exclusionsFile")"
        endValue="$(grep "Z:" "$exclusionsFile")"
        menuItems+="Change_scope_range Start:${startValue:2}_End:${endValue:2} "
    else
        menuItems+="Set_scope_range . "
    fi
    exec 3>&1
    menuResult=$(dialog --menu "Options" 0 0 0 $menuItems 2>&1 1>&3)
    exec 3>&-
    optionMode=""
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
        exec 3>&1
        excludeOrView=$(dialog --menu "Manage exclusion list" 0 0 0 "1" "Exclude an IP" "2" "View or edit the list" 2>&1 1>&3)
        exec 3>&-
        if [[ $excludeOrView == "1" ]]; then
            exec 3>&1
            excluding=$(dialog --inputbox "Which IP do you want to exclude?" 0 0 2>&1 1>&3)
            exec 3>&-
            grep -q "$excluding" "$exclusionsFile" && \
                dialog --msgbox "That IP is already excluded!" 0 0 && return 0
            echo "Y:$excluding" >> "$exclusionsFile"
        else
            if grep -q "Y:" "$exclusionsFile"; then
                exclusionList=""
                for IP in $(grep "Y:" "$exclusionsFile"); do
                    exclusionList+="${IP:2} . off"
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
                    for IP in ${removeIPList[*]}; do
                        sed -i "/${IP}/d" "$exclusionsFile"
                    done
                fi
            fi
        fi
        scopeGenerate
    ;;
    "Set_scope_range"|"Change_scope_range")
        exclusionsFile="$exclusionsFolder/s$subnet.n$netmask"
        exec 3>&1
        scope_range=$(dialog --inputbox "What range do you want? Example: 192.168.1.1 192.168.1.255. Leave empty to delete." 0 0 2>&1 1>&3)
        exec 3>&-
        if ! [[ -z $scope_range ]]; then
            if grep -q "X:" "$exclusionsFile"; then
                replaceLine=${scope_range% *}
                sed -i "/X/s|.*|X:${replaceLine}|" "$exclusionsFile"
            else
                echo "X:${scope_range% *}" >> "$exclusionsFile"
            fi
            if grep -q "Z:" "$exclusionsFile"; then
                replaceLine=${scope_range#* }
                sed -i "/Z/s_.*_Z:${replaceLine}_" "$exclusionsFile"
            else
                echo "Z:${scope_range#* }" >> "$exclusionsFile"
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
    optionResult=$(dialog --inputbox "$optionName" 0 0 2>&1 1>&3)
    exec 3>&-
    if ! [[ -z $optionResult ]]; then
        if grep -q "$optionCode " "$currentScope"; then
            if [[ $optionMode == "multi" ]]; then
                sed -i "/${optionCode} /s_;_, ${optionResult};_" "$currentScope"
            elif [[ $optionMode == "quotes" ]]; then
                sed -i "/${optionCode} /s_.*_    option ${optionCode} \"${optionResult}\";_" "$currentScope"
            else
                sed -i "/${optionCode} /s_.*_    option ${optionCode} ${optionResult};_" "$currentScope"
            fi
        elif [[ $optionMode == "quotes" ]]; then
            sed -i "/}/s_.*_    option ${optionCode} \"${optionResult}\";\\n}_" "$currentScope"
        else
            sed -i "/}/s_.*_    option ${optionCode} ${optionResult};\\n}_" "$currentScope"
        fi
        serviceRestart
    fi
}

editMenuMode() {
    option_edit_mode_items="1 Edit 2 Add_an_option 3 Delete"
    ! [[ $optionMode == "multi" ]] && option_edit_mode_items="1 Edit 2 Delete"
    exec 3>&1
    option_edit_mode=$(dialog --menu "What do you want to do?" 0 0 0 $option_edit_mode_items 2>&1 1>&3)
    exec 3>&-
    if [[ $option_edit_mode == "1" ]]; then
        input_init="$(grep "$optionCode " "$currentScope")"
        input_init="${input_init//    }"
        input_init="${input_init#* * }"
        input_init="${input_init//;}"
        exec 3>&1
        option_edit_input=$(dialog --inputbox "Editing ${optionName,,}" 0 0 "$input_init" 2>&1 1>&3)
        exec 3>&-
        sed -i "/${optionCode} /s_.*_    option ${optionCode} ${option_edit_input};_" "$currentScope"
    elif [[ $option_edit_mode == "2" && $optionMode == "multi" ]]; then
        dialogInputbox
    elif [[ $option_edit_mode == "2" ]] || [[ $option_edit_mode == "3" ]]; then
        exec 3>&1
        confirm_option_delete=$(dialog --yesno "Are you sure you want to delete $optionCode?" 0 0 2>&1 1>&3)
        confirm_option_delete=$?
        exec 3>&-
        [[ $confirm_option_delete -eq "0" ]] && \
            sed -i "/${optionCode} /d" "$currentScope"
    fi
}

#if [[ $1 == "--uninstall" || $1 == "-u" ]]; then
#    rm -rf /opt/dhcpDialog
#    rm /usr/bin/dhcpDialog
#else
#    dialogMainMenu
#fi
