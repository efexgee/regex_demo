#!/bin/bash

function clean_up () {
    tput cnorm
    IFS=$oIFS
    exit 0
}

trap clean_up SIGINT
oIFS=$IFS

RED=`tput setaf 1`
YELLOW=`tput setaf 3`
NORM=`tput sgr0`

function input_regex () {
    exec 3>&1 1>&2  # save STDOUT to FD3, redirect to STDERR
    
    local oIFS=$IFS
    local BACKSPACE=`tput kbs`
    
    # get flags for the grep command
    local grep_args=''
    read -p "Enter grep arguments: $YELLOW" grep_args
    echo -n $NORM
    if [[ -n $grep_args ]]; then
        # add a spacer between the flag and the /regex/
        grep_spacer=" "
    fi
    
    tput civis  # hide the cursor
    IFS=''  # disable the input field separator
    
    # use 'read' in a loop to fake interactive editor behavior
    local input
    local regex
    while true; do
        # the prompt is updating in the loop
        # technically, the user is typing to the right
        # of the prompt but since the input is not echo'd
        # and the cursor is invisible, it looks like we're
        # editing the prompt area
        read -srn 1 -p "grep ${YELLOW}$grep_args${NORM}$grep_spacer/${RED}${regex}${NORM}/" input

        case $input in
            "")
                # enter was probably pressed
                # accept the regex
                #DEBUG echo; echo "regex is |$grep_args;$regex|"
                break ;;
            $BACKSPACE)
                # handle backspace
                regex=${regex%?} ;;
            # anything else is added to the regex
            # matching printable characters doesn't save us from arrow keys
            [[:print:]]) regex+="$input" ;;
        esac
    
        #echo -n ' (o)'
        #sleep 0.1
    
        # overwrite the prompt
        tput dl1    # delete the current line
        tput hpa 0  # move cursor to the beginning of line
    done

    IFS=$oIFS   # restore IFS
    tput cnorm  # un-hide cursor

    exec 1>&3   # restore STDOUT

    echo $regex
}

regex=$(input_regex)

echo
echo "regex=|$regex|"
