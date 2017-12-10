#!/bin/bash

# Apply a series of greps to input from STDIN
# to demonstrate regular expressions

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

number=0
function grep_it () {
    ((number++))

    clear
    # match every line. using grep just to add the line numbers
    echo "$text" | grep '$'
    echo

    # "-s" ignore lines without delimiters
    local grep_args=`echo $1 | cut -s -d';' -f1`
    # if we have args, pad them with a space
    if [[ $grep_args != "" ]]; then
        grep_args+=" "
    fi
    # without "-s" cut matches the whole line if there is no delimiter
    local grep_regex=`echo $1 | cut -d';' -f2`

    # print the header
    echo "$number: grep $grep_args/`tput setaf 1`$grep_regex`tput sgr0`/"
    prompt blank
    # perform the grep
    echo "$text" | grep $grep_args "($grep_regex|$)"
    prompt
}

function prompt() {
    if [[ $1 == "blank" ]]; then
        read -s -n 1 input
    else
        echo
        read -s -n 1 -p "Next (q to quit): " input
        # one echo to cap the input
        echo
    fi
    echo

    if [[ $input = "q" ]]; then
        exit 0
    fi
}

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
IFS=$ORIG_IFS

# run the greps
for regex in ${regexes[*]}; do
    grep_it "$regex"
done
