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
    popd > /dev/null # restore previous directory
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
# -E use extended regular expressions (egrep)
GREP_MODE='-E'
# -n print line numbers
alias grep='\grep --color=always -n'
# for the demo output, add
# -C100 print 100 lines of context
alias demo_grep='grep -C100'
# The '-C100', 'mc=', "bogus line", and '-e' in grep_it
# appended to the sample text allow us to always show
# unmatched lines in grey, even if no lines matched.
export GREP_COLORS='ms=04;31:mc=01;04;31:sl=:cx=01;30:fn=01;37:ln=32:bn=35:se=36'
GREP_BOGUS_LINE='#!~;;~!#'

alias jq='\jq -r'

# cursor manipulations
alias hide_cursor='tput civis'
alias show_cursor='tput cnorm'
alias reset_line='tput dl1; tput hpa 0'

# set our tab width
TAB=1   # also used in tab-related functions
tabs -${TAB}

# set up the regular expressions
oIFS=$IFS   # backup the input field separator

DEMO_FILE_SUFFIX=".regex_demo.json"

# default file to use as the input text if no filename is provided
DEFAULT_INFILE="original${DEMO_FILE_SUFFIX}"

# backspace key
BACKSPACE=`tput kbs`

# define some colors
NORM=`tput sgr0`
BLACK=`tput setaf 0`
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`

# width added to the pretty regex strings by the colors
COLOR_PADDING=$(( ${#YELLOW}+${#NORM}+${#RED}+${#NORM} ))

# check whether we have a 'seq' command
if ! which seq > /dev/null; then
    echo "Requires the seq command."
    exit 10
fi

# check whether we have a 'realpath' command
if ! which realpath > /dev/null; then
    echo "Requires the realpath command."
    exit 10
fi

# determine whether to use the default text file
if (( $# == 0 )); then
    infile=$DEFAULT_INFILE
else
    # grab absolute path to file so we can pushd
    infile=$(realpath $1)
fi

# change directory to script directory so we can
# list all the demo files in that directory
pushd $(dirname $(realpath $0)) > /dev/null


function prep_pretty () {
    # build pretty version of regex list
    # this will be printed by 'select'

    # reset array because we're assigning directly
    # to indexes
    unset pretty_regexes

    for ((i = 0; i < ${#regexes[*]}; i++)); do
        local regex_line=${regexes[$i]}

        # build grep args string
        local grep_args=""
        grep_args+="$YELLOW"
        if echo "$regex_line" | grep -q $REGEX_SEP; then
            grep_args+="$(echo "$regex_line" | cut -d${REGEX_SEP} -f1)"
            grep_args+=" "
        fi
        grep_args+="$NORM"

        # build grep regex string
        local grep_regex="/"
        grep_regex+="$RED"
        grep_regex+="$(echo "$regex_line" | cut -d${REGEX_SEP} -f2)"
        grep_regex+="$NORM"
        grep_regex+="/"

        # pad all entries to the same width or 'select' will
        # not be able to align them due to the non-printing
        # color codes
        pretty_regexes[$i]=$(printf "%-*s" $padded_width "${grep_args}${grep_regex}")
    done
}

function load_demo () {
    # load text and regexes from a json file
    local infile=$1

    local IFS=$'\n'

    # reset to first regex in the list
    #TODO reset to -1 because -1 + 2 = 1 ...
    regex_id=-1

    text=$(jq '.text[]' $infile)
    text+=$(echo -e "\n${GREP_BOGUS_LINE}")

    regexes=( $(jq '.regexes[]' $infile) )

    # build a pattern to match menu replies
    regex_choices=`seq -s '|' 1 ${#regexes[*]}`

    # determine some widths
    input_width=$(echo "${regexes[*]}" | wc -L) # the widest regex line
    regex_width=$((input_width + 2)) # regex with added slashes # restore default font
    padded_width=$((regex_width + COLOR_PADDING)) # with slashes and colors

    prep_pretty
}

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

    (( printed_width+=1 ))    # space after ')'
    (( printed_width+=1 ))    # ')' after number
    (( printed_width+=2 ))    # two digits (assuming < 100 items)

    # calculate actual width (what 'select' "sees")
    local actual_width=$printed_width

    # account for color control codes
    (( actual_width+=$COLOR_PADDING ))

    # calculate how many columns we want
    local screen_width=$(tput cols)
    local want_cols=$(fit_columns $printed_width $TAB $screen_width)

    # calculate what we have to set COLUMNS to
    local need_width=0
    for ((i = 1; i <= $want_cols; i++)); do
        (( need_width+=$actual_width ))
        need_width=$(add_a_tab $need_width $SELECT_TAB)
    done

    echo $need_width
}

