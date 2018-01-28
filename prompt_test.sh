#!/bin/bash

function quitting() {
    # also executes on ctrl-c
    # quits with status 0 because it was user-initiated
    echo $NORM  # restore default font
    echo "Quitting."
    IFS=$oIFS   # restore IFS
    tput cnorm  # restore cursor
    exit 0
}

trap quitting SIGINT

shopt -s expand_aliases

alias grep='grep --color=always -n -E'
export GREP_COLORS='ms=04;31:mc=33:sl=:cx=:fn=01;37:ln=32:bn=35:se=36'

# define some colors
NORM=`tput sgr0`
RED=`tput setaf 1`

function live_regex () {
    local BACKSPACE=`tput kbs`

    tput civis  # hide the cursor

    local text=`cat text`

    # use 'read' in a loop to fake interactive editor behavior
    local input
    local regex

    while true; do
        clear

        regex="$prompt"
        output=$(echo "$text" | egrep --color=always -n -e '$' -e "$regex" 2> /dev/null)
 
        if (( $? == 2 )); then
            echo "$old_output"
        else
            echo "$output"
            old_output="$output"
        fi

        echo
    
        #TODO use '-s' on read, but breaks terminal if ctrl-c'd
        read -rn 1 -p "Enter regex: grep /${RED}${prompt}${NORM}/" input

        case $input in
            "")
                # enter was probably pressed
                # accept the regex
                break ;;
            $BACKSPACE)
                # handle backspace
                prompt=${prompt%?} ;;
            # anything else is added to the regex
            # matching printable characters doesn't save us from arrow keys
            [[:print:]])
                prompt+="$input" ;;
        esac

        # overwrite the prompt
        tput dl1    # delete the current line
        tput hpa 0  # move cursor to the beginning of line
    done

    tput cnorm  # un-hide cursor
}

live_regex
