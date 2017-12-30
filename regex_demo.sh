#!/bin/bash
# Apply a series of greps to a file of text
# to demonstrate regular expressions

# GLOBALS

function quitting() {
    # also executes on ctrl-c
    # quits with status 0 because it was user-initiated
    echo $NORM  # restore default font
    echo "Quitting."
    tabs -8     # restore default tab width
    IFS=$oIFS   # restore IFS
    tput cnorm  # restore cursor
    exit 0
}

# trap ctrl-c so we can fix any custom settings
trap quitting SIGINT

# disable *-expansion on echo so regexes are printed
set -f

# enable shell pattern matching
#TODO for?
shopt -s extglob

# use the grep alias inside the functions
shopt -s expand_aliases

# set default grep options
# -n print line numbers
# -E use extended regular expressions (egrep)
alias grep='grep --color=always -n -E'
export GREP_COLORS='ms=04;31:mc=33:sl=:cx=:fn=01;37:ln=32:bn=35:se=36'

alias jq='jq -r'

# set our tab width
TAB=1   # also used in tab-related functions
tabs -${TAB}

# set up the regular expressions
oIFS=$IFS   # backup the input field separator
IFS=$'\n'   # need this dollar or some escapes get evaluated in the strings

# default file to use as the input text if no filename is provided
DEFAULT_INFILE="./original.regex_demo.json"

