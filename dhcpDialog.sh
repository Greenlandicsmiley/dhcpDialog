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
leases_file="leasesFileReplace"
active_leases_file="$optFolder/active.leases"
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
    mainMenuResult="1"
    while ! [[ -z "$mainMenuResult" ]]; do
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
            [[ -z "$(dir $scopeFolder)" ]] && \
                dialog --msgbox "Please add a scope first." 0 0
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
            [[ -z "$(dir $scopeFolder)" ]] && dialog --msgbox "There are no dhcp scopes!" 0 0 && continue

            scopeFiles=""
            for file in $(dir $scopeFolder); do
                scopeFiles+="$file . off "
            done
            exec 3>&1
            scopeDelete="$(dialog --checklist "Delete scope(s) - Press space to select." 0 0 0 $scopeFiles 2>&1 1>&3)"
            exec 3>&-

            [[ -z "$scopeDelete" ]] && continue
            exec 3>&1
            scopeDeleteYN=$(dialog --yesno "Are you sure you want to delete these scopes?: ${scopeDelete[*]}" 0 0 2>&1 1>&3)
            scopeDeleteYN=$?
            exec 3>&-

            ! [[ $scopeDeleteYN == "0" ]] && continue
            for file in $scopeDelete; do
                rm "$scopeFolder/$file"
                rm "$exclusionsFolder/$file"
            done
            serviceRestart
        ;;
        4)
            dhcp_leases=$(grep -n "lease.*{" $leases_file)
            for lease in ${dhcp_leases// /_}; do
                ! [[ "${lease//_/ }" == "$(grep -n "${lease//_/ }" "$leases_file" | tail -n 1)" ]] && continue
                starting_line=${lease#:*}
                ending_line=$(( starting_line + 1 ))
                until [[ "$(sed -n "${ending_line}p" "$leases_file")" == "}" ]]; do
                    ending_line=$(( ending_line + 1 ))
                done
                for active_lease in $(grep -n "binding state active" "$leases_file"); do
                    ! [[ ${active_lease%:*} -gt $starting_line && ${active_lease%:*} -lt $ending_line ]] && continue
                    lease_ip="${lease% *}"
                    lease_ip="${lease_ip#*: }"
                    lease_ip_infos+="${starting_line}:${lease_ip}:${ending_line} "
                    lease_menu_items+="$lease_ip . "
                done
            done
            exec 3>&1
            lease_menu=$(dialog --menu "View active leases" 0 0 0 $lease_menu_items 2>&1 1>&3)
            exec 3>&-
            for lease in $lease_ip_infos; do
                lease_ip="${lease#*:}"
                starting_line="${lease%:*:*}"
                ending_line="${lease#*:*:}"
                [[ "${lease_ip%:*}" == "$lease_menu" ]] && break
            done
            dialog --msgbox "$(sed -n "${starting_line},${ending_line}p" $active_leases_file)" 0 0
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
    exclusionsFile="$exclusionsFolder/${subnet}s_n${netmask}"
    ! [[ -z "$1" ]] && printf "%s" "subnet $subnet netmask $netmask{\\n}" > "$currentScope" && \
        touch "$exclusionsFolder/${subnet}s_n${netmask}"
    while ! [[ -z "$menuResult" ]]; do
        menuItems=""
        for key in "${hashKeys[@]}"; do
            menuItem="$(grep "$key " "$currentScope")"
            menuItem="${menuItem#* }"
            menuItem="${menuItem//;}"
            ! grep -q "$key " "$currentScope" && menuItem="."
            menuItems+="${optionKeytoName[$key]} $menuItem "
        done
        if grep -q "X:" "$exclusionsFile" && grep -q "Z:" "$exclusionsFile"; then
            menuItems+="Manage_excluded_IPs . "
            startValue="$(grep "X:" "$exclusionsFile")"
            endValue="$(grep "Z:" "$exclusionsFile")"
            menuItems+="Change_scope_range ${startValue:2}-${endValue:2} "
        else
            menuItems+="Set_scope_range . "
        fi
        exec 3>&1
        menuResult=$(dialog --menu "Options" 0 0 0 $menuItems 2>&1 1>&3)
        exec 3>&-
        case $menuResult in
        "Subnet_mask"|"Broadcast_address")
            optionName="${menuResult//_/ }"
            optionCode="${optionNametoKey[$menuResult]}"
            optionMode=""
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

editMenuMode() {
    exec 3>&1
    option_edit_mode=$(dialog --menu "What do you want to do?" 0 0 0 "1" "Set value" "2" "Delete" 2>&1 1>&3)
    exec 3>&-
    if [[ $option_edit_mode == "1" ]]; then
        input_init="$(grep "$optionCode " "$currentScope")"
        input_init="${input_init#* }"
        input_init="${input_init//;}"
        exec 3>&1
        option_edit_input=$(dialog --inputbox "Set value(s) for ${optionName,,}. Separate with commas for multiple values. Some options may not be allowed to have multiple values." 0 0 "$input_init" 2>&1 1>&3)
        exec 3>&-
        [[ $option_mode == "quotes" ]] && option_edit_input="\"option_edit_input\""
        ! [[ $option_mode == "multi" ]] && option_edit_input="${option_edit_input//,*}"
        sed -i "/${optionCode} /s_.*_${optionCode} ${option_edit_input};_" "$currentScope"
    elif [[ $option_edit_mode == "2" ]]; then
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
