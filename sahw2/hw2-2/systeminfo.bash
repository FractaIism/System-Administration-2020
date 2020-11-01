#!/usr/local/bin/bash
# bash -v: verbose
# bash -x: print each command after expansion

shopt -s expand_aliases # non-interactive shells don't expand aliases by default, use this to enable aliasing

alias pause='read -n1'

# fingerprint generated with sha256 using string "Fractalism"
fingerprint="848e38199c280c93a1accf8184325646fa584fc4a6f5dbecf1963bcec0e48ea6"

trap 'echo "Ctrl + C pressed"; exit 2' SIGINT

main(){
    # WARNING: using 'local opt=$(...)' changes the exit code to 0
	# Note: 'local' isn't really necessary as long as you define variables before using them

    while true; do
        # Note: var=$(cmd_list) sends stdout of cmd_list to $var and exit code to $?
        # Note: 3>&1 1>&2 2>&3 3>&- reverses stdout and stderr. Since $(...) eats all of stdout, we need dialog to output to stderr so we can actually see the dialog.
        opt=$(dialog --cancel-label 'Exit' --menu 'System Info Panel' 13 30 10   1 'LOGIN RANK' 2 'PORT INFO' 3 'MOUNTPOINT INFO' 4 'SAVE SYSTEM INFO' 5 'LOAD SYSTEM INFO' 3>&1 1>&2 2>&3 3>&-)
        exit_code=$?

        if [ "${exit_code}" -eq 1 ]; then
            echo 'Exit'
            exit 0
        elif [ "${exit_code}" -eq 255 ]; then
            echo 'Esc pressed'
            exit 1
        fi

        case $opt in
            1) login_rank ;;
            2) port_info ;;
            3) mountpoint_info ;;
            4) save_system_info ;;
            5) load_system_info ;;
            *) echo "Unrecognized option" ;;
        esac
    done
}

