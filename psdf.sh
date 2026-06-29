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

# Pseudo/virtual filesystem types we never want to show. These (tmpfs,
# proc, snap squashfs images, ...) often appear many times and aren't
# real storage. Used as a fallback filter and to drop snap loops.
is_pseudo() {
    case $1 in
        tmpfs|devtmpfs|devfs|fdescfs|proc|procfs|sysfs|cgroup|cgroup2|\
        overlay|squashfs|mqueue|debugfs|tracefs|securityfs|pstore|bpf|\
        configfs|fusectl|hugetlbfs|autofs|binfmt_misc|ramfs|nullfs|none|\
        udev|efivarfs|selinuxfs|map) return 0 ;;
    esac
    return 1
}

# When lsblk is available (Linux), build an allow-list of mount points that
# are backed by real block devices. This is the most reliable way to skip
# virtual/temp filesystems and dedupe what df reports.
declare -A allow
use_allow=0
if command -v lsblk >/dev/null 2>&1; then
    while read -r mp; do
        [[ -n $mp ]] && allow[$mp]=1
    done < <(lsblk -rno MOUNTPOINT 2>/dev/null)
    (( ${#allow[@]} > 0 )) && use_allow=1
fi

# GNU df (Linux) supports -T to print the fs type, which we use for filtering
# when lsblk isn't around. BSD/Darwin df lacks it, so fall back to -P only.
if df --version >/dev/null 2>&1; then
    df_out=$(df -hPT)
    has_type=1
else
    df_out=$(df -hP)
    has_type=0
fi

# Parse df directly: read each line into an array and index the Use% and
# mount columns from the end, so it works with or without the Type column.
declare -A seen
while read -ra f; do
    n=${#f[@]}
    (( n < 2 )) && continue
    src=${f[0]}
    mount=${f[n-1]}
    pct=${f[n-2]}
    type=
    (( has_type )) && type=${f[1]}

    # strip the trailing '%' (e.g. 56% -> 56); skip header / non-numeric rows
    pct=${pct%\%}
    [[ $pct == *[!0-9]* || -z $pct ]] && continue

    # drop virtual/pseudo filesystems (by type if known, else by source name)
    is_pseudo "${type:-$src}" && continue
    is_pseudo "$src" && continue

    # with lsblk, keep only real block-device mount points
    (( use_allow )) && [[ -z ${allow[$mount]} ]] && continue

    # de-duplicate: never show the same mount point twice
    [[ -n ${seen[$mount]} ]] && continue
    seen[$mount]=1

    # ignore mounts with 0% Use
    if (( pct > 0 )); then
        progressbar "$pct"
        echo "$mount"
    fi
done <<< "$df_out"

# add newline to properly end
echo -ne '\n'
