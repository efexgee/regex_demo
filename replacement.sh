#!/bin/bash
# Apply a series of greps to a file of text
# to demonstrate regular expressions

# GLOBALS

# separator between grep args and the regex
# ~ is a special character in VI's ex mode
# but not in regex or grep
REGEX_SEP='~'

function quitting() {
    # also executes on ctrl-c
    # quits with status 0 because it was user-initiated
    echo -n $NORM  # restore default font
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
# in the case statements
shopt -s extglob

# use the grep alias inside the functions
shopt -s expand_aliases

# set default grep options
# -n print line numbers
# -E use extended regular expressions (egrep)
alias grep='grep --color=always -n -E'
# for the demo output, add
# -C100 print 100 lines of context
alias demo_grep='grep -C100'
# The '-C100', 'mc=', "bogus line", and '-e' in grep_it
# appended to the sample text allow us to always show
# unmatched lines in grey, even if no lines matched.
export GREP_COLORS='ms=04;31:mc=01;04;31:sl=:cx=01;30:fn=01;37:ln=32:bn=35:se=36'
GREP_BOGUS_LINE='#!~;;~!#'

alias jq='jq -r'

# cursor manipulations
alias hide_cursor='tput civis'
alias show_cursor='tput cnorm'
alias reset_line='tput dl1; tput hpa 0'

# set our tab width
TAB=1   # also used in tab-related functions
tabs -${TAB}

# set up the regular expressions
oIFS=$IFS   # backup the input field separator

# backspace key
BACKSPACE=`tput kbs`

# define some colors
NORM=`tput sgr0`
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`

function replacement () {
    local sed_args=''

    # get the regex
    hide_cursor

    # use 'read' in a loop to fake custom editor behavior
    local input
    local regex
    while true; do
        # the prompt is updating in the loop
        # technically, the user is typing to the right
        # of the prompt but since the cursor is invisible
        # it looks like we're editing the prompt area
        #TODO This doesn't seem to actually happen: use '-s' on read, but breaks terminal if ctrl-c'd
        read -srn 1 -p "Enter regex: sed /${RED}${regex}${NORM}/" input

        case $input in
            "")
                # enter was probably pressed
                # accept the regex
                break ;;
            $BACKSPACE)
                # handle backspace
                regex=${regex%?} ;;
            # anything else is added to the regex
            # matching printable characters doesn't save us from arrow keys
            [[:print:]]) regex+="$input" ;;
        esac

        # overwrite the prompt
        reset_line
    done

    reset_line

    local find="$regex"
    regex=""

    # use 'read' in a loop to fake custom editor behavior
    local input
    while true; do
        read -srn 1 -p "Enter regex: sed /${RED}${find}${NORM}/${GREEN}${regex}${NORM}/" input

        case $input in
            "")
                # enter was probably pressed
                # accept the regex
                break ;;
            $BACKSPACE)
                # handle backspace
                regex=${regex%?} ;;
            # anything else is added to the regex
            # matching printable characters doesn't save us from arrow keys
            [[:print:]]) regex+="$input" ;;
        esac

        # overwrite the prompt
        reset_line
    done

    reset_line

    local repl="$regex"
    regex=""

    # use 'read' in a loop to fake custom editor behavior
    local input
    while true; do
        read -srn 1 -p "Enter regex: sed /${RED}${find}${NORM}/${GREEN}${repl}${NORM}/${YELLOW}${regex}${NORM}" input

        case $input in
            "")
                # enter was probably pressed
                # accept the regex
                break ;;
            $BACKSPACE)
                # handle backspace
                regex=${regex%?} ;;
            # anything else is added to the regex
            # matching printable characters doesn't save us from arrow keys
            [[:print:]]) regex+="$input" ;;
        esac

        # overwrite the prompt
        reset_line
    done

    sed_args="$regex"

    show_cursor

    echo

    SEP=$'\a'

    echo
    echo "$text" | sed "s${SEP}${find}${SEP}${RED}&${NORM}${SEP}${sed_args}" | grep -n -e '$'
    echo
    echo "$text" | sed "s${SEP}${find}${SEP}${GREEN}${repl}${NORM}${SEP}${sed_args}" | grep -n -e '$'
    echo
    read -s -n 1 -p "${BLACK}Again${NORM}"
}

alias sed='sed -r'

text=$(cat text)


RED=`tput setaf 1`
GREEN=`tput setaf 2`
NORM=`tput sgr0`

oIFS=$IFS

IFS=''

while true; do
    clear
    echo "$text"
    echo

    replacement
done
