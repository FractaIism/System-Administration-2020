#!/usr/bin/awk -f

BEGIN {
    for(i=1;i<=5;++i){
        Top[i] = -1
    }
    wcpu[-1] = -1 
}

# { print $0 }

NR >= 10 {
    i = NR - 9  # start index from 1
    
    # keep all records, sort only indexes
    pid[i]  = $1
    user[i] = $2 
    res[i]  = $7
    wcpu[i] = $11   # $10 for local VM, $11 for CS workstation
    cmd[i]  = $12   # $11 for local VM, $12 for CS workstation
    sub(/%/, "", wcpu[i])   # remove % from wcpu
    wcpu[i] = wcpu[i] + 0   # awk variables determine type from the last assignment, so we add zero to let it be interpreted as a numeric value

    # insertion sort on array of indexes Top according to wcpu
    rank=999
    for(j=5;j>=1;--j) {
        if( wcpu[i] > wcpu[Top[j]] ) {
            rank = j
        }
    }
    for(j=5;j>=1&&j>=rank;--j) {
        Top[j+1] = Top[j]
    }
    Top[rank] = i
}

END {
    # get list of bad users
    for(i=1;i<=5;++i) {
        badness[user[Top[i]]]++  # count how many times each user has appeared on WCPU list
    }
    for(i=1;i<=5;++i) {
        badness[user[i]]++  # count how many times each user has appeared on RES list
    }
    
    # print results
    print "Top Five Processes of WCPU over 0.5\n"
    printf "%-6s %-15s %-10s %s\n", "PID", "command", "user", "WCPU"
    for(i=1;i<=5;++i) {
        if(wcpu[Top[i]] > 0.5) {
            printf "%-6s %-15s %-10s %.2f%%\n", pid[Top[i]], cmd[Top[i]], user[Top[i]], wcpu[Top[i]]
        }
    }
    
    print "\nTop Five Processes of RES\n"
    printf "%-6s %-15s %-10s %s\n", "PID", "command", "user", "RES"
    for(i=1;i<=5;++i) {
        printf "%-6s %-15s %-10s %s\n", pid[i], cmd[i], user[i], res[i]
    }

    print "\nBad Users:\n"
    formatSpec = "\x1B[%dm%s\x1B[0m\n"
    for(name in badness) {  # iterates over array indexes
        if(name == "root") {
            printf formatSpec, 32, "root"
        } else if(badness[name] == 1) {
            printf formatSpec, 33, name
        } else if(badness[name] >= 2) {
            printf formatSpec, 31, name
        }
    }
}

