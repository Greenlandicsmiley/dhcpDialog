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

declare -A optionKeytoName #Associative array to easily convert pretty names to config names
optionKeytoName=(["subnet-mask"]="Subnet mask" ["routers"]="Router(s)" ["domain-name-servers"]="DNS server(s)" ["domain-name"]="Domain name" ["broadcast-address"]="Broadcast address" ["static-routes"]="Static route(s)" ["ntp-servers"]="NTP server(s)" ["tftp-server-name"]="TFTP server(s)" ["bootfile-name"]="Boot file name")
declare -A optionNametoKey #Associative array to easily convert config names to pretty names
optionNametoKey=(["Subnet mask"]="subnet-mask" ["Router(s)"]="routers" ["DNS server(s)"]="domain-name-servers" ["Domain name"]="domain-name" ["Broadcast address"]="broadcast-address" ["Static route(s)"]="static-routes" ["NTP server(s)"]="ntp-servers" ["TFTP server(s)"]="tftp-server-name" ["Boot file name"]="bootfile-name")

#Non-menu functions go here
serviceRestart() {
    cat $scope_folder/s* > $dhcpd_conf_file
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
        unset main_menu_list #Reset variable to avoid adding more to main_menu_list array
        main_menu_list+=("1" "About" "2" "License" "3" "Add server") #Add static menu items
        server_menu_number=4 #Set menu item nr to allow for dynamic menu filling
        for server in $(dir $server_folder); do
            server_conf_file="$server_folder/$server/server.conf" #Set server configuration file according to user selection
            server_role="$(grep "Role:" "$server_conf_file")" #Extract role value from conf file
            server_name="$(grep "Name:" "$server_conf_file")" #Extract name value from conf file
            server_address="$(grep "Address:" "$server_conf_file")" #Extract address value from conf file
            main_menu_list+=("${server_menu_number} ${server_name}" "${server_role} ${server_address}") #Add menu item according to conf file
            server_menu_number=$(( server_menu_number + 1 )) #Add menu item nr for next menu item
        done
        exec 3>&1
        main_menu=$(dialog --cancel-label "Exit" --menu "Choose a dhcp server" 0 0 0 "${main_menu_list[@]}" 2>&1 1>&3)
        exec 3>&-
        main_menu_result=${main_menu# *} #Extract menu selection from menu result
        case $main_menu_result in
        1)
            dialog --textbox $ABOUT 0 0 #Display about information
            continue
        ;;
        2)
            dialog --textbox $LICENSE 0 0 #Display license information
            continue
        ;;
        3)
            unset new_server_name #Infinitely loop until user sets a name for the server
            until ! [[ -z "$new_server_name" ]]; do
                exec 3>&1
                new_server_name="$(dialog --inputbox "Set a name of the server" 0 0 )"
                exec 3>&-
                [[ -d "$new_server_name" ]] && unset new_server_name && dialog --msgbox "Server already exists!" 0 0 #Unset variable to loop again until user chooses a server name that has not been chosen yet
            done
            server_conf_file="$server_folder/${new_server_name// /_}/server.conf" #Set server configuration file according to user input
            mkdir "$server_folder/${new_server_name// /_}" #Create server directory
            cp "$server_conf_template" "$server_conf_file" #Copy server configuration template
        ;;
        esac
        [[ -z "$main_menu" ]] && continue #Reset loop if user input for main menu is empty to avoid running commands below
        current_server="${main_menu#* }" #Extract selected server from user selection
        leases_file="$srv_folder/${current_server}/dhcpd.leases" #Set leases file variable according to user selection
        dhcpd_conf_file="$srv_folder/${current_server}/dhcpd.conf" #Set conf file variable according to user selection
        scope_folder="$srv_folder/${current_server}/dhcpScopes" #Set scope folder variable according to user selection
        exclusionsFolder="$srv_folder/${current_server}/exclusions" #Set exclusions folder variable according to user selection
        current_scope="$(grep "Default Scope:" "$server_folder/$current_server/server.conf")" #Set current scope to user selection
        current_scope="${current_scope#*:}" #Remove everything before and including : to get the correct scope value
        dialog_scope_menu #Switch to scope menu for current scope
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
    scope_menu="," #Set variable to comma to be able to loop while loop
    cidr_notation="${netmask}" #Convert CIDR notation to netmask
    ! [[ -z "$1" ]] && printf "%s" "subnet $subnet netmask $netmask{\\n}" > "$currentScope" && \
        touch "$exclusionsFolder/${subnet}s_n${netmask}" #Create exclusions file if it does not exist
    while ! [[ -z "$scope_menu" ]]; do
        scope_menu_items+=("1" "Change current scope" "2" "Create new scope" "3" "Delete current scope" "4" "Set server configurations") #Add static menu items
        x_line="$(grep "X:" "$exclusionsFile")" #Get line nr of X: to later get value
        z_line="$(grep "Z:" "$exclusionsFile")" #Get line nr of Y: to later get value
        scope_menu_number=4 #Set scope menu nr to 4 as default
        if ! [[ -z "${x_line:2}" || -z "${z_line:2}" ]]; then #Check if X or Y line exist. Assuming both exist if one does
            menuItems+=("5 Change scope range" "${x_line:2}-${z_line:2}") #Add static menu item with correct values for currently selected subnet
            menuItems+=("6 Manage excluded IPs" ".") #Add static menu item for managing excluded IPs
            menuItems+=("7 View dhcp leases" ".") #Add static menu item for viewing dhcp leases
            scope_menu_number=7 #Set scope menu nr to 7 so dynamically added menu items get the correct menu nr
        else
            menuItems+=("5 Set scope range" ".") #Add set scope range if no scope range has been set
            scope_menu_number=5 #Set scope menu nr to 5 so dynamically added menu items get the correct menu nr
        fi
        current_scope_file="$server_folder/$current_server/dhcp_scopes/$current_scope" #Set current scope file to the correct file for later file manipulation
        for option in "${options_list[@]}"; do
            option_list_string="$(grep "$option" "$current_scope_file")" #Get whole string of line of the currently looped option
            option_list_name="${optionKeytoName[${option_list_string% *}]}" #Extract option name from the string
            [[ -z "$option_list_name" ]] && option_list_name="$option" #Set option name to loop variable if option does not exist
            option_list_value="${option_list_string#* }" #Extract value from the string
            [[ -z "$option_list_value" ]] && option_list_value="Not set" #If value not selected set to not set
            scope_menu_number=$(( scope_menu_number + 1 )) #Addition to the scope menu nr
            scope_menu_items+=("${scope_menu_number} ${option_list_name}" "${option_list_value}") #Add menu item dynamically according to extracted information from string
        done
        exec 3>&1
        scope_menu=$(dialog --cancel-label "Back" --menu "Current scope: ${current_scope}\\nCurrent server: ${current_server}" 0 0 0 "${scope_menu_items[@]}" 2>&1 1>&3)
        exec 3>&-
        option_name="${scope_menu#* }" #Get option name from selected item
        option_code="${optionNametoKey[$option_name]}" #Convert option name to key
        option_mode="" #Set option mode to empty as default
        case ${scope_menu#* } in
        "Change current scope")
            [[ -z "$(dir $scope_folder)" ]] && \
                dialog --msgbox "Add a scope first." 0 0 && continue #Tell user to ask scope first if no scope has been set
            unset available_scopes #Reset variable
            cd "$scope_folder"
            for scope in *; do #Loop through files in scope dir
                available_scopes+=("$scope" ".") #Add scope file to menu list array
            done
            exec 3>&1
            choose_scope_menu=$(dialog --cancel-label "Back" --menu "Choose a scope to change to" 0 0 0 "${available_scopes[@]}" 2>&1 1>&3)
            exec 3>&-
            [[ -z "$choose_scope_menu" ]] && continue #Reset loop if user exits

            subnet=${choose_scope_menu%s_*} #Set subnet variable according to selected scope
            netmask=${choose_scope_menu#*_n} #Set netmask variable according to selected scope
            continue #Reset loop to avoid running commands after case statement
        ;;
        "Create new scope")
            exec 3>&1
            networkResult=$(dialog --cancel-label "Back" --inputbox "Create a scope. Example: 192.168.1.0/24" 0 0 2>&1 1>&3) #Tell user to input subnet information
            exec 3>&-
            [[ -z "$networkResult" ]] && continue #Reset loop if no scope has been added
            subnet=${networkResult%/*} #Set subnet variable according to user input
            netmask=${networkResult#*/} #Set netmask variable according to user input
            dialog_edit_menu
        ;;
        "Delete current scope")
            [[ -z "$(dir $scope_folder)" ]] && dialog --msgbox "There are no dhcp scopes." 0 0 && continue #Reset loop if there are no scopes

            unset scopeFiles #Reset variable
            for file in $(dir $scope_folder); do
                scopeFiles+=("$file" "." "off")
            done
            exec 3>&1
            scopeDelete="$(dialog --checklist "Delete scope(s) - Press space to select." 0 0 0 "${scopeFiles[@]}" 2>&1 1>&3)"
            exec 3>&-

            [[ -z "$scopeDelete" ]] && continue #Reset loop if no scope has been selected
            exec 3>&1
            scopeDeleteYN=$(dialog --yesno "Are you sure you want to delete these scopes?: $scopeDelete" 0 0 2>&1 1>&3) #Ask user to confirm
            scopeDeleteYN=$? #Set confirmation variable to exit status
            exec 3>&-

            ! [[ $scopeDeleteYN == "0" ]] && continue #Reset loop if user cancels deletion
            for file in $scopeDelete; do #Loop through selected scopes
                rm "$scope_folder/$file" #Delete scope file
                rm "$exclusionsFolder/$file" #Delete scope exclusions file
            done
            serviceRestart #Restart service to set changes
            continue #Reset loop to avoid running other commands
        ;;
        "Set server configurations")
            dialog_server_configuration_menu #Run server configuration menu
            continue #Reset loop to avoid running other commands
        ;;
        "Router(s)"|"DNS server(s)"|"Static route(s)"|"NTP server(s)")
            option_mode="multi" #Set option mode to multi
        ;;
        "Domain name"|"TFTP server name"|"Bootfile name")
            option_mode="quotes" #Set option mode to quotes
        ;;
        "View dhcp leases")
            unset lease_ip_infos #Reset associative array
            declare -A lease_ip_infos
            dhcp_leases=$(grep -n "lease.*{" $leases_file) #Get all lease lines
            for lease in ${dhcp_leases// /_}; do #Loop through variable that has contents of leases
                ! [[ "${lease//_/ }" == "$(grep -n "${lease//_/ }" "$leases_file" | tail -n 1)" ]] && continue #If current lease is not the latest, then do not add to active leases
                lease_ip="${lease% *}" #Remove { and whitespace from the end
                lease_ip="${lease_ip#*: }" #Remove line nr and whitespace from the beginning. At this point variable should look like: lease x.x.x.x
                starting_line=${lease#:*} #Get line nr of lease
                ending_line=$(( starting_line + 1 )) #Set ending line nr of the lease
                until [[ "$(sed -n "${ending_line}p" "$leases_file")" == "}" ]]; do #Add 1 to ending line variable until the line is the end of the lease
                    ending_line=$(( ending_line + 1 )) #Add to ending line variable by 1
                done
                for active_lease in $(grep -n "binding state active" "$leases_file"); do #Get all lines that has binding state active and loop through the list
                    ! [[ ${active_lease%:*} -gt $starting_line && ${active_lease%:*} -lt $ending_line ]] && continue #Reset loop if current line is not between the starting line and the ending line of the current lease being looped through
                    lease_ip_infos+=(["$lease_ip"]="${starting_line}:${ending_line}") #Add lease information to associative array for easier information extraction
                    lease_menu_items+=("$lease_ip" ".") #Dynamically add lease ip to menu item list
                done
            done
            exec 3>&1
            lease_menu=$(dialog --menu "View active leases" 0 0 0 "${lease_menu_items[@]}" 2>&1 1>&3)
            exec 3>&-
            lease_line_numbers="${lease_ip_infos[$lease_menu]}" #Extract line information from IP into a variable
            starting_line="${lease_line_numbers%:*}" #Get starting line of lease
            ending_line="${lease_line_numbers#*:}" #Get ending line of lease
            dialog --msgbox "$(sed -n "${starting_line},${ending_line}p" $leases_file)" 0 0 #Display lease information
            continue
        ;;
        "Manage excluded IPs")
            exec 3>&1
            excludeOrView=$(dialog --menu "Manage exclusion list" 0 0 0 "1" "Exclude an IP" "2" "View or edit the list" 2>&1 1>&3)
            exec 3>&-
            if [[ "$excludeOrView" == "1" ]]; then #Check if user chose excluding an IP
                exec 3>&1
                excluding=$(dialog --inputbox "Which IP do you want to exclude?" 0 0 2>&1 1>&3)
                exec 3>&-
                grep -q "$excluding" "$exclusionsFile" && \
                    dialog --msgbox "That IP is already excluded!" 0 0 && continue #Reset loop if IP was already excluded
                echo "Y:$excluding" >> "$exclusionsFile" #Exclude IP if it is not excluded already
            else
                ! grep -q "Y:" "$exclusionsFile" && continue #Reset loop if no IP has been excluded yet
                unset exclusionList
                for IP in $(grep "Y:" "$exclusionsFile"); do #Loop through all excluded IPs
                    exclusionList+=("${IP:2}" "." "off") #Add IP to checklist while removing Y:
                done
                exec 3>&1
                remove_ip_list=$(dialog --checklist "View or remove IPs from exclusion" 0 0 0 "${exclusionList[@]}" 2>&1 1>&3)
                exec 3>&-
                [[ -z "$remove_ip_list" ]] && continue #Reset loop if user cancels
                exec 3>&1
                delete_ip_confirmation=$(dialog --yesno "Are you sure you want to remove these IPs from exlcusion?: $removeIPList" 0 0 2>&1 1>&3) #Confirm with user if the IPs they chose to delete should be deleted
                delete_ip_confirmation=$? #Get result of confirmation
                exec 3>&-
                ! [[ $remove_ip_confirmation == "0" ]] && continue #Reset loop if user cancels
                for ip in $remove_ip_list; do #Loop through IPs chosen to be deleted and
                    sed -i "/${ip}/d" "$exclusionsFile" #Delete excluded IP from exclusion list
                done
            fi
            dialog_edit_menu
        ;;
        "Set scope range"|"Change scope range")
            inputbox_init="$(grep "X:" "$exclusionsFile") $(grep "Z:" "$exclusionsFile")" #Get scope range of current scope for initial input box value
            exec 3>&1
            scope_range=$(dialog --inputbox "Set the scope range. Example: 192.168.1.1 192.168.1.255. Leave empty to delete." 0 0 "$inputbox_init" 2>&1 1>&3)
            exec 3>&-
            [[ -z "$scope_range" ]] && \
                sed -i "/X:/,/Z:/d" "$exclusionsFile" && continue #Delete scope range if input box is left empty
            sed -i "/X:/s_.*_X:${scope_range% *}_" "$exclusionsFile"
            sed -i "/Z:/s_.*_Z:${scope_range#* }_" "$exclusionsFile" #Replace range with new values
            dialog_edit_menu
        ;;
        esac
        scopeGenerate
        serviceRestart
    done
}

dialog_server_configuration_menu() {
    while ! [[ -z "$server_configuration_menu" ]]; do
        server_role=""
        server_name=""
        server_user=""
        server_address=""
        server_default_scope=""
        server_key=""
        exec 3>&1
        server_configuration_menu=$(dialog --cancel-label "Back" --menu "Change server configuration" 0 0 0 \
            "1" "Server role: $server_role - " \
            "2" "Server name: $server_name" \
            "3" "Server user: $server_user" \
            "4" "IP address: $server_address" \
            "5" "Default scope: $server_default_scope" \
            "6" "SSH key: $server_key" 2>&1 1>&3)
        exec 3>&-
        case $server_configuration_menu in
        1)
            exec 3>&1
            server_configuration_input="$(dialog --yes-label "Master" --no-label "Slave" --yesno "Set value for server role:" 0 0 2>&1 1>&3)" #Yes no dialog to force user to set a role. Might want to change to a toggle
            server_configuration_input=$?
            exec 3>&-
            [[ $server_configuration_input ]] && \
                sed -i "/Role/s_.*_Role:master_" $server_conf_file && \
                continue
            sed -i "/Role/s_.*_Role:slave_" $server_conf_file
        ;;
        2)
        ;;
        3)
        ;;
        4)
        ;;
        5)
        ;;
        6)
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
