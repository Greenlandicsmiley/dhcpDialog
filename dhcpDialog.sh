#!/bin/bash

dialog --msgbox "DEVELOPMENT ONLY" 0 0

#File paths
optFolder="/opt/dhcpDialog"

scopeFolder="$optFolder/dhcpScopes"
exclusionsFolder="$optFolder/exclusions"
dhcpd_conf_file="$optFolder/dhcpd.conf"
LICENSE="$optFolder/LICENSE"
CONTRIBUTION="$optFolder/CONTRIBUTING.md"
ABOUT="$optFolder/ABOUT"
leases_file="leasesFileReplace"
active_leases_file="$optFolder/active.leases"
servers_list="$optFolder/servers.list"

#Arrays
hashKeys=("subnet-mask" "routers" "domain-name-servers" "domain-name" "broadcast-address" "static-routes" "ntp-servers" "tftp-server-name" "bootfile-name")

declare -A optionKeytoName
optionKeytoName=(["subnet-mask"]="Subnet mask" ["routers"]="Router(s)" ["domain-name-servers"]="DNS server(s)" ["domain-name"]="Domain name" ["broadcast-address"]="Broadcast address" ["static-routes"]="Static route(s)" ["ntp-servers"]="NTP server(s)" ["tftp-server-name"]="TFTP server(s)" ["bootfile-name"]="Boot file name")
declare -A optionNametoKey
optionNametoKey=(["Subnet mask"]="subnet-mask" ["Router(s)"]="routers" ["DNS server(s)"]="domain-name-servers" ["Domain name"]="domain-name" ["Broadcast address"]="broadcast-address" ["Static route(s)"]="static-routes" ["NTP server(s)"]="ntp-servers" ["TFTP server(s)"]="tftp-server-name" ["Boot file name"]="bootfile-name")

