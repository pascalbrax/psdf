#!/bin/bash
#
# df as percentage bars - pascal brax 2018

# grap df -h output
DFOUTPUT=$(df -h | grep '/')


# progress bar function
progressbar()
{
    bar="##################################################"
    barlength=${#bar}
    n=$(($1*barlength/100))
    printf "\r[%-${barlength}s (%2d%%)] " "${bar:0:n}" "$1" 
}


# Printf '%s\n' "$var" is necessary because printf '%s' "$var" on a
# variable that doesn't end with a newline then the while loop will
# completely miss the last line of the variable.
while IFS= read -r line
do
   # Percentage and mount points per line
   LINEPER=`echo $line | awk {'print $5'}`
   LINEMOUNT=`echo $line | awk {'print $6'}`
   
   # ${var: : -1} removes 1 trailing character from $var (56% -> 56)
   LINENUM=`echo ${LINEPER: : -1}`

   # lets ignore mounts with 0% Use
   if (( $LINENUM > 0 )); then
    progressbar "$LINENUM" 
    echo $LINEMOUNT
    fi


done < <(printf '%s\n' "$DFOUTPUT")
#add newline to properly end
echo -ne '\n'
