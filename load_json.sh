#!/bin/bash

shopt -s expand_aliases

alias jq='jq -r'

oIFS=$IFS

INFILE="original.regex_demo.json"

title=$(jq '.title' $INFILE)
description=$(jq '.description' $INFILE)

echo "$title: $description"
echo

text=$(jq '.text[]' $INFILE)

echo "$text"
echo

IFS=$'\t'
regexes=( $(jq '.regexes | @tsv' $INFILE) )

for (( i=0; $i < ${#regexes[*]}; i++ )); do
    echo "${regexes[$i]}" | tr -d '"'
done

#echo
#echo "|${regexes[10]}|"
#echo "|${regexes[13]}|"
#echo "|${regexes[14]}|"

IFS=$oIFS