function hi () {
    # highlight the shortcut key on a menu option
    # used inline: echo "press `hi done`"
    local word=$1

    local output+="("
    output+=$BLUE
    output+=${word:0:1}
    output+=$NORM
    output+=")${word:1}"

    echo -n "$output"
}

function grep_it () {
    # apply a regex and grep flag to the text
    local label=$1
    local grep_line=$2

    local input

    clear

    # just using grep to add the line numbers for consistent
    # appearance
    echo "$text" | grep '$' | head -n -1
    echo

    # '-s' makes 'cut' skip the line if there is no delimeter
    local grep_args=`echo "$grep_line" | cut -s -d${REGEX_SEP} -f1`
    local grep_spacer=''
    # if we have args, pad them with a space
    if [[ $grep_args != "" ]]; then
        grep_spacer=" "
    fi

    # 'cut' matches the whole line if there is no delimiter
    local grep_regex=`echo "$grep_line" | cut -d${REGEX_SEP} -f2`

    # print the regex that is about to be applied
    echo "$label: grep ${YELLOW}${grep_args}${NORM}${grep_spacer}/${RED}$grep_regex${NORM}/"
    echo

    # wait for user with a prompt
    hide_cursor
    read -s -n 1 -p "${BLACK}Hit <enter> to see the regex applied${NORM}" input
    # delete the prompt before printing the results
    reset_line
    show_cursor

    # secret check for a request to quit
    if [[ $input != "" ]]; then
        # if anything other than <enter> was pressed
        # process it
        process_input "$input"
    else
        # showing the result of applying the regex

        # handle one-off demonstrationg of lookahead, using PCRE
        # behavior with -P is untested and unreliable
        if [[ ! $grep_args =~ "P" ]]; then
            # use standard regex_demo grepping
            grep_output=$(echo "$text" | demo_grep $GREP_MODE $grep_args -e "$GREP_BOGUS_LINE" -e "$grep_regex" 2>&1)
        else
            # use hacky perl-style grepping
            # grep -P does not support multiple '-e' arguments, so
            # we can't grep the BOGUS_LINE to ensure a match
            grep_output=$(echo "$text" | demo_grep -P "$grep_regex" 2>&1)
        fi

        case $? in
            # the grep is good; cut off the bogus line
            0) echo "$grep_output" | head -n -1 ;;
            # the grep matched nothing (probably -v); force a fake no-match via bogus line
            # or it will print nothing at all
            1) echo "$text" | demo_grep -e "$GREP_BOGUS_LINE" | head -n -1 ;;
            # grep error: print slightly prettier output
            2) echo "GREP ERROR: args=|${YELLOW}${grep_args}${NORM}| regex=|${RED}${grep_regex}${NORM}|" >&2; echo "$grep_output" ;;
        esac

        echo
        validating_prompt "`hi back` `hi jump` `hi custom` `hi interactive` `hi load` file `hi quit` | Next " "bjcilq" "enter"
    fi
}

function validating_prompt () {
    # prompt until a valid entry is received
    local prompt="$1"
    local options="$2"
    local accept_enter=false

    if [[ $3 == "enter" ]]; then
        accept_enter=true
    fi

    hide_cursor

    while true; do
        read -s -n 1 -p "$prompt"
        if $accept_enter && [[ $REPLY == "" ]]; then
            break
        elif echo $REPLY | grep -q "[$options]"; then
            break
        fi
        reset_line
    done

    reset_line
    show_cursor

    process_input $REPLY
}

function process_input () {
    # process the input from prompts
    # allows for selecting options even when not
    # offered
    local option=$1

    case $option in
        "q") quitting ;;
        "j") regex_menu ;;
        "c") custom ;;
        "i") interactive ;;
        #TODO don't let this go negative!
        # to go back 1 we need to subtract 2
        "b") regex_id=$((regex_id - 2)) ;;
        "l") demo_menu ;;
        # return a status to indicate we did nothing
        # to allow callers to handle that if necessary
        *) ;;
    esac
}

function input_regex () {
    # since we're using 'echo' to "return" values from the
    # function we can't print to STDOUT during the input
    exec 3>&1 1>&2  # "save" STDOUT to FD3, redirect to STDERR

    local grep_args=''
    local grep_spacer=''

    #TODO ask for arguments after the regex
    # get flags for the grep command
    # -e allows us to handle things like backspaces
    read -e -p "Enter grep arguments: $YELLOW" grep_args
    # turn off colors without printing a newline
    echo -n $NORM

    if [[ -n $grep_args ]]; then
        # clean up args
        grep_args="$(echo $grep_args | sed 's/  */ /g; s/^ *//; s/ *$//')"
        # add a spacer between the flag and the /regex/
        grep_spacer=" "
    fi

    echo

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
        read -srn 1 -p "Enter regex: grep ${YELLOW}$grep_args${NORM}$grep_spacer/${RED}${regex}${NORM}/" input

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

    show_cursor

    exec 1>&3   # restore STDOUT

    if [[ -n $grep_args ]]; then
        echo "${grep_args}${REGEX_SEP}${regex}"
    else
        echo "$regex"
    fi
}

