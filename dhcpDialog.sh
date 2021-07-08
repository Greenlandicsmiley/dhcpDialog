#!/bin/bash

dialog --msgbox "DEVELOPMENT ONLY" 0 0

#File paths
optFolder="/opt/dhcpDialog"
server_folder="/srv/dhcpDialog"


scope_folder="$optFolder/dhcpScopes"
exclusionsFolder="$optFolder/exclusions"
dhcpd_conf_file="$optFolder/dhcpd.conf"
LICENSE="$optFolder/LICENSE"
ABOUT="$optFolder/ABOUT"
leases_file="leasesFileReplace"
servers_list="$optFolder/servers.list"

#Arrays
options_list=("subnet-mask" "routers" "domain-name-servers" "domain-name" "broadcast-address" "static-routes" "ntp-servers" "tftp-server-name" "bootfile-name")

declare -A optionKeytoName
optionKeytoName=(["subnet-mask"]="Subnet mask" ["routers"]="Router(s)" ["domain-name-servers"]="DNS server(s)" ["domain-name"]="Domain name" ["broadcast-address"]="Broadcast address" ["static-routes"]="Static route(s)" ["ntp-servers"]="NTP server(s)" ["tftp-server-name"]="TFTP server(s)" ["bootfile-name"]="Boot file name")
declare -A optionNametoKey
optionNametoKey=(["Subnet mask"]="subnet-mask" ["Router(s)"]="routers" ["DNS server(s)"]="domain-name-servers" ["Domain name"]="domain-name" ["Broadcast address"]="broadcast-address" ["Static route(s)"]="static-routes" ["NTP server(s)"]="ntp-servers" ["TFTP server(s)"]="tftp-server-name" ["Boot file name"]="bootfile-name")

#Non-menu functions go here
serviceRestart() {
    cat $scope_folder/s* > $dhcpd_conf_file
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
            unset range_start_no_dot
            for octet in ${rangeStart//./ }; do
                range_start_no_dot+="$(printf "%03d" "$octet")"
            done
            range_end=${IP:2}
            unset range_end_no_dot
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
    while ! [[ -z "$main_menu" ]]; do
        unset main_menu_list
        main_menu_list+=("1" "About" "2" "License" "3" "Add server")
        server_number=4
        for server in $(dir $server_folder); do
            server_conf_file="$server_folder/$server/server.conf"
            server_role="$(grep "Role:" "$server_conf_file")"
            server_name="$(grep "Name:" "$server_conf_file")"
            server_address="$(grep "Address:" "$server_conf_file")"
            main_menu_list+=("${server_number} ${server_name}" "${server_role} ${server_address}")
            server_menu_number=$(( server_number + 1 ))
        done
        exec 3>&1
        main_menu=$(dialog --cancel-label "Exit" --menu "Choose a dhcp server" 0 0 0 "${main_menu_list[@]}" 2>&1 1>&3)
        exec 3>&-
        main_menu_result=${main_menu# *}
        case $main_menu_result in
        1)
            dialog --textbox $ABOUT 0 0
            continue
        ;;
        2)
            dialog --textbox $LICENSE 0 0
            continue
        ;;
        3)
            exec 3>&1
            new_server_name="$(dialog --inputbox "Name of the server" 0 0 )"
            exec 3>&-
            mkdir "$server_folder/${new_server_name// /_}"
        ;;
        esac
        [[ -z "$main_menu" ]] && continue
        current_server="${main_menu#* }"
        leases_file="$srv_folder/${current_server}/dhcpd.leases"
        dhcpd_conf_file="$srv_folder/${current_server}/dhcpd.conf"
        scope_folder="$srv_folder/${current_server}/dhcpScopes"
        exclusionsFolder="$srv_folder/${current_server}/exclusions"
        current_scope="$(grep "Default Scope:" "$server_folder/$current_server/server.conf")"
        current_scope="${current_scope#*:}"
        dialog_scope_menu
    done
}

