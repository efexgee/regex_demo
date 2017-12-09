#!/bin/bash

# Apply a series of greps to input from STDIN
# to demonstrate regular expressions

DEFAULT_INFILE="./regex_demo.txt"

# echo the string with line breaks
IFS=""

# use the grep alias inside the functions
shopt -s expand_aliases

# set default grep options
# -n print line numbers
# -E use extended regular expressions (egrep)
alias grep='grep --color=always -n -E'
export GREP_COLORS='ms=04;31:mc=33:sl=:cx=:fn=01;37:ln=32:bn=35:se=36'

number=0
function regex () {
    ((number += 1))
    echo "$number: grep ${@: 1:$(($# - 1))} /${!#}/"
    #printf "%2d: grep %s /%s/\n" $number "${@: 1:$(($# - 1))}" ${!#}
    tput setaf 2; echo $text | grep "$@|$"
    #echo $text | grep -v $@
    echo
    prompt
}

function prompt() {
    read -s -n 1 -p "Next (q to quit): " input
    echo
    echo

    if [[ $input = "q" ]]; then
        exit 0
    fi
}
    
if (( $# == 0 )); then
    infile=$DEFAULT_INFILE
else
    infile=$1
fi

text=`cat $infile`

clear

# print original text
echo "# original text"
echo $text | grep '$'
echo
prompt

# run the greps
regex 'c'
regex 'C'
regex 'p f'
regex -i 'c'
regex -i '^c'
regex 's'
regex 'ss'
regex '.'
regex '..'
regex '..*'
regex '(.)\1'
regex '.$'
regex '\.$'
regex 'i'
regex ' i'
regex '[A-Z]'
regex '^[A-Z]'
regex 'ee'
regex 'ideas'
regex 'ide[ae]s'
regex '[iI]de[ae]s'
regex '^$'
regex '^.$'
regex '^.*$'
regex '^.*\.$'
regex -i 'ide[ae]s'
regex -i '([aeiou])\1'
regex -i '[aeiou][aeiou]+'
regex '[aeiou]{2,}'
regex -v '[^aeiou ]{2,}'