function custom () {
    # allow input of a custom regex to run on the text

    # get the regex via pretty interface
    local grep_line=$(input_regex)

    # we need to give grep_it() a label
    local label="*"

    # run it on the text
    grep_it "$label" "$grep_line"
}

function interactive () {
    # show matches in real-time

    hide_cursor

    # use 'read' in a loop to fake interactive editor behavior
    local input
    local regex
    local prompt
    local output
    local old_output

    # make local copy without bogus line because we don't need it
    local text=$(echo "$text" | head -n -1)

    while true; do
        clear

        regex="$prompt"
        output=$(echo "$text" | egrep --color=always -n -e '$' -e "$regex" 2> /dev/null)

        if (( $? == 2 )); then
            echo "$old_output"
        else
            echo "$output"
            old_output="$output"
        fi

        echo

        read -srn 1 -p "Enter regex: grep /${RED}${prompt}${NORM}/" input

        case $input in
            "")
                # enter was probably pressed
                # accept the regex
                break ;;
            $BACKSPACE)
                # handle backspace
                prompt=${prompt%?} ;;
            # anything else is added to the regex
            # matching printable characters doesn't save us from arrow keys
            [[:print:]])
                prompt+="$input" ;;
        esac

        # overwrite the prompt
        reset_line
    done

    show_cursor

    #TODO if we have a way to save customs, we should offer to save here
}

function demo_menu () {
    clear
    echo "Load a regex_demo file"
    echo

    local IFS=$'\n'

    local i=0
    local demo_file
    local demo_files
    local demos
    local demo_title
    local demo_descr

    local PS3=$'\n'"Choose a regex demo `hi continue` `hi quit`: "

    # enable file globbing to get the list of input files
    set +f

    for demo_file in $(\ls *${DEMO_FILE_SUFFIX}); do
        (( i++ ))
        demo_files[$i]=$demo_file

        demo_title=$(jq '.title' $demo_file)
        demo_descr=$(jq '.description' $demo_file)
        demos[$i]="${BLUE}$demo_title${NORM}: $demo_descr"
    done

    # re-disable file globbing
    set -f

    local choices=`seq -s '|' 1 ${#demos[*]}`

    select choice in ${demos[*]}; do
        case $REPLY in
            "c") break ;;
            "q") quitting ;;
            @($choices))
                load_demo ${demo_files[$REPLY]}
                break
                ;;
            *) echo "Not a valid choice: $REPLY"
        esac
    done
}

function regex_menu () {
    # draw the menu of regexes to choose from
    clear

    local IFS=$'\n'

    # set the terminal width so 'select' can align
    # colored text
    COLUMNS=$(set_term_width $regex_width)

    # 'select' uses PS3 as its prompt
    local PS3=$'\n'"Choose regex `hi continue` `hi quit`: "

    select choice in ${pretty_regexes[*]}; do
        case $REPLY in
                #TODO catch return by putting all this in a while loop
            "c") break ;;
                # don't jump to a different regex
            "q") quitting ;;
                # quit
            @($regex_choices))
                # if it's one of the numbers
                # change the current regex ID
                regex_id=$((REPLY -2))
                break ;;
            "debug")
                # undocumented debug output option
                tabs -d${TAB}
                echo "input_width=$input_width"
                echo "regex_width=$regex_width"
                echo "padded_width=$padded_width"
                echo "COLOR_PADDING=$COLOR_PADDING"
                echo "COLUMNS=$COLUMNS"
                echo "pwd=$(pwd)"
                echo "regex_choices=$regex_choices"
                ;;
            *) echo "Not a valid choice: $REPLY" ;;
                # anything else is invalid
        esac
    done

    # reset screen width
    COLUMNS=$(tput cols)
}

# main

# check that the text file exists
if [[ -f $infile ]]; then
    load_demo $infile
else
    demo_menu
fi

while true; do
    for ((regex_id = 0; regex_id < ${#regexes[*]}; regex_id++)); do
        grep_it $((regex_id + 1)) "${regexes[$regex_id]}"
    done

    echo "At the end of demo."
    echo

    validating_prompt "`hi back` `hi jump` `hi custom` `hi interactive` `hi load` file `hi quit`" "bjcilq"
done
