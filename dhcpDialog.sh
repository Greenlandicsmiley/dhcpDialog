#!/bin/bash

dialog --msgbox "DEVELOPMENT ONLY" 0 0

#Source variables from .env file except for ABOUT and LICENSE
. /etc/dhcpDialog.env

LICENSE="$OPT_DIR/LICENSE"
ABOUT="$OPT_DIR/ABOUT"

#Arrays
options_list=("subnet-mask" "routers" "domain-name-servers" "domain-name" "broadcast-address" "static-routes" "ntp-servers" "tftp-server-name" "bootfile-name")

declare -A optionKeytoName #Associative array to easily convert pretty names to config names
optionKeytoName=(["subnet-mask"]="Subnet mask" ["routers"]="Router(s)" ["domain-name-servers"]="DNS server(s)" ["domain-name"]="Domain name" ["broadcast-address"]="Broadcast address" ["static-routes"]="Static route(s)" ["ntp-servers"]="NTP server(s)" ["tftp-server-name"]="TFTP server(s)" ["bootfile-name"]="Boot file name")
declare -A optionNametoKey #Associative array to easily convert config names to pretty names
optionNametoKey=(["Subnet mask"]="subnet-mask" ["Router(s)"]="routers" ["DNS server(s)"]="domain-name-servers" ["Domain name"]="domain-name" ["Broadcast address"]="broadcast-address" ["Static route(s)"]="static-routes" ["NTP server(s)"]="ntp-servers" ["TFTP server(s)"]="tftp-server-name" ["Boot file name"]="bootfile-name")

#Non-menu functions go here
serviceRestart() {
    cat "$SCOPE_DIR/s*" > "$DHCPD_CONF_FILE"
    #service
}