dialog_scope_menu() {
    while ! [[ -z "$scope_menu" ]]; do
        scope_menu_items+=("1" "Change current scope" "2" "Create new scope" "3" "Delete current scope" "4" "Set server configurations")
        scope_menu_number=4
        current_scope_file="$server_folder/$current_server/dhcp_scopes/$current_scope"
        for option in "${options_list[@]}"; do
            option_list_string="$(grep "$option" "$current_scope_file")"
            option_list_name="${optionKeytoName[${option_list_string% *}}"
            option_list_value="${option_list_string#* }"
            scope_menu_items+=("${scope_menu_number} ${option_list_name}" "${option_list_value}")
            scope_menu_number=$(( scope_menu_number + 1 ))
        done
        exec 3>&1
        scope_menu=$(dialog --cancel-label "Back" --menu "Current scope: ${current_scope}\\nCurrent server: ${current_server}" 0 0 0 "${scope_menu_items[@]}" 2>&1 1>&3)
        exec 3>&-
        option_name="${scope_menu#* }"
        option_code="${optionNametoKey[$scope_menu]}"
        option_mode=""
        case ${scope_menu#* } in
        "Change current scope")
            [[ -z "$(dir $scope_folder)" ]] && \
                dialog --msgbox "Add a scope first." 0 0 && continue
            available_scopes=""
            for scope in $(dir $scope_folder); do
                available_scopes+="$scope . "
            done
            exec 3>&1
            choose_scope_menu=$(dialog --cancel-label "Back" --menu "Choose a scope to change to" 0 0 0 $available_scopes 2>&1 1>&3)
            exec 3>&-
            [[ -z "$choose_scope_menu" ]] && continue

            subnet=${choose_scope_menu%s_*}
            netmask=${choose_scope_menu#*_n}
            continue
        ;;
        "Create new scope")
            exec 3>&1
            networkResult=$(dialog --cancel-label "Back" --inputbox "Create a scope. Example: 192.168.1.0/24" 0 0 2>&1 1>&3)
            exec 3>&-
            [[ -z "$networkResult" ]] && continue

            subnet=${networkResult%/*}
            netmask=${networkResult#*/}
            continue
        ;;
        "Delete current scope")
            [[ -z "$(dir $scope_folder)" ]] && dialog --msgbox "There are no dhcp scopes." 0 0 && continue

            scopeFiles=""
            for file in $(dir $scope_folder); do
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
                rm "$scope_folder/$file"
                rm "$exclusionsFolder/$file"
            done
            serviceRestart
        ;;
        "Set server configurations")
            dialog_server_configuration_menu
        ;;
        "Router(s)"|"DNS server(s)"|"Static route(s)"|"NTP server(s)")
            option_mode="multi"
        ;;
        "Domain name"|"TFTP server name"|"Bootfile name")
            option_mode="quotes"
        ;;
        esac
    done
}

dialog_server_configuration_menu() {
    while ! [[ -z "$server_configuration_menu" ]]; do
        exec 3>&1
        server_configuration_menu=$(dialog --cancel-label "Back" --menu "Change server configuration" 0 0 0 \
            "1" "Server role" \
            "2" "Server name" \
            "3" "Server user" \
            "4" "IP address" \
            "5" "Default scope" \
            "6" "SSH key" 2>&1 1>&3)
        exec 3>&-
    done
}

dialogEditMenu() {
    option_menu=","
    currentScope="$scope_folder/${subnet}s_n${netmask}"
    exclusionsFile="$exclusionsFolder/${subnet}s_n${netmask}"
    cidr_notation="${netmask}"
    ! [[ -z "$1" ]] && printf "%s" "subnet $subnet netmask $netmask{\\n}" > "$currentScope" && \
        touch "$exclusionsFolder/${subnet}s_n${netmask}"
    while ! [[ -z "$option_menu" ]]; do
        x_line="$(grep "X:" "$exclusionsFile")"
        z_line="$(grep "Z:" "$exclusionsFile")"
        for key in "${options_list[@]}"; do
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
            dialog --msgbox "$(sed -n "${starting_line},${ending_line}p" $leases_file)" 0 0 
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
