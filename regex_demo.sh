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
    echo $NORM  # restore default font
    echo "Quitting."
    tabs -8     # restore default tab width
    IFS=$oIFS   # restore IFS
    tput cnorm  # restore cursor
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
# -n print line numbers
# -E use extended regular expressions (egrep)
# -C100 print 100 lines of context
alias demo_grep='grep --color=always -n -E -C100'
# The '-C100', 'mc=', "bogus line", and '-e' in grep_it
# appended to the sample text allow us to always show
# unmatched lines in grey, even if no lines matched.
export GREP_COLORS='ms=04;31:mc=01;04;31:sl=:cx=01;30:fn=01;37:ln=32:bn=35:se=36'
GREP_BOGUS_LINE='#!~;;~!#'

alias jq='jq -r'

# set our tab width
TAB=1   # also used in tab-related functions
tabs -${TAB}

# set up the regular expressions
oIFS=$IFS   # backup the input field separator

DEMO_FILE_SUFFIX=".regex_demo.json"

# default file to use as the input text if no filename is provided
DEFAULT_INFILE="./original${DEMO_FILE_SUFFIX}"

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

# determine whether to use the default text file
if (( $# == 0 )); then
    infile=$DEFAULT_INFILE
else
    infile=$1
fi

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

    #DEBUG pretty_regexes[11]=`printf "${YELLOW}${NORM}${RED}${NORM}%.*s" $((padded_width - $COLOR_PADDING)) '-------------------------------------------'`
}

function load_demo () {
    # load text and regexes from a json file
    #TODO this will break on tab characters
    local infile=$1

    local IFS=$'\n'

    # reset to first regex in the list
    #TODO reset to -1 because -1 + 2 = 1 ...
    regex_id=-1

    title=$(jq '.title' $infile)
    description=$(jq '.description' $infile)
    text=$(jq '.text[]' $infile)
    text+=$(echo -e "\n${GREP_BOGUS_LINE}")

    regexes=( $(jq '.regexes[]' $infile) )

    # build a pattern to match menu replies
    choices=`seq -s '|' 1 ${#regexes[*]}`

    # determine some widths
    input_width=$(echo "${regexes[*]}" | wc -L) # the widest regex line
    regex_width=$((input_width + 2)) # regex with added slashes # restore default font
    padded_width=$((regex_width + COLOR_PADDING)) # with slashes and colors

    prep_pretty
}

load_demo $infile

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
    # used inline: echo "press `hi d`one"
    #TODO accept whole word and highlight first letter?
    local output+="("
    local output+=$BLUE
    local output+=$1
    local output+=$NORM
    local output+=")"

    echo -n "$output"
}

function grep_it () {
    # apply a regex and grep flag to the text
    local label=$1
    local grep_line=$2

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
    tput civis  # hide the cursor
    read -s -n 1 -p "${BLACK}Hit <enter> to see the regex applied${NORM} " input
    # delete the prompt before printing the results
    tput dl1
    tput hpa 0
    tput cnorm  # show the cursor

    # secret check for a request to quit
    if [[ $input == "q" ]]; then
        quitting
    fi

    # print the grep output
    grep_output=$(echo "$text" | demo_grep $grep_args -e "$GREP_BOGUS_LINE" -e "$grep_regex" 2> /dev/null)

    case $? in
        # the grep is good; cut off the bogus line
        0) echo "$grep_output" | head -n -1 ;;
        # the grep matched nothing (probably -v); force a fake no-match via bogus line
        # or it will print nothing at all
        1) echo "$text" | demo_grep -e "$GREP_BOGUS_LINE" | head -n -1 ;;
        # grep error: print slightly prettier output
        2) echo "GREP ERROR: args=|${YELLOW}${grep_args}${NORM}| regex=|${RED}${grep_regex}${NORM}|" >&2 ;;
    esac

    prompt
}

