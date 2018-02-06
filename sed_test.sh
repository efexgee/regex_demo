#!/bin/bash

shopt -s expand_aliases

SEP=$'\a'

alias grep='grep --color=always -n -E'
export GREP_COLORS='ms=04;31:mc=01;04;31:sl=:cx=01;30:fn=01;37:ln=32:bn=35:se=36'

alias sed='sed -r'

text=$(cat text)

echo "$text"

RED=`tput setaf 1`
GREEN=`tput setaf 2`
NORM=`tput sgr0`

oIFS=$IFS

IFS=''

while true; do
echo
read -e -r -p "match: " match
read -e -r -p "replace: " replace
read -e -r -p "options: " options
echo
echo "/${match}/${replace}/"
echo
#echo "$text" | grep -e '$' -e "$match"
echo "$text" | sed "s${SEP}${match}${SEP}${RED}&${NORM}${SEP}${options}"
echo
echo "$text" | sed "s${SEP}${match}${SEP}${GREEN}${replace}${NORM}${SEP}${options}" | grep -e '$'
echo
read -s -n 1 -p "next"
clear
done