ipAddition() {
    range_start_octet_2="${rangeStart#*.}" && range_start_octet_2="${range_start_octet_2%.*.*}" #Remove 1st, 3rd, and 4th octets
    range_start_octet_3="${rangeStart#*.*.}" && range_start_octet_3="${range_start_octet_3%.*}" #Remove 1st, 2nd, and 4th octets
    rangeStart="${rangeStart%.*}.$(( ${rangeStart#*.*.*.} + 1 ))" #Remove 4th octet and then add 4th octet back while adding 1 to it
    [[ ${rangeStart#*.*.*.} -ge 256 ]] && \
        rangeStart="${rangeStart%.*.*}.$(( range_start_octet_3 + 1 )).0" #Set 4th octet to 0, then add 1 to 3rd octet, if 4th octet is greater than 255
    [[ $range_start_octet_3 -ge 256 ]] && \
        rangeStart="${rangeStart%.*.*.*}.$(( range_start_octet_2 + 1 )).0.${rangeStart#*.*.*.}" #Set 3rd octet to 0, then add 1 to 2nd octet, if 3rd octet is greater than 255
    [[ $range_start_octet_2 -ge 256 ]] && \
        rangeStart="$(( ${rangeStart%.*.*.*} + 1 )).0.${rangeStart#*.*.}" #Set 2nd octet to 0, then add 1 to 1st octet, if 2nd octet is greater than 255
    [[ ${rangeStart%.*.*.*} -ge 256 ]] && \
        rangeStart="255.${rangeStart#*.}" #Set 1st octet to 255 if 1st octet is greater than 255. Probably not needed at all
}

ipSubtraction() {
    range_end_octet_2="${range_end#*.}" && range_end_octet_2="${range_end_octet_2%.*.*}" #Remove 1st, 3rd, and 4th octets
    range_end_octet_3="${range_end#*.*.}" && range_end_octet_3="${range_end_octet_3%.*}" #Remove 1st, 2nd, and 4th octets
    range_end="${range_end%.*}.$(( ${range_end#*.*.*.} - 1 ))" #Remove 4th octet then add it back while adding 1 to it
    [[ ${range_end#*.*.*.} -le -1 ]] && \
        range_end="${range_end%.*.*}.$(( range_end_octet_3 - 1 )).255" #Set 4th octet to 255, then subtract 3rd octet by 1, if 4th octet is less than 0
    [[ $range_end_octet_3 -le -1 ]] && \
        range_end="${range_end%.*.*.*}.$(( range_end_octet_2 - 1 )).255.${range_end#*.*.*.}" #Set 3rd octet to 255 then subtract 2nd octet by 1, if 3rd octet is less than zero
    [[ $range_end_octet_2 -le -1 ]] && \
        range_end="$(( ${range_end%.*.*.*} - 1 )).255.${range_end#*.*.}" #Set 2nd octet to 255, then subtract 1st octet by 1, if 2nd octet is less than 0
    [[ ${range_end%.*.*.*} -le -1 ]] && \
        range_end="0.${range_end#*.}" #Set 1st octet to 0, if 1st octet is less than 0. Probably not needed at all
}

scopeGenerate() {
    ! grep -q "X:" "$exclusionsFile" || ! grep -q "Z:" "$exclusionsFile" && return 1 #Do not generate exclusion file if no scope range has been set

    sort -t . -k 1,1n -k 2,2n -k 3,3n -k 4,4n -o "$exclusionsFile" "$exclusionsFile" #Sort IP addresses and output to current exclusions file
    sed -i "/X/,/Z/!d" "$exclusionsFile" #Remove all IP addresses outside the scope range
    while IFS= read -r IP; do; do #Loop through contents of exclusions file
        case ${IP:2} in
        "X:")
            sed -i "/range/d" "$currentScope" #Delete every line that has range
            rangeStart=${IP:2} #Set starting range to value of X:
        ;;
        "Y:")
            [[ $rangeStart == "${IP:2}" ]] && \
                ipAddition && continue #Add 1 to range start if it is excluded from range
            range_end=${IP:2} #Set ending range to value of currently looped Y:
            ipSubtraction #Subtract IP by 1 to not include excluded IP
            sed -i "/}/s_.*_range $rangeStart $range_end;\\n}_" "$currentScope" #Replace } with correct range string
            rangeStart=${IP:2} #Set starting range to value of currently looped Y:
            ipAddition #Add 1 to IP to not include excluded IP
        ;;
        "Z:")
            unset range_start_no_dot #Reset variable to avoid adding more to range_start_no_dot variable
            for octet in ${rangeStart//./ }; do
                range_start_no_dot+="$(printf "%03d" "$octet")" #Add currently looped octet while padding it with zeros
            done
            range_end=${IP:2} #Set ending range to value of Z:
            unset range_end_no_dot #Reset variable to avoid adding more to range_end_no_dot variable
            for octet in ${range_end//./ }; do
                range_end_no_dot+="$(printf "%03d" "$octet")" #Add currently looped octet while padding it with zeros
            done
            [[ $range_start_no_dot -le $range_end_no_dot ]] && \
                sed -i "/}/s_.*_range $rangeStart $range_end;\\n}_" "$currentScope" #Replace } with correct range string
        ;;
        esac
    done < <(grep -v '^ *#' < "$exclusionsFile")
}

#Menu functions go here - where Dialog commands will be invoked
dialog_main_menu() {
    main_menu="," #Set variable to , to be able to loop following commands until user wants to go back
    while ! [[ -z "$main_menu" ]]; do
        #Add static menu items
        #Set menu item nr to allow for dynamic menu filling
        main_menu_list=("1" "About" "2" "License" "3" "Add server")
        main_menu_number=3
        #Set server configuration file variable to extract server configuration
        #Get server role from conf file
        #Get server name from conf file
        #Get server address from conf file
        pushd "${SERVER_DIR}"
        for server in *; do
            server_conf_file="${SERVER_DIR}/${server}/server.conf"
            . "${server_conf_file}"
            main_menu_number=$(( main_menu_number + 1 ))
            main_menu_list+=("${main_menu_number} ${SERVER_NAME}" "${SERVER_ROLE} ${SERVER_ADDRESS}")
        done
        popd
        exec 3>&1
        main_menu="$(dialog --cancel-label "Exit" --menu "Choose a dhcp server" 0 0 0 "${main_menu_list[@]}" 2>&1 1>&3)"
        exec 3>&-
        main_menu_result="${main_menu#* }" #Extract menu selection from menu result
        case $main_menu_result in
        "1") #About
            dialog --textbox $ABOUT 0 0 #Display information about the project
        ;;
        "2") #License
            dialog --textbox $LICENSE 0 0 #Display information about the license (GPLv3)
        ;;
        "3") #Add server
            #Infinitely loop until user sets a name for the server
            #Unset variable if name is already taken to be bale to loop
            unset new_server_name
            until ! [[ -z "$new_server_name" ]]; do
                exec 3>&1
                new_server_name="$(dialog --inputbox "Set a name for the server" 0 0 )"
                exec 3>&-
                new_server_name="${new_server_name// /_}"
                [[ -d "${SERVER_DIR}/${new_server_name}" ]] && \
                  unset new_server_name && \
                  dialog --msgbox "Server already exists!" 0 0
            done
            #Set server configuration file according to user input
            #Create server directory
            #Copy server configuration template
            server_conf_file="$SERVER_DIR/${new_server_name}/server.conf"
            mkdir "${SERVER_DIR}/${new_server_name}"
            cp "${SERVER_CONF_TEMPLATE}" "${server_conf_file}"
        ;;
        esac
        [[ -z "$main_menu" ]] || [[ "${main_menu}" == "1" || "${main_menu}" == "2" ]] && continue
        current_server="${main_menu#* }"
        leases_file="${SERVER_DIR}/${current_server}/dhcpd.leases"
        dhcpd_conf_file="${SERVER_DIR}/${current_server}/dhcpd.conf"
        scope_dir="${SERVER_DIR}/${current_server}/dhcp_scopes"
        exclusions_dir="${SERVER_DIR}/${current_server}/exclusions"
        . "${SERVER_DIR}/${current_server}/server.env"
        subnet="${current_scope%s_*}"
        netmask="${current_scope#*_n}"
        exclusions_file="${subnet}s_n${netmask}"
        dialog_scope_menu
    done
}

#Visualization
#1  Change current scope
#2  Create new scope
#3  Delete current scope
#4  Set server configuration
#5  Subnet mask
#6  Routers
#7  DNS
#8  Domain name
#9  Broadcast address
#10 Static routes
#11 NTP servers
#12 TFTP server name
#13 Bootfile name
#14
#15
#16
#17
#18
dialog_scope_menu() {
    #Set scope menu variable to be able to loop
    #Convert CIDR notation to netmask
    #Create exclusions file if it does not exist
    cidr_notation="${netmask}"
    ! [[ -f "${exclusions_file}" ]] && touch "${exclusions_file}"
    scope_menu=","
    while ! [[ -z "$scope_menu" ]]; do
        #Add static menu items
        scope_menu_items=("1" "Change current scope" "2" "Create new scope" "3" "Delete current scope" "4" "Set server configurations")
        x_line="$(grep "X:" "$exclusions_file")"
        z_line="$(grep "Z:" "$exclusions_file")"
        if ! [[ -z "${x_line:2}" || -z "${z_line:2}" ]]; then
            menuItems+=("5 Change scope range" "${x_line:2}-${z_line:2}")
            menuItems+=("6 Manage excluded IPs" ".")
            menuItems+=("7 View dhcp leases" ".")
            scope_menu_number=7
        else
            menuItems+=("5 Set scope range" ".")
            scope_menu_number=5
        fi
        #Go through available options and add them to menu
        current_scope_file="$server_dir/$current_server/dhcp_scopes/$current_scope"
        for option in "${options_list[@]}"; do
            option_list_string="$(grep "$option" "$current_scope_file")"
            option_list_name="${optionKeytoName[${option_list_string% *}]}"
            option_list_value="${option_list_string#* }"
            [[ -z "$option_list_name" ]] && option_list_name="$option"
            [[ -z "$option_list_value" ]] && option_list_value="Not set"
            scope_menu_number=$(( scope_menu_number + 1 ))
            scope_menu_items+=("${scope_menu_number} ${option_list_name}" "${option_list_value}")
        done
        exec 3>&1
        scope_menu="$(dialog --cancel-label "Back" --menu "Current scope: ${current_scope}\\nCurrent server: ${current_server}" 0 0 0 "${scope_menu_items[@]}" 2>&1 1>&3)"
        exec 3>&-
        #Get option name from selected item
        #Convert option name to key
        #Set option mode to empty as default
        option_name="${scope_menu#* }"
        option_code="${optionNametoKey[$option_name]}"
        option_mode=""
        case ${scope_menu#* } in
        "Change current scope")
            #Tell user to ask scope first if no scope has been set
            #Reset variable
            #Loop through files in scope dir
            #Add scope file to menu list array
            [[ -z "$(dir $scope_folder)" ]] && \
                dialog --msgbox "Add a scope first." 0 0 && continue
            unset available_scopes
            cd "$scope_folder"
            for scope in *; do
                available_scopes+=("$scope" ".")
            done
            exec 3>&1
            choose_scope_menu="$(dialog --cancel-label "Back" --menu "Choose a scope to change to" 0 0 0 "${available_scopes[@]}" 2>&1 1>&3)"
            exec 3>&-
            #Reset loop if user exits
            #Set subnet variable according to selected scope
            #Set netmask variable according to selected scope
            #Reset loop to avoid running commands after case statement
            [[ -z "$choose_scope_menu" ]] && continue
            subnet=${choose_scope_menu%s_*}
            netmask=${choose_scope_menu#*_n}
            continue
        ;;
        "Create new scope")
            #Tell user to input subnet information
            #Reset loop if no scope has been added
            #Set subnet variable according to user input
            #Set netmask variable according to user input
            exec 3>&1
            networkResult="$(dialog --cancel-label "Back" --inputbox "Create a scope. Example: 192.168.1.0/24" 0 0 2>&1 1>&3)"
            exec 3>&-

            [[ -z "$networkResult" ]] && continue
            subnet=${networkResult%/*}
            netmask=${networkResult#*/}
            dialog_edit_menu
        ;;
        "Delete current scope")
            #Reset loop if there are no scopes
            [[ -z "$(dir $scope_folder)" ]] && dialog --msgbox "There are no dhcp scopes." 0 0 && continue

            #Reset variable
            #Change dir to scope_folder then loop through files
            unset scope_files
            pushd "$scope_folder"
            for file in *; do
                scope_files+=("$file" "." "off")
            done
            popd
            exec 3>&1
            scope_delete="$(dialog --checklist "Delete scope(s) - Press space to select." 0 0 0 "${scope_files[@]}" 2>&1 1>&3)"
            exec 3>&-

            #Reset loop if no scope has been selected
            #Ask user to confirm
            #Set confirmation variable to exit status
            [[ -z "$scope_delete" ]] && continue
            exec 3>&1
            scope_delete_yes_no=$(dialog --yesno "Are you sure you want to delete these scopes?: $scope_delete" 0 0 2>&1 1>&3)
            scope_delete_yes_no=$?
            exec 3>&-

            #Reset loop if user cancels deletion
            #Loop through selected scopes and delete selected files
            #Restart service to set changes, then reset loop to avoid running other commands
            if [[ "$scope_delete_yes_no" ]]; then
                for file in $scopeDelete; do
                    rm "$scope_folder/$file"
                    rm "$exclusionsFolder/$file"
                done
                serviceRestart
            fi
            continue
        ;;
        "Set server configurations")
            #Run server configuration menu then restart loop
            dialog_server_configuration_menu
            continue
        ;;
        "Router(s)"|"DNS server(s)"|"Static route(s)"|"NTP server(s)")
            option_mode="multi" #Set option mode to multi
        ;;
        "Domain name"|"TFTP server name"|"Bootfile name")
            option_mode="quotes" #Set option mode to quotes
        ;;
        "View dhcp leases")
            #Reset associative array
            #Loop through variable that has contents of leases
            #If current lease is not the latest, then do not add to active leases
            #Remove line nr and whitespace from the beginning. Variable should look like: lease x.x.x.x
            unset lease_ip_infos
            declare -A lease_ip_infos
            dhcp_leases=$(grep -n "lease.*{" $leases_file)
            for lease in ${dhcp_leases// /_}; do
                ! [[ "${lease//_/ }" == "$(grep -n "${lease//_/ }" "$leases_file" | tail -n 1)" ]] && continue
                lease_ip="${lease% *}"
                lease_ip="${lease_ip#*: }"
                starting_line=${lease#:*}
                ending_line=$(( starting_line + 1 ))
                until [[ "$(sed -n "${ending_line}p" "$leases_file")" == "}" ]]; do
                    ending_line=$(( ending_line + 1 ))
                done
                for active_lease in $(grep -n "binding state active" "$leases_file"); do
                    ! [[ ${active_lease%:*} -gt $starting_line && ${active_lease%:*} -lt $ending_line ]] && continue
                    lease_ip_infos+=(["$lease_ip"]="${starting_line}:${ending_line}")
                    lease_menu_items+=("$lease_ip" ".")
                done
            done
            exec 3>&1
            lease_menu="$(dialog --menu "View active leases" 0 0 0 "${lease_menu_items[@]}" 2>&1 1>&3)"
            exec 3>&-
            lease_line_numbers="${lease_ip_infos[$lease_menu]}"
            starting_line="${lease_line_numbers%:*}"
            ending_line="${lease_line_numbers#*:}"
            dialog --msgbox "$(sed -n "${starting_line},${ending_line}p" $leases_file)" 0 0
            continue
        ;;
        "Manage excluded IPs")
            exec 3>&1
            excludeOrView=$(dialog --menu "Manage exclusion list" 0 0 0 "1" "Exclude an IP" "2" "View or edit the list" 2>&1 1>&3)
            exec 3>&-
            if [[ "$excludeOrView" == "1" ]]; then
                exec 3>&1
                excluding="$(dialog --inputbox "Which IP do you want to exclude?" 0 0 2>&1 1>&3)"
                exec 3>&-
                grep -q "$excluding" "$exclusionsFile" && \
                    dialog --msgbox "That IP is already excluded!" 0 0 && continue
                echo "Y:$excluding" >> "$exclusionsFile"
            else
                ! grep -q "Y:" "$exclusionsFile" && continue
                unset exclusion_list
                for IP in $(grep "Y:" "$exclusionsFile"); do
                    exclusion_list+=("${IP:2}" "." "off")
                done
                exec 3>&1
                remove_ip_list="$(dialog --checklist "View or remove IPs from exclusion" 0 0 0 "${exclusion_list[@]}" 2>&1 1>&3)"
                exec 3>&-
                [[ -z "$remove_ip_list" ]] && continue
                exec 3>&1
                delete_ip_confirmation="$(dialog --yesno "Are you sure you want to remove these IPs from exlcusion?: $remove_ip_list" 0 0 2>&1 1>&3)"
                delete_ip_confirmation=$?
                exec 3>&-
                ! [[ $remove_ip_confirmation == "0" ]] && continue
                for ip in $remove_ip_list; do
                    sed -i "/${ip}/d" "$exclusionsFile"
                done
            fi
            dialog_edit_menu
        ;;
        "Set scope range"|"Change scope range")
            inputbox_init="$(grep "X:" "$exclusionsFile") $(grep "Z:" "$exclusionsFile")"
            exec 3>&1
            scope_range="$(dialog --inputbox "Set the scope range. Example: 192.168.1.1 192.168.1.255. Leave empty to delete." 0 0 "$inputbox_init" 2>&1 1>&3)"
            exec 3>&-
            [[ -z "$scope_range" ]] && \
                sed -i "/X:/,/Z:/d" "$exclusionsFile" && continue
            sed -i "/X:/s_.*_X:${scope_range% *}_" "$exclusionsFile"
            sed -i "/Z:/s_.*_Z:${scope_range#* }_" "$exclusionsFile"
            dialog_edit_menu
        ;;
        esac
        scopeGenerate
        serviceRestart
    done
}

#Menu for editing server options
dialog_server_configuration_menu() {
    server_configuration_menu=","
    while ! [[ -z "$server_configuration_menu" ]]; do
        #Add server configuration menu items for server options
        . $server_conf_file
        server_role="$(grep "Role:" $server_conf_file)"
        server_conf_menu_items+=("1" "Server role: ${SERVER_ROLE}")

        server_name="$(grep "Name:" $server_conf_file)"
        server_conf_menu_items+=("2" "Server name: ${server_name/Name:}")

        server_user="$(grep "User:" $server_conf_file)"
        server_conf_menu_items+=("3" "Server user: ${server_user/User:}")

        server_address="$(grep "Address:" $server_conf_file)"
        server_conf_menu_items+=("4" "IP address: ${server_address/Address:}")

        server_default_scope="$(grep "Default scope:" $server_conf_file)"
        server_default_scope="${server_default_scope/Default scope:}"
        [[ -z "$sever_default_scope" ]] && server_default_scope="Not set"
        server_conf_menu_items+=("5" "Default scope: $server_default_scope")

        server_key="$(grep "Key:" $server_conf_file)"
        server_conf_menu_items+=("6" "SSH key: ${server_key/Key:}")

        server_conf_menu_items+=("7" "Upload public ssh key")

        exec 3>&1
        server_configuration_menu="$(dialog --cancel-label "Back" --menu "Change server configuration" 0 0 0 $server_conf_menu_items 2>&1 1>&3)"
        exec 3>&-
        case $server_configuration_menu in
        1)
            exec 3>&1
            server_configuration_input="$(dialog --yes-label "Master" --no-label "Slave" --yesno "Set role for $server_name:" 0 0 2>&1 1>&3)" #Yes no dialog to force user to set a role
            server_configuration_input="$?"
            exec 3>&-
            [[ "$server_configuration_input" ]] && \
                sed -i "/Role/s_.*_Role:master_" "$server_conf_file" && \
                continue
            sed -i "/Role/s_.*_Role:slave_" "$server_conf_file"
        ;;
        2)
            exec 3>&1
            server_change_name="$(dialog --inputbox "Set name for $server_name:" 0 0 $server_name 2>&1 1>&3)"
            exec 3>&-
            ! [[ -z "$server_change_name" ]] && sed -i "/Name:/s_${server_name}_${server_change_name}_"
        ;;
        3)
            exec 3>&1
            server_change_user="$(dialog --inputbox "Set user for $server_name:" 0 0 $server_user 2>&1 1>&3)"
            exec 3>&-
            ! [[ -z "$server_change_user" ]] && sed -i "/User:/s_${server_user}_${server_change_user}_"
        ;;
        4)
            exec 3>&1
            server_change_address="$(dialog --inputbox "Set address for $server_name:" 0 0 $server_address 2>&1 1>&3)"
            exec 3>&-
            ! [[ -z "$server_change_address" ]] && sed -i "/Address:/s_${server_address}_${server_change_address}_"
        ;;
        5)
            exec 3>&1
            server_change_default_scope="$(dialog --inputbox "Set default scope for $server_name:" 0 0 $server_user 2>&1 1>&3)"
            exec 3>&-
            ! [[ -z "$server_change_default_scope" ]] && sed -i "/Default scope:/s_${server_default_scope}_${server_change_default_scope}_"
        ;;
        6)
            exec 3>&1
            server_change_key="$(dialog --inputbox "Set SSH key location for $server_name:" 0 0 $server_key 2>&1 1>&3)"
            exec 3>&-
            ! [[ -z "$server_change_key" ]] && sed -i "/Key:/s_${server_key}_${server_change_key}_"
        ;;
        7)
            ! [[ -f "$server_dir/$current_server/.ppk" ]] && touch "$server_dir/$current_server/.ppk"
            exec 3>&1
            server_upload_key="$(dialog --editbox "$server_dir/$current_server/.ppk"  0 0 2>&1 1>&3)"
            exec 3>&-
            ! [[ -z "$server_upload_key" ]] && echo "Insert upload key here"
        ;;
        esac
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