# define some colors
NORM=`tput sgr0`
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`

# width added to the pretty regex strings by the colors
COLOR_PADDING=$(( ${#YELLOW}+${#NORM}+${#RED}+${#NORM} ))

# check whether we have a 'seq' command
if ! which seq > /dev/null; then
    echo "Requires the seq command."
    exit 10
fi

# determine whether to use the default text file
if (( $# == 0 )); then
    infile=$DEFAULT_INFILE
else
    infile=$1
fi

# read from JSON files
title=$(jq '.title' $infile)
description=$(jq '.description' $infile)
text=$(jq '.text[]' $infile)
IFS=','
regexes=( $(jq '.regexes | @csv' $infile | tr -d '"') )

IFS=$'\n' #TODO do we still need this?

function rnd_up_to_multiple () {
    # round up to the nearest multiple of N
    local value=$1
    local multiple=$2

    # we add almost one whole multiple first so the integer
    # division will essentially round up for us
    local offset=$(($multiple - 1))
    echo $(( (value + offset) / multiple * multiple ))
}

function add_a_tab () {
    # calculate the cursor position if we add a tab to
    local cur_pos=$1
    local tab_width=$2

    if (( cur_pos % tab_width == 0 )); then
        (( cur_pos+=tab_width ))
    else
        cur_pos=$(rnd_up_to_multiple $cur_pos $tab_width)
    fi

    echo $cur_pos
}

function fit_columns () {
    # calculate number of columns fit on a screen
    local str_width=$1
    local tab_width=$2
    local screen_width=$3

    local num_columns=1
    local cur_pos=$str_width

    # if we haven't run out of screen
    while (( $cur_pos < $screen_width )); do
        # add a tab
        cur_pos=$(add_a_tab $cur_pos $tab_width)

        # add a copy of the string
        (( cur_pos+=$str_width ))

        # if that didn't put us over, we've fit another column
        if (( $cur_pos <= $screen_width )); then
            (( num_columns+=1 ))
        fi
    done

    echo $num_columns
}

function set_term_width () {
    # the 'select' command can't account for non-printing
    # characters like color-codes when calculating how
    # many columns to print, so we're going to lie to it

    local SELECT_TAB=8     # 'select' assumes 8-char tabs

    # calculate printed width (what we see)
    local printed_width=$1

    (( printed_width+=1 ))    # space after ')'
    (( printed_width+=1 ))    # ')' after number
    (( printed_width+=2 ))    # two digits (assuming < 100 items)

    # calculate actual width (what 'select' "sees")
    local actual_width=$printed_width

    # account for color control codes
    (( actual_width+=$COLOR_PADDING ))

    # calculate how many columns we want
    local screen_width=$(tput cols)
    local want_cols=$(fit_columns $printed_width $TAB $screen_width)

    # calculate what we have to set COLUMNS to
    local need_width=0
    for ((i = 1; i <= $want_cols; i++)); do
        (( need_width+=$actual_width ))
        need_width=$(add_a_tab $need_width $SELECT_TAB)
    done

    #DEBUG echo "screen_width=$screen_width. printed_width=$printed_width. want_cols=$want_cols" >&2
    #DEBUG echo "actual_width=$actual_width. need_width=$need_width" >&2
    #DEBUG echo "first string should end at $printed_width and second should start at $(( $(add_a_tab $printed_width $TAB) + 1))" >&2
    echo $need_width
}


# determine some widths
input_width=$(echo "${regexes[*]}" | wc -L) # the widest regex line
regex_width=$((input_width + 2)) # regex with added slashes # restore default font
padded_width=$((regex_width + COLOR_PADDING)) # with slashes and colors

# build pretty version of regex list
# this will be printed by 'select'
for ((i = 0; i < ${#regexes[*]}; i++)); do
    regex_line=${regexes[$i]}

    # build grep args string
    grep_args=""
    grep_args+="$YELLOW"
    if echo $regex_line | grep -q ';'; then
        grep_args+="$(echo $regex_line | cut -d';' -f1)"
        grep_args+=" "
    fi
    grep_args+="$NORM"

    # build grep regex string
    grep_regex="/"
    grep_regex+="$RED"
    grep_regex+="$(echo $regex_line | cut -d';' -f2)"
    grep_regex+="$NORM"
    grep_regex+="/"

    # pad all entries to the same width or 'select' will
    # not be able to align them due to the non-printing
    # color codes
    pretty_regexes[$i]=$(printf "%-*s" $padded_width "${grep_args}${grep_regex}")
done

#DEBUG pretty_regexes[11]=`printf "${YELLOW}${NORM}${RED}${NORM}%.*s" $((padded_width - $COLOR_PADDING)) '-------------------------------------------'`

function hi () {
    # highlight the shortcut key on a menu option
    # used inline: echo "press `hi d`one"
    local output+="("
    local output+=$BLUE
    local output+=$1
    local output+=$NORM
    local output+=")"

    echo -n $output
}

# 'select' uses PS3 as its prompt
# Note: function hi() has to be defined
PS3=$'\n'"Choose regex `hi c`ontinue `hi q`uit: "

function grep_it () {
    # apply a regex and grep flag to the text
    local label=$1
    local grep_line=$2

    clear
    # just using grep to add the line numbers for consistent
    # appearance
    echo "$text" | grep '$'
    echo

    # '-s' makes 'cut' skip the line if there is no delimeter
    local grep_args=`echo $grep_line | cut -s -d';' -f1`
    # if we have args, pad them with a space
    if [[ $grep_args != "" ]]; then
        local grep_spacer=" "
    fi
    # 'cut' matches the whole line if there is no delimiter
    local grep_regex=`echo $grep_line | cut -d';' -f2`

    # print the regex that is about to be applied
    echo "$label: grep ${YELLOW}${grep_args}${NORM}${grep_spacer}/${RED}$grep_regex${NORM}/"
    echo

    # wait for user with a prompt
    tput civis  # hide the cursor
    read -s -n 1 -p "${BLACK}Show regex applied${NORM} " input
    # delete the prompt before printing the results
    tput dl1
    tput hpa 0
    tput cnorm  # show the cursor

    # check for a request to quit (though not offered)
    if [[ $input == "q" ]]; then
        quitting
    fi

    # print the grep output
    # the "regex|$" must not be inside "()" or regexes with back
    # references will break
    echo "$text" | grep $grep_args "$grep_regex|$"
    prompt
}

function prompt() {
    echo

    tput civis
    read -s -n 1 -p "`hi b`ack `hi j`ump `hi i`nteractive `hi m`enu `hi q`uit | Next " input
    # since the input requires no <enter> we print
    # a newline to keep things pretty
    echo
    tput cnorm

    case $input in
        "q") quitting ;;
        "j") regex_menu ;;
        "i") interactive ;;
        "b") regex_id=$((regex_id - 2)) ;;
        "m") menu ;;
        *) ;;
    esac
}

function input_regex () {
    exec 3>&1 1>&2  # "save" STDOUT to FD3, redirect to STDERR

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

    echo

    # get the regex
    tput civis  # hide the cursor
    IFS=''  # disable the input field separator

    # use 'read' in a loop to fake interactive editor behavior
    local input
    local regex
    while true; do
        # the prompt is updating in the loop
        # technically, the user is typing to the right
        # of the prompt but since the cursor is invisible
        # it looks like we're editing the prompt area
        #TODO use '-s' on read, but breaks terminal if ctrl-c'd
        read -rn 1 -p "Enter regex: grep ${YELLOW}$grep_args${NORM}$grep_spacer/${RED}${regex}${NORM}/" input

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

function interactive () {
    # allow input of a custom regex to run on the text
    echo
    # get the regex via pretty interface
    regex=$(input_regex)

    # we need to give grep_it() a label
    local label="*"

    # run it on the text
    grep_it "$label" "${opts};${regex}"
}

function menu () {
    echo "read diff input file"
    read -p "not implemented"
}

function regex_menu () {
    # draw the menu of regexes to choose from
    clear
    # set the terminal width so 'select' can align
    # colored text
    COLUMNS=$(set_term_width $regex_width)

    select choice in ${pretty_regexes[*]}; do
        case $REPLY in
                #TODO it would be nice to catch <return> here
            "c") break ;;
                # don't jump to a different regex
            "q") quitting ;;
                # quit
            @($choices))
                # if it's one of the numbers
                # change the current regex ID
                regex_id=$((REPLY -2))
                break ;;
            "debug")
                # undocumented debug output option
                tabs -d8
                echo "input_width=$input_width"
                echo "regex_width=$regex_width"
                echo "padded_width=$padded_width"
                echo "COLOR_PADDING=$COLOR_PADDING"
                echo "COLUMNS=$COLUMNS"
                ;;
            *) echo "Not a valid choice: $REPLY" ;;
                # anything else is invalid
        esac
    done
}

# technically, this is the actual script
for ((regex_id = 0; regex_id < ${#regexes[*]}; regex_id++)); do
    grep_it $((regex_id + 1)) "${regexes[$regex_id]}"
done