login_rank(){
    top_logins=$( last | grep -v -E ^$\|utx.log | cut -d ' ' -f 1 | sort | uniq -c | sort -nrk1 | head -5 | awk '
        BEGIN   { printf "%-5s%-15s%-10s\n", "Rank", "Name", "Times"  }
        //      { printf "%-5u%-15s%-10d\n", NR, $2, $1  }
    ' )
    dialog --title "LOGIN RANK" --msgbox "$top_logins" 15 30
}

port_info(){
    while true; do
        # sockets: format: PID Protocol_LocalAddr
        sockets=$( sockstat | tail +2 | awk '
            $5 ~ /tcp|udp/ { printf "%d %s_%s ", $3, $5, $6 }
        ' )
        pid=$( dialog --menu "PORT INFO (PID and Port)" 30 70 23 $sockets 3>&1 1>&2 2>&3 3>&- )
        if [ "$?" -ne 0 ]; then return; fi

        ppid=$( echo $pid | xargs -I% ps -o ppid= % )

        if [ -z "$( hostname | grep '.cs.nctu.edu.tw' )" ]; then    # if not on CS workstation
            # WARNING: use sed to remove leading spaces and cut -w to condense spacing to get the fields correctly
            procinfo=$( top -b -p $pid | tail -2 | head -1 | sed 's/^[ \t]*//' | cut -w -f 2,7,8,10,11 )
        else    # if on CS workstation
            procinfo=$( top -b -p $pid | tail -2 | head -1 | sed 's/^[ \t]*//' | cut -w -f 2,7,8,11,12 )
        fi

        # command <<< "string" : send "string" as input to command (same as echo "string" | command)
        read -r -a array <<< "$procinfo"

        user=${array[0]}
        used_mem=${array[1]}    # formatted, ex: 2740K
        proc_state=${array[2]}
        wcpu=$( sed 's/..$//' <<< ${array[3]} )
        cmd=${array[4]}

        # sysctl hw.physmem ? hw.realmem ?
        total_mem=$( sysctl hw.realmem | cut -d' ' -f2 )    # unformatted, unit: bytes
        used_mem_scalar=$( sed 's/[a-zA-Z]//g' <<< "${used_mem}" )
        used_mem_unit=$( sed 's/[0-9]*//g' <<< "${used_mem}" )
        used_mem_unformatized=$( unformatize "${used_mem_scalar}" "${used_mem_unit}" ) # in bytes
        wmem=$( bc <<< "scale=1;${used_mem_unformatized}/${total_mem}" )

        dialog --title "Process Status: $pid" --msgbox "USER: ${user}\nPID: ${pid}\nPPID: ${ppid}\nSTAT: ${proc_state}\n%CPU: ${wcpu}\n%MEM: ${wmem}\nCOMMAND: ${cmd}" 15 35
    done
}

mountpoint_info(){
    while true; do
        fs_list=$( df -ahT -t nfs,zfs | tail +2 | cut -w -f 1,7 )
        fs=$( dialog --menu "MOUNTPOINT INFO" 30 70 25 ${fs_list} 3>&1 1>&2 2>&3 3>&- )
        if [ "$?" -ne 0 ]; then return; fi

        fs_info=$( df -ahT "$fs" | tail -1 | awk '
            {
                print "Filesystem: " $1
                print "Type: " $2
                print "Size: " $3
                print "Used: " $4
                print "Avail: " $5
                print "Capacity: " $6
                print "Mounted_on: " $7
            }
        ' )
        dialog --title "$fs" --msgbox "$fs_info" 15 40
    done
}

save_system_info(){
    # bash do-while loop (weird syntax)
    while
        savefile=$( dialog --title "Save to file" --inputbox "Enter the path:" 7 60 "$(pwd)/res" 3>&1 1>&2 2>&3 3>&- )
        exit_code=$?
        savepath=$( sed -E 's/[^/]*$//' <<< "$savefile" )
        if [ "$exit_code" -ne 0 ]; then
            return
        elif [ ! -d "$savepath" ]; then
            dialog --title "Directory not found" --msgbox "$savepath not found!" 7 60
        elif [ ! -w "$savepath" ]; then
            dialog --title "Permission denied" --msgbox "No write permission to $savefile!" 7 60
        else
            break
        fi
    do true; done

    # grab system info
    hostname=$( hostname )
    os_type=$( sysctl kern.ostype | cut -d ' ' -f 2- )
    kern_ver=$( sysctl kern.version | cut -d ' ' -f 2- )
    os_arch=$( sysctl hw.machine_arch | cut -d ' ' -f 2- )
    cpu_model=$( sysctl hw.model | cut -d ' ' -f 2- )
    n_cpu=$( sysctl hw.ncpu | cut -d ' ' -f 2- )
    phys_mem=$( sysctl hw.physmem | cut -d ' ' -f 2- )
    n_users=$( users | wc -w | sed 's/^\ *//')

    if false; then  # use top to get free memory
        if [ -z "$( hostname | grep '.cs.nctu.edu.tw' )" ]; then    # if not on CS workstation
            free_mem=$( top -b | grep Mem:|cut -d ' ' -f 8 ) # format: 3674M
        else    # if on CS workstation
            free_mem=$( top -b | grep Mem:|cut -d ' ' -f 10 )
        fi

        total_mem=$( sysctl hw.realmem | cut -d' ' -f2 )    # unformatted, unit: bytes
        total_mem_formatized=$( formatize $total_mem )  # formatted
        free_mem_scalar=$( sed 's/[a-zA-Z]//g' <<< "${free_mem}" )
        free_mem_unit=$( sed 's/[0-9]*//g' <<< "${free_mem}" )
        free_mem_unformatized=$( unformatize "${free_mem_scalar}" "${free_mem_unit}" ) # in byte
        wfreemem=$(( free_mem_unformatized * 100 / total_mem ))
    else    # use sysctl to get free memory
        free_mem=$( sysctl hw.usermem | cut -d ' ' -f2) # unformatted, unit: bytes
        total_mem=$( sysctl hw.realmem | cut -d ' ' -f2 )    # unformatted, unit: bytes
        total_mem_formatized=$( formatize $total_mem )  # formatted
        wfreemem=$(( free_mem * 100 / total_mem ))
    fi

    sysinfo="$( printf "%s%s%s%s%s%s%s%s%s%s%s" \
        "This system report is generated on $(date) \n" \
        "=================================================================\n" \
        "Hostname: ${hostname} \n" \
        "OS Name: ${os_type} \n" \
        "OS Release Version: ${kern_ver} \n" \
        "OS Architecture: ${os_arch} \n" \
        "Processor Model: ${cpu_model} \n" \
        "Number of Processor Cores: ${n_cpu} \n" \
        "Total Physical Memory: ${total_mem_formatized} \n" \
        "Free Memory (%): ${wfreemem} \n" \
        "Total logged in users: ${n_users} \n"
    )"

    # Note: echo produces an extra space at the end, use printf instead
    printf "%s\n" "$fingerprint" > "$savefile"
    # insert $output as string parameter because it includes a % character
    printf "%s" "$sysinfo" >> "$savefile"

    dialog --title "System Info" --msgbox "$sysinfo\n\n\nThe output file is saved to ${savefile}" 30 70
}

load_system_info(){
    while
            while
            loadfile=$( dialog --title "Load from file" --inputbox "Enter the path:" 7 60 "$(pwd)/res" 3>&1 1>&2 2>&3 3>&- )
            if [ "$?" -ne 0 ]; then
                return
            elif [ ! -e "$loadfile" ]; then
                dialog --title "File not found" --msgbox "$loadfile not found!" 7 60
            elif [ ! -r "$loadfile" ]; then
                dialog --title "Permission denied" --msgbox "No read permission to $loadfile!" 7 60
            else
                break
            fi
        do true; done

        filename=$( sed -E 's/.*\///' <<< "$loadfile" )
        content="$( cat "$loadfile" )"

        if [ "$( head -1 <<< "$content" )" = "$fingerprint" ]; then
            dialog --title "$filename" --msgbox "$( tail +2 <<< "$content" )" 30 70
            return
        else
            dialog --title "File not valid" --msgbox "The file is not generated by this program." 7 60
        fi
    do true; done
}

# convert from formatted size in KB, MB, GB to unformatted size in bytes
# $1 : size (in the units given by $2)
# $2 : unit (K, M, G)
unformatize() {
    local mult
    case $2 in
        K) mult=$((10**3)) ;;
        M) mult=$((10**6)) ;;
        G) mult=$((10**9)) ;;
        *) echo "Failed to match in function ${FUNCNAME[0]}: mult=$mult" ;;
    esac
    echo $(($1*$mult))
}

# convert from unformatted size in bytes to formatted size in KB, MB, or GB
# $1 : size in bytes
formatize() {
    local size=$1   # size in bytes
    local mag       # magnitude (K=1, M=2, G=3)
    for(( mag=0; $(bc <<< "${size}>=1000"); ++mag )) do
        size=$(echo "scale=2;${size}/1000"|bc)
    done
    case $mag in
        1) echo "${size} KB" ;;
        2) echo "${size} MB" ;;
        3) echo "${size} GB" ;;
        *) echo "Failed to match in function ${FUNCNAME[0]}: mag=$mag" ;;
    esac
}

# print variables to watch and pause
debug() {
    # clear
    printf "function debug()\n"
    n=0
    for var in "$@"; do
        n=$((n+1))
        echo "$n: $var"
    done
    read -n1
}

main "$@"
