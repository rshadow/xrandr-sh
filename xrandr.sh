#!/bin/bash

# Update monirots via xrandr

### OPTIONS

usage ()
{
    echo "usage: xrandr OPTIONS"
    echo "  -h|--help     - This help"
    echo "  -a|--all      - Configure all connected monitors"
    echo "  -o|--one      - Only primary monitor"
    echo "  -v|--verbose  - Turn on verbose mode"
    echo "  -d|--debug    - Turn on debug all xrandr output"
    echo "  -s|--sleep    - Wait seconds before apply"
    echo "  -e|--emulate  - Just show assembled command without execution"
}

# Mode: 
#   1 - all monitors,
#   0 - only primary
MODE=1
# Show debug messages
VERBOSE=
# More debug
DEBUG=
# Sleep before apply
SLEEP=0
# Just show command
EMULATE=

while [ "$1" != "" ]; do
    case $1 in
        -v | --verbose )    VERBOSE=1
        ;;
        -v | --debug )      DEBUG=1
        ;;
        -a | --all )        MODE=1
        ;;
        -o | --one )        MODE=0
        ;;
        -s | --sleep )      SLEEP=1
        ;;
        -e | --emulate )    EMULATE=1
        ;;
        -h | --help )       usage
                            exit
                            ;;
        * )                 usage
                            exit 1
    esac
    shift
done


### SLEEP
# Maybe need for udev because events too fast for devices.


if [ $SLEEP != 0 ]
then
    [ $VERBOSE ] && echo "Sleep:        $SLEEP seconds"
    sleep $SLEEP
fi


### DATA


# Get user and X display
XDISP=":0.0"
[ $VERBOSE ] && echo "Display:      $XDISP"
CURUSER=$(whoami)
[ $VERBOSE ] && echo "Owner:        $CURUSER"
XWHO=$(who | grep "(${XDISP})" | head -n 1)
XUSER=$(echo "$XWHO" | cut -d' ' -f 1) || echo "$CURUSER"

[ $VERBOSE ] && echo "User:         $XUSER"

# Set X enviroment
export XAUTHORITY=/home/${XUSER}/.Xauthority
export DISPLAY=$XDISP
export WALLPAPER=/home/${XUSER}/.wallpaper.jpeg

# Get xrandr data
XRANDR=$(which xrandr)
[ "$CURUSER" != "$XUSER" ] && XRANDR="sudo -u ${XUSER} ${XRANDR}"
XDATA=$(DISPLAY=${XDISP} ${XRANDR} | grep -v "^ " | grep -iv "^screen")
[ $DEBUG ] && echo "XRandr:       $XDATA"

# All connectors
ALL=$(echo "$XDATA" | cut -f 1 -d ' ')
[ $VERBOSE ] && echo "$ALL" | paste -s -d"," | echo "Output:       $(cat -)"

# Primary monitor name: by special connector or first from list
PRIMARY=$(echo "$ALL" | grep eDP) || $(echo "$ALL" | head -n 1)
[ $VERBOSE ] && echo "Primary:      $PRIMARY"

SECONDARY=$(echo "$ALL" | grep -v "$PRIMARY")
[ $VERBOSE ] && echo "$SECONDARY" | paste -s -d"," | echo "Secondary:    $(cat -)"

# List of connected monitors
CONNECTED=$(echo "$XDATA" | grep " connected " | cut -f 1 -d ' ')
[ $VERBOSE ] && echo "$CONNECTED" | paste -s -d"," | echo "Connected:    $(cat -)"

# List of disconnected monitors
DISCONNECTED=$(echo "$XDATA" | grep " disconnected " | cut -f 1 -d ' ')
[ $VERBOSE ] && echo "$DISCONNECTED" | paste -s -d"," | echo "Disconnected: $(cat -)"

# List of configured monitors
ENABLED=$(echo "$XDATA" | grep "onnected [0-9]" | cut -f 1 -d ' ')
[ $VERBOSE ] && echo "$ENABLED" | paste -s -d"," | echo "Configured:   $(cat -)"

# List of unconfigured monitors
DISABLED=$(echo "$XDATA" | grep -v "onnected [0-9]" | cut -f 1 -d ' ')
[ $VERBOSE ] && echo "$DISABLED" | paste -s -d"," | echo "Unconfigured: $(cat -)"

# Need tune-up
UP=$(cat <(echo "$CONNECTED") <(echo "$DISABLED") | sort | uniq -d)
[ $VERBOSE ] && echo "$UP" | paste -s -d"," | echo "Tune-up:      $(cat -)"

# Need off
DOWN=$(cat <(echo "$DISCONNECTED") <(echo "$ENABLED") | sort | uniq -d)
[ $VERBOSE ] && echo "$DOWN" | paste -s -d"," | echo "Off:          $(cat -)"


### ASSEMBLY


# Execution string
EXEC="$XRANDR"

case $MODE in
    0)
        [ $VERBOSE ] && echo "Mode:         primary monitor only ($MODE)"

        # Primary monitor
        EXEC="$EXEC --output $PRIMARY --auto"

        # Drop all configured
        for OUTPUT in $(echo "$ENABLED" | grep -v "$PRIMARY")
        do
            EXEC="$EXEC --output $OUTPUT --off"
        done
    ;;
    1)
        [ $VERBOSE ] && echo "Mode:         auto configure all monitors ($MODE)"

        # Tune-up
        for OUTPUT in $UP
        do
            EXEC="$EXEC --output $OUTPUT --auto --right-of $PRIMARY"
        done

        # Turn off
        for OUTPUT in $(echo "$DOWN" | grep -v "$PRIMARY")
        do
            EXEC="$EXEC --output $OUTPUT --off"
        done
    ;;
    *)
        echo "Unknown mode $MODE"
        exit 1
    ;;
esac


### EXECUTION


# Apply configuration
if [ "$EXEC" == "$XRANDR" ]
then
    [ $VERBOSE ] && echo "Execute:      is not need"
else
    if [ $EMULATE ]
    then
        echo "$EXEC"
    else
        [ $VERBOSE ] && echo "Execute:      $EXEC"
        $($EXEC) || exit $?
    fi
fi

# Update wallpaper
if [ -x /usr/bin/feh ] && [ -f "$WALLPAPER" ]
then
    feh --no-fehbg --bg-fill "$WALLPAPER"
    [ $VERBOSE ] && echo "Wallpaper:    $WALLPAPER"
else
    [ $VERBOSE ] && echo "Wallpaper:    not updated"
fi


# COMPLETE


[ $VERBOSE ] && echo "Complete."
exit 0
