#!/bin/bash

shopt -s expand_aliases

alias jq='jq -r'

oIFS=$IFS

infile=$1

if [ -z $infile ]; then
    echo "This shouldn't be empty"
    exit 1
fi

title=$(jq '.title' $infile)
description=$(jq '.description' $infile)

echo "$title: $description"
echo

text=$(jq '.text[]' $infile)

echo "$text"
echo

IFS=$'\n'
# .regexes must be referenced as a list or the escaping breaks
regexes=( $(jq '.regexes[]' $infile) )

for (( i=0; $i < ${#regexes[*]}; i++ )); do
    echo "${regexes[$i]}" | tr -d '"'
done

#echo
#echo "|${regexes[10]}|"
#echo "|${regexes[13]}|"
#echo "|${regexes[14]}|"

IFS=$oIFS
