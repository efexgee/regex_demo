#!/bin/bash -f
# set -f or glob expansion on echo will hide things like ".*"

# Apply a series of greps to a file of text
# to demonstrate regular expressions

# The seq command is technically not standard
if ! which seq > /dev/null; then
    echo "Requires the seq command."
    exit 10
fi

# enable shell pattern matching
shopt -s extglob

# default file to use as the input text if no filename is provided
DEFAULT_INFILE="./regex_demo.txt"

# determine whether to use the default text file
if (( $# == 0 )); then
    infile=$DEFAULT_INFILE
else
    infile=$1
fi

text=`cat $infile`

# set default grep options
# -n print line numbers
# -E use extended regular expressions (egrep)
alias grep='grep --color=always -n -E'
# use the grep alias inside the functions
shopt -s expand_aliases
export GREP_COLORS='ms=04;31:mc=33:sl=:cx=:fn=01;37:ln=32:bn=35:se=36'

# set up the regular expressions
ORIG_IFS=$IFS
IFS=$'\n'   # need this dollar or some escapes get evaluated in the strings
regexes=(`cat <<EOF
c
C
p f
-i;c
-i;^c
s
ss
.
..
..*
(.)\1
.$
\.$
i
 i
[A-Z]
^[A-Z]
ee
ideas
ide[ae]s
[iI]de[ae]s
^$
^.$
^.*$
^.*\.$
-i;ide[ae]s
-i;([aeiou])\1
-i;[aeiou][aeiou]+
[aeiou]{2,}
-v;[^aeiou ]{2,}
EOF`
)

# define some colors
NORM=`tput sgr0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
BLUE=`tput setaf 4`

# build a pattern to match menu replies
choices=`seq -s '|' 1 ${#regexes[*]}`

# build pretty version of regex list
#   removes the ";" and adds color

# find the longest entry to determine string padding
max_length=$(($(echo "${regexes[*]}" | wc -L) - 3))

for ((i = 0; i < ${#regexes[*]}; i++ )); do
    grep_line=${regexes[$i]}

    if echo $grep_line | grep -q ';'; then
        # color codes, though not visible, make the strings too wide for "select"
        #grep_args="${BLUE}$(echo $grep_line | cut -s -d';' -f1) ${NORM}"
        grep_args="$(echo $grep_line | cut -d';' -f1) "
    else
        grep_args=""
    fi
    #grep_regex="/${RED}$(echo $grep_line | cut -d';' -f2)${NORM}/"
    grep_regex="${RED}$(echo $grep_line | cut -d';' -f2)${NORM}"

    pretty_regexes[$i]=$(printf "%-${max_length}s\n" "${grep_args}${grep_regex}")
done

# set up menu prompt text
PS3=$'\n'"Choose regex (c)ontinue (q)uit: "

function grep_it () {
    local label=$1
    local grep_line=$2

    clear
    # match every line. using grep just to add the line numbers
    echo "$text" | grep '$'
    echo

    # "-s" ignore lines without delimiters
    local grep_args=`echo $grep_line | cut -s -d';' -f1`
    # if we have args, pad them with a space
    local grep_spacer
    if [[ $grep_args != "" ]]; then
        local grep_spacer=" "
    fi
    # without "-s" cut matches the whole line if there is no delimiter
    local grep_regex=`echo $grep_line | cut -d';' -f2`

    # print the header
    echo "$label: grep ${grep_args}${grep_spacer}/`tput setaf 1`$grep_regex`tput sgr0`/"
    # wait for user
    read -s -n 1 input
    if [[ $input == "q" ]]; then
        quitting
    fi

    echo
    # print the grep output
    # do not put "()" around the "|" or the back references break
    echo "$text" | grep $grep_args "$grep_regex|$"
    prompt
}

function quitting() {
    # quits with status 0 because it was intentional
    echo
    echo "Quitting."
    exit 0
}

function prompt() {
    echo
    read -s -n 1 -p "Next (b)ack (j)ump (m)enu (q)uit: " input
    # one echo to cap the input
    echo

    case $input in
        "q") quitting ;;
        "j")
            read -p "Jump to regex: " target_id
            # subtract two from the target because:
            #  the for loop will increment it
            #  we were passed "id + 1"
            case $target_id in
                @($choices)) regex_id=$((target_id - 2)) ;;
                *)
                    echo
                    read -s -n 1 -t 1 -p "Not a valid ID: $target_id" ;;
            esac ;;
        "b") regex_id=$((regex_id - 2)) ;;
        "m") menu ;;
        *) ;;
    esac
}

function menu () {
    clear
    select choice in ${pretty_regexes[*]}; do
        case $REPLY in
            "c") break ;;
            "q") quitting ;;
            @($choices))
                regex_id=$((REPLY -2))
                break ;;
            *) echo "Not a valid choice: $REPLY" ;;
        esac 
    done
}

# technically, this is the actual script
for ((regex_id = 0; regex_id < ${#regexes[*]}; regex_id++)); do
    grep_it $((regex_id + 1)) "${regexes[$regex_id]}"
done
