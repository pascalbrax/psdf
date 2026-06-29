#!/bin/bash
#
# df as percentage bars - pascal brax 2018

# define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
# No color
NC='\033[0m'

# bar template (constant, so define it once outside the loop/function)
bar="##################################################"
barlength=${#bar}

# progress bar function
progressbar()
{
    local pct=$1
    local n=$(( pct * barlength / 100 ))
    local color=$GREEN
    if (( pct >= 90 )); then
        color=$RED
    elif (( pct >= 70 )); then
        color=$YELLOW
    fi
    printf "\r[${color}%-${barlength}s ${NC}(%2d%%)] " "${bar:0:n}" "$pct"
}

# Parse "df" directly: let read split the columns instead of spawning
# echo/awk subshells per line. -P (POSIX) prevents long device names
# from wrapping onto a second line and breaking the field order.
while read -r _ _ _ _ pct mount; do
    # strip the trailing '%' from the Use% column (e.g. 56% -> 56)
    pct=${pct%\%}
    # skip the header row and any line whose Use% isn't numeric
    [[ $pct == *[!0-9]* || -z $pct ]] && continue
    # ignore mounts with 0% Use
    if (( pct > 0 )); then
        progressbar "$pct"
        echo "$mount"
    fi
done < <(df -hP)

# add newline to properly end
echo -ne '\n'
