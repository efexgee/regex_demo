#!/bin/bash -f
# set -f or glob expansion on echo will hide things like ".*"

# Apply a series of greps to a file of text
# to demonstrate regular expressions

# set our tab width
TAB=8
tabs -${TAB} > /dev/null

# check whether we have a 'seq' command
if ! which seq > /dev/null; then
    echo "Requires the seq command."
    exit 10
fi

# enable shell pattern matching
#TODO for?
shopt -s extglob

# default file to use as the input text if no filename is provided
DEFAULT_INFILE="./regex_demo.txt"

# determine whether to use the default text file
if (( $# == 0 )); then
    infile=$DEFAULT_INFILE
else
    infile=$1
fi

# grab the contents
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
regexes=(`cat <<EOF | sort -R | head -999
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
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`

# width added to the pretty regex strings by the colors
COLOR_PADDING=$(( ${#YELLOW}+${#NORM}+${#RED}+${#NORM} ))

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

    echo "printed_width=$printed_width" >&2

    (( printed_width+=1 ))    # space after ')'
    (( printed_width+=1 ))    # ')' after number
    (( printed_width+=2 ))    # two digits (assuming < 100 items)

    # calculate actual width (what 'select' "sees")
    local actual_width=$printed_width

    # account for color control codes
    (( actual_width+=$COLOR_PADDING ))
    
    #printed_width=$(add_a_tab $printed_width $TAB)
    #actual_width=$(add_a_tab $actual_width $SELECT_TAB)
    # "round" to the next tab stop
    #printed_width=$(rnd_up_to_multiple $printed_width $TAB)
    #actual_width=$(rnd_up_to_multiple $actual_width $SELECT_TAB)


    # calculate how many columns we want
    local screen_width=$(tput cols)

    local want_cols=$(fit_columns $printed_width $TAB $screen_width)

    local need_width=0
    for ((i = 1; i <= $want_cols; i++)); do
        (( need_width+=$actual_width ))
        need_width=$(add_a_tab $need_width $SELECT_TAB)
    done
        
    echo "screen_width=$screen_width. printed_width=$printed_width. want_cols=$want_cols" >&2
    echo "actual_width=$actual_width. need_width=$need_width" >&2
    echo "first string should end at $printed_width and second should start at $(( $(add_a_tab $printed_width $TAB) + 1))" >&2
    echo $need_width
}

# build pretty version of regex list
#   removes the ";" and adds color
#echo "${regexes[*]}"
#read
 
# find the widest string to determine string padding
input_width=$(echo "${regexes[*]}" | wc -L)
regex_width=$((input_width + 2)) # add 2 for the slashes around the regex
padded_width=$((regex_width + COLOR_PADDING)) # for color codes

for ((i = 0; i < ${#regexes[*]}; i++)); do
    grep_line=${regexes[$i]}

    # build grep args string (need colors codes for padding)
    grep_args=""
    grep_args+="$YELLOW"
    if echo $grep_line | grep -q ';'; then
        grep_args+="$(echo $grep_line | cut -d';' -f1)"
        grep_args+=" "
    fi
    grep_args+="$NORM"

    # build grep regex string
    grep_regex="/"
    grep_regex+="$RED"
    grep_regex+="$(echo $grep_line | cut -d';' -f2)"
    grep_regex+="$NORM"
    grep_regex+="/"

    # apply padding to make "select" menu align correctly
    # because of the color codes
    #padded_width=0
    pretty_regexes[$i]=$(printf "%*s" $padded_width "${grep_args}${grep_regex}")

    #pretty_regexes[$i]=`echo "${pretty_regexes[$i]}"| col`
    #echo ${#pretty_regexes[$i]} ${pretty_regexes[$i]}
    #echo ${pretty_regexes[$i]} | wc -L
done

pretty_regexes[11]=`printf "${YELLOW}${NORM}${RED}${NORM}%.*s" $((padded_width - $COLOR_PADDING)) '-------------------------------------------'`
echo "max_pretty_wc: `echo "${pretty_regexes[*]}" | wc -L`"
echo
i=21
echo "${#regexes[$i]}|${regexes[$i]}|"
echo "${#pretty_regexes[$i]}|${pretty_regexes[$i]}|"
printf -- "--|%${padded_width}s\n" "|"
i=27
echo "${#regexes[$i]}|${regexes[$i]}|"
echo "${#pretty_regexes[$i]}|${pretty_regexes[$i]}|"
printf -- "--|%${padded_width}s\n" "|"
i=4
echo "${#regexes[$i]}|${regexes[$i]}|"
echo "${#pretty_regexes[$i]}|${pretty_regexes[$i]}|"

read

function hi () {
    #local output+=`tput smul`
    local output+="("
    local output+=$BLUE
    local output+=$1
    local output+=$NORM
    local output+=")"
    #local output+=`tput rmul`

    echo -n $output
}

# set up menu prompt text
#PS3=$'\n'"Choose regex `hi c`ontinue `hi q`uit: "
#PS3=$'\n'$'..) ----+----1----+----2----+----3----+----4----+----5----+----6----+----7----+----8----+----9\n'"Choose regex `hi c`ontinue `hi q`uit: "
PS3=$'\n'`tabs -d8`"Choose regex `hi c`ontinue `hi q`uit: "

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
    echo "$label: grep ${YELLOW}${grep_args}${NORM}${grep_spacer}/`tput setaf 1`$grep_regex`tput sgr0`/"
    echo

    # wait for user
    tput civis
    read -s -n 1 -p "Show result " input
    tput dl1
    tput hpa 0
    tput cnorm

    if [[ $input == "q" ]]; then
        quitting
    fi

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
    
    read -s -n 1 -p "`hi b`ack `hi j`ump `hi i`nteractive `hi m`enu `hi q`uit | Next " input
    # one echo to cap the input
    echo

    case $input in
        "q") quitting ;;
        "j") regex_menu ;;
        "i") interactive ;;
        "b") regex_id=$((regex_id - 2)) ;;
        "m") menu ;;
        *) ;;
    esac
}

function interactive () {
    echo "Apply a custom regular expression"
    read -r -p "regular expression: $RED" regex
    echo -n $NORM
    read -r -p "grep options: $YELLOW" opts
    echo -n $NORM

    local label="*"
    
    grep_it "$label" "${opts};${regex}"
}

function menu () {
    echo "read diff input file"
    read -p "not implemented"
}

function regex_menu () {
    clear
    COLUMNS=$(set_term_width $regex_width)
    echo "c: $COLUMNS"

    select choice in ${pretty_regexes[*]}; do
        case $REPLY in
            "c") break ;;
            "q") quitting ;;
            #[0-9]*) tabs -d$REPLY ;;
            @($choices))
                regex_id=$((REPLY -2))
                break ;;
            [0-9]*) COLUMNS=$REPLY; echo "Set COLUMNS=$REPLY" ;;
            "debug")
                tabs -d8
                echo "input_width=$input_width"
                echo "regex_width=$regex_width"
                echo "padded_width=$padded_width"
                echo "COLOR_PADDING=$COLOR_PADDING"
                echo "COLUMNS=$COLUMNS"
                ;;
            *) echo "Not a valid choice: $REPLY" ;;
        esac 
    done
}

# technically, this is the actual script
for ((regex_id = 0; regex_id < ${#regexes[*]}; regex_id++)); do
    grep_it $((regex_id + 1)) "${regexes[$regex_id]}"
done
