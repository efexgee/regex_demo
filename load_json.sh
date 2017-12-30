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

IFS=','
regexes=( $(jq '.regexes | @csv' $INFILE | tr -d '"') )

echo ${regexes[*]}
echo
echo "|${regexes[10]}|"
echo "|${regexes[13]}|"
echo "|${regexes[14]}|"

IFS=$oIFS