#Non-menu functions go here
serviceRestart() {
    cat $scopeFolder/s* > $dhcpd_conf_file
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
    ! grep -q "X:" "$exclusionsFile" || ! grep -q "Z:" "$exclusionsFile" && return 1

    sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n -o "$exclusionsFile" "$exclusionsFile"
    sed -i "/X/,/Z/!d" "$exclusionsFile"
    for IP in $(< "$exclusionsFile"); do
        case ${IP:2} in
        "X:")
            sed -i "/range/d" "$currentScope"
            rangeStart=${IP:2}
        ;;
        "Y:")
            [[ $rangeStart == "${IP:2}" ]] && \
                ipAddition && continue
            range_end=${IP:2}
            ipSubtraction
            sed -i "/}/s_.*_range $rangeStart $range_end;\\n}_" "$currentScope"
            rangeStart=${IP:2}
            ipAddition
        ;;
        "Z:")
            for octet in ${rangeStart//./ }; do
                range_start_no_dot+="$(printf "%03d" "$octet")"
            done
            range_end=${IP:2}
            for octet in ${range_end//./ }; do
                range_end_no_dot+="$(printf "%03d" "$octet")"
            done
            [[ $range_start_no_dot -le $range_end_no_dot ]] && \
                sed -i "/}/s_.*_range $rangeStart $range_end;\\n}_" "$currentScope"
        ;;
        esac
    done
}

#Menu functions go here - where Dialog commands will be invoked
dialog_main_menu() {
    main_menu=","
    while ! [[ -z "$main_menu" ]]; do
        exec 3>&1
        main_menu=$(dialog --menu "Options" 0 0 0 \
        1 "Edit scope(s)" \
        2 "Add scope(s)" \
        3 "Delete scope(s)" \
        4 "View leases" \
        5 "About" \
        6 "Contribution" \
        7 "View the entire license" 2>&1 1>&3)
        exec 3>&-
        case $main_menu in
        1)
            [[ -z "$(dir $scopeFolder)" ]] && \
                dialog --msgbox "Please add a scope first." 0 0 && continue
            available_scopes=""
            for scope in $(dir $scopeFolder); do
                available_scopes+="$scope . "
            done
            exec 3>&1
            editChooseScope=$(dialog --menu "Which network do you want to edit?" 0 0 0 $available_scopes 2>&1 1>&3)
            exec 3>&-
            [[ -z "$editChooseScope" ]] && continue

            subnet=${editChooseScope%s_*}
            netmask=${editChooseScope#*_n}
            dialogEditMenu
        ;;
        2)
            exec 3>&1
            networkResult=$(dialog --inputbox "Which network do you want to add? Examples: 192.168.1.0/24" 0 0 2>&1 1>&3)
            exec 3>&-
            [[ -z "$networkResult" ]] && continue

            subnet=${networkResult%/*}
            netmask=${networkResult#*/}
            dialogEditMenu ","
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
            scopeDeleteYN=$(dialog --yesno "Are you sure you want to delete these scopes?: $scopeDelete" 0 0 2>&1 1>&3)
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

dialog_servers() {
    for server in $(grep -n "server:" "$servers_list"); do
        server_line=""
        server_line=""
        hostname="${server#*:}"
        state="${server#*;}"
        [[ ${server#*;} == "local" ]] && \
            server_menu_list+=("${hostname%;*} $state") && \
            server_menu_list+=("${hostname%;*} $state")
    done
}

dialogEditMenu() {
    option_menu=","
    currentScope="$scopeFolder/${subnet}s_n${netmask}"
    exclusionsFile="$exclusionsFolder/${subnet}s_n${netmask}"
    cidr_notation="${netmask}"
    ! [[ -z "$1" ]] && printf "%s" "subnet $subnet netmask $netmask{\\n}" > "$currentScope" && \
        touch "$exclusionsFolder/${subnet}s_n${netmask}"
    while ! [[ -z "$option_menu" ]]; do
        x_line="$(grep "X:" "$exclusionsFile")"
        z_line="$(grep "Z:" "$exclusionsFile")"
        for key in "${hashKeys[@]}"; do
            option_value="$(grep "$key " "$currentScope")"
            option_value="${option_value#* }"
            [[ -z "$option_value" ]] && option_value="."
            menuItems+=("${optionKeytoName[$key]}")
            menuItems+=("${option_value//;}")
        done
        if ! [[ -z "$x_line" || -z "$x_line" ]]; then
            menuItems+=("View dhcp leases")
            menuItems+=(".")
            menuItems+=("Manage excluded IPs")
            menuItems+=(".")
            menuItems+=("Change scope range")
            menuItems+=("${x_line:2}-${z_line:2}")
        else
            menuItems+=("Set scope range")
            menuItems+=(".")
        fi
        exec 3>&1
        option_menu=$(dialog --menu "Options" 0 0 0 "${menuItems[@]}" 2>&1 1>&3)
        exec 3>&-
        optionName="$option_menu"
        optionCode="${optionNametoKey[$option_menu]}"
        optionMode=""
        case $option_menu in
        "Router(s)"|"DNS server(s)"|"Static route(s)"|"NTP server(s)")
            optionMode="multi"
        ;;
        "Domain name"|"TFTP server name"|"Bootfile name")
            optionMode="quotes"
        ;;
        "View dhcp leases")
            dhcp_leases=$(grep -n "lease.*{" $leases_file)
            for lease in ${dhcp_leases// /_}; do
                lease_ip="${lease% *}"
                lease_ip="${lease_ip#*: }"
                ! [[ "${lease//_/ }" == "$(grep -n "${lease//_/ }" "$leases_file" | tail -n 1)" ]] && continue
                for octet in 
                starting_line=${lease#:*}
                ending_line=$(( starting_line + 1 ))
                until [[ "$(sed -n "${ending_line}p" "$leases_file")" == "}" ]]; do
                    ending_line=$(( ending_line + 1 ))
                done
                for active_lease in $(grep -n "binding state active" "$leases_file"); do
                    ! [[ ${active_lease%:*} -gt $starting_line && ${active_lease%:*} -lt $ending_line ]] && continue
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
        "Manage excluded IPs")
            exec 3>&1
            excludeOrView=$(dialog --menu "Manage exclusion list" 0 0 0 "1" "Exclude an IP" "2" "View or edit the list" 2>&1 1>&3)
            exec 3>&-
            if [[ $excludeOrView == "1" ]]; then
                exec 3>&1
                excluding=$(dialog --inputbox "Which IP do you want to exclude?" 0 0 2>&1 1>&3)
                exec 3>&-
                grep -q "$excluding" "$exclusionsFile" && \
                    dialog --msgbox "That IP is already excluded!" 0 0 && continue
                echo "Y:$excluding" >> "$exclusionsFile"
            else
                ! grep -q "Y:" "$exclusionsFile" && continue
                exclusionList=""
                for IP in $(grep "Y:" "$exclusionsFile"); do
                    exclusionList+="${IP:2} . off"
                done
                exec 3>&1
                remove_ip_list=$(dialog --checklist "View or remove IPs from exclusion" 0 0 0 $exclusionList 2>&1 1>&3)
                exec 3>&-

                [[ -z "$remove_ip_list" ]] && continue
                exec 3>&1
                removeIPYN=$(dialog --yesno "Are you sure you want to remove these IPs from exlcusion?: $removeIPList" 0 0 2>&1 1>&3)
                removeIPYN=$?
                exec 3>&-

                ! [[ $removeIPYN == "0" ]] && continue
                for ip in $remove_ip_list; do
                    sed -i "/${ip}/d" "$exclusionsFile"
                done
            fi
        ;;
        "Set_scope_range"|"Change_scope_range")
            inputbox_init="$(grep "X:" "$exclusionsFile") $(grep "Z:" "$exclusionsFile")"
            exec 3>&1
            scope_range=$(dialog --inputbox "Set the scope range. Example: 192.168.1.1 192.168.1.255. Leave empty to delete." 0 0 "$inputbox_init" 2>&1 1>&3)
            exec 3>&-
            [[ -z "$scope_range" ]] && \
                sed -i "/X:/,/Z:/d" "$exclusionsFile" && continue
            sed -i "/X:/s_.*_X:${scope_range% *}_" "$exclusionsFile"
            sed -i "/Z:/s_.*_Z:${scope_range#* }_" "$exclusionsFile"
        ;;
        esac
        ! [[ $option_menu =~ ^("Manage_excluded_IPs"|"Set_scope_range"|"Change_scope_range")$ ]] && \
            dialog_edit_menu
        scopeGenerate
        serviceRestart
    done
}

dialog_edit_menu() {
    exec 3>&1
    edit_menu=$(dialog --menu "What do you want to do?" 0 0 0 "1" "Set value" "2" "Delete" 2>&1 1>&3)
    exec 3>&-
    input_init=""
    if [[ $edit_menu == "1" ]]; then
        input_init="$(grep "$optionCode " "$currentScope")"
        input_init="${input_init#* }"
        input_init="${input_init//;}"
        exec 3>&1
        option_edit_input=$(dialog --inputbox "Set value(s) for ${optionName,,}. Separate with commas for multiple values. Some options may not be allowed to have multiple values." 0 0 "$input_init" 2>&1 1>&3)
        exec 3>&-
        ! [[ $option_mode == "multi" ]] && option_edit_input="${option_edit_input//,*}"
        [[ $option_mode == "quotes" ]] && option_edit_input="\"${option_edit_input}\""
        sed -i "/${optionCode} /s_.*_${optionCode} ${option_edit_input};_" "$currentScope"
    elif [[ $edit_menu == "2" ]]; then
        exec 3>&1
        confirm_option_delete=$(dialog --yesno "Are you sure you want to delete $optionCode?" 0 0 2>&1 1>&3)
        confirm_option_delete=$?
        exec 3>&-
        [[ $confirm_option_delete ]] && \
            sed -i "/${optionCode} /d" "$currentScope"
    fi
}

#if [[ $1 == "--uninstall" || $1 == "-u" ]]; then
#    rm -rf /opt/dhcpDialog
#    rm /usr/bin/dhcpDialog
#else
#    dialogMainMenu
#fi
