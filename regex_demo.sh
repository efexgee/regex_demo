#!/bin/bash

# Apply a series of greps to input from STDIN
# to demonstrate regular expressions

# echo the string with line breaks
IFS=""

# set default grep options
# -n print line numbers
# -E use extended regular expressions (egrep)
export GREP_OPTIONS='--color=always -n -E'
export GREP_COLORS='ms=01;31:mc=33:sl=:cx=:fn=01;37:ln=32:bn=35:se=36'

function regex () {
    echo "# grep ${@: 1:$(($# - 1))} /${!#}/"
    echo $text | grep "$@|$"
    #echo $text | grep -v $@
    echo
}

text=`cat $1`

# print original text
echo "# original text"
echo $text | grep '$'
echo

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