function prompt() {
    echo

    tput civis  # hide cursor
    read -s -n 1 -p "`hi b`ack `hi j`ump `hi c`ustom `hi l`oad file `hi q`uit | Next " input
    # since the input requires no <enter> we print
    # a newline to keep things pretty
    echo
    tput cnorm  # restore cursor

    case $input in
        "q") quitting ;;
        "j") regex_menu ;;
        "c") custom ;;
        # to go back 1 we need to subtract 2
        "b") regex_id=$((regex_id - 2)) ;;
        "l") demo_menu ;;
        *) ;;
    esac
}

function input_regex () {
    # since we're using 'echo' to "return" values from the
    # function we can't print to STDOUT during the input
    exec 3>&1 1>&2  # "save" STDOUT to FD3, redirect to STDERR

    local oIFS=$IFS
    local BACKSPACE=`tput kbs`

    local grep_args=''
    local grep_spacer=''
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
    tput civis  # hide the cursor
    #TODO disable why?
    local IFS=''  # disable the input field separator

    # use 'read' in a loop to fake custom editor behavior
    local input
    local regex
    while true; do
        # the prompt is updating in the loop
        # technically, the user is typing to the right
        # of the prompt but since the cursor is invisible
        # it looks like we're editing the prompt area
        #TODO use '-s' on read, but breaks terminal if ctrl-c'd
        read -rn 1 -p "Enter regex: grep ${YELLOW}$grep_args${NORM}$grep_spacer/${RED}${regex}${NORM}/" input

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
        tput dl1    # delete the current line
        tput hpa 0  # move cursor to the beginning of line
    done

    tput cnorm  # un-hide cursor

    exec 1>&3   # restore STDOUT

    if [[ -n $grep_args ]]; then
        echo "${grep_args}${REGEX_SEP}${regex}"
    else
        echo "$regex"
    fi
}

function custom () {
    # allow input of a custom regex to run on the text
    echo
    # get the regex via pretty interface
    local grep_line=$(input_regex)

    # we need to give grep_it() a label
    local label="*"

    # run it on the text
    grep_it "$label" "$grep_line"
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

    local PS3=$'\n'"Choose a regex demo `hi c`ontinue `hi q`uit: "

    # disable file globbing so '*' doesn't get expanded
    set +f

    for demo_file in $(\ls *${DEMO_FILE_SUFFIX}); do
        (( i++ ))
        demo_files[$i]=$demo_file

        demo_title=$(jq '.title' $demo_file)
        demo_descr=$(jq '.description' $demo_file)
        demos[$i]="${BLUE}$demo_title${NORM}: $demo_descr"
    done

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

    # re-enable file globbing
    set -f
}

function regex_menu () {
    # draw the menu of regexes to choose from
    clear

    local IFS=$'\n'

    # set the terminal width so 'select' can align
    # colored text
    COLUMNS=$(set_term_width $regex_width)

    # 'select' uses PS3 as its prompt
    local PS3=$'\n'"Choose regex `hi c`ontinue `hi q`uit: "

    select choice in ${pretty_regexes[*]}; do
        case $REPLY in
                #TODO it would be nice to catch <return> here
            "c") break ;;
                # don't jump to a different regex
            "q") quitting ;;
                # quit
            @($choices))
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
                ;;
            *) echo "Not a valid choice: $REPLY" ;;
                # anything else is invalid
        esac
    done

    # reset screen width
    COLUMNS=$(tput cols)
}

# main
while true; do
    for ((regex_id = 0; regex_id < ${#regexes[*]}; regex_id++)); do
        grep_it $((regex_id + 1)) "${regexes[$regex_id]}"
    done

    while true; do
        # don't just exit when we reach the end of the list
        read -n 1 -p "At the end. Quit? (y/n) " response

        case $response in
            "y") quitting ;;
            "n") break ;;
            # break out of the inner 'while' loop
            # then the 'for' loop starts over
            *) echo "Please answer (y/n)" ;;
        esac
    done
done
