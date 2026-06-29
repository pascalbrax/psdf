#!/bin/bash
#
# df as percentage bars - pascal brax 2018

# ---------------------------------------------------------------------------
# Options
# ---------------------------------------------------------------------------
# Colours shade white -> purple -> white across each bar/label. On a bright
# terminal background the "white" end is invisible, so --invert swaps it for
# black (i.e. shade black -> purple -> black). Can also be set with
# PSDF_INVERT=1 in the environment.
INVERT=${PSDF_INVERT:-0}
while (( $# )); do
    case $1 in
        -i|--invert) INVERT=1 ;;
        -h|--help)
            printf 'usage: %s [-i|--invert]\n' "${0##*/}"
            printf '  -i, --invert   shade from black instead of white (bright backgrounds)\n'
            printf 'env: PSDF_INVERT=1 same as --invert\n'
            printf '     PSDF_COLORS=truecolor|256  force colour depth (default: auto-detect)\n'
            exit 0 ;;
        *) printf 'unknown option: %s\n' "$1" >&2; exit 1 ;;
    esac
    shift
done

# Pick the colour depth: 24-bit truecolor when the terminal advertises it,
# otherwise fall back to the xterm-256 palette. PSDF_COLORS overrides.
case ${PSDF_COLORS:-} in
    truecolor|24bit|24) COLORMODE=truecolor ;;
    256)                COLORMODE=256 ;;
    *)
        case $COLORTERM in
            truecolor|24bit) COLORMODE=truecolor ;;
            *)               COLORMODE=256 ;;
        esac ;;
esac

# purple end of the gradient (RGB)
PR=168; PG=50; PB=235

# bar glyphs
FILL='█'
EMPTY='░'
RESET='\033[0m'

# fgcode <r> <g> <b> -> sets FG to the SGR foreground escape for the current
# colour mode. In 256 mode the RGB is mapped to the nearest xterm-256 index
# (6x6x6 colour cube, or the grey ramp when r==g==b).
fgcode()
{
    local r=$1 g=$2 b=$3 idx
    if [[ $COLORMODE == truecolor ]]; then
        FG="\033[38;2;${r};${g};${b}m"
        return
    fi
    if (( r == g && g == b )); then
        if   (( r < 8 ));   then idx=16
        elif (( r > 238 )); then idx=231
        else idx=$(( 232 + (r - 8) / 10 )); fi
    else
        idx=$(( 16 + 36 * (r * 5 / 255) + 6 * (g * 5 / 255) + (b * 5 / 255) ))
    fi
    FG="\033[38;5;${idx}m"
}

# colour used for the empty part of the bar (grey, visible on either bg)
if (( INVERT )); then
    fgcode 200 200 200   # light grey for a bright background
else
    fgcode 90 90 90      # dim grey for a dark background
fi
EMPTYFG=$FG

# bar template length (constant, define once)
barlength=50

# ---------------------------------------------------------------------------
# Colour helpers (pure bash, no subshells)
# ---------------------------------------------------------------------------
# cellcolor <i> <len>: sets FG to the colour escape for position i over a span
# of len cells. The blend is a triangle (0 at the ends, 100 in the middle) so
# the gradient runs white -> purple -> white ("and back"). blend 100 is full
# purple; blend 0 is white, or black when --invert is set. Pure integer math.
cellcolor()
{
    local i=$1 len=$2 d max b
    max=$(( len > 1 ? len - 1 : 1 ))
    d=$(( 2 * i - (len - 1) ))
    (( d < 0 )) && d=$(( -d ))
    b=$(( 100 - d * 100 / max ))
    if (( INVERT )); then
        fgcode $(( PR * b / 100 )) $(( PG * b / 100 )) $(( PB * b / 100 ))
    else
        fgcode $(( 255 + (PR - 255) * b / 100 )) \
               $(( 255 + (PG - 255) * b / 100 )) \
               $(( 255 + (PB - 255) * b / 100 ))
    fi
}

# progressbar <pct>: gradient-filled bar, dim glyphs for the empty remainder
progressbar()
{
    local pct=$1
    local n=$(( pct * barlength / 100 ))
    local i b out=""
    for (( i = 0; i < barlength; i++ )); do
        if (( i < n )); then
            cellcolor "$i" "$barlength"
            out+="${FG}${FILL}"
        else
            out+="${EMPTYFG}${EMPTY}"
        fi
    done
    printf '%b' "${out}${RESET}"
}

# shade <string>: print the string with the same white->purple->white sweep
shade()
{
    local s=$1
    local len=${#s}
    local i out=""
    (( len == 0 )) && return
    for (( i = 0; i < len; i++ )); do
        cellcolor "$i" "$len"
        out+="${FG}${s:i:1}"
    done
    printf '%b' "${out}${RESET}"
}

# ---------------------------------------------------------------------------
# Filesystem selection (see previous commits for the filtering rationale)
# ---------------------------------------------------------------------------
# Pseudo/virtual filesystem types we never want to show.
is_pseudo() {
    case $1 in
        tmpfs|devtmpfs|devfs|fdescfs|proc|procfs|sysfs|cgroup|cgroup2|\
        overlay|squashfs|mqueue|debugfs|tracefs|securityfs|pstore|bpf|\
        configfs|fusectl|hugetlbfs|autofs|binfmt_misc|ramfs|nullfs|none|\
        udev|efivarfs|selinuxfs|map) return 0 ;;
    esac
    return 1
}

# When lsblk is available (Linux), build an allow-list of mount points backed
# by real block devices.
declare -A allow
use_allow=0
if command -v lsblk >/dev/null 2>&1; then
    while read -r mp; do
        [[ -n $mp ]] && allow[$mp]=1
    done < <(lsblk -rno MOUNTPOINT 2>/dev/null)
    (( ${#allow[@]} > 0 )) && use_allow=1
fi

# GNU df (Linux) supports -T to print the fs type; BSD/Darwin df doesn't.
if df --version >/dev/null 2>&1; then
    df_out=$(df -hPT)
    has_type=1
else
    df_out=$(df -hP)
    has_type=0
fi

# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------
declare -A seen
while read -ra f; do
    n=${#f[@]}
    (( n < 2 )) && continue
    src=${f[0]}
    mount=${f[n-1]}
    pct=${f[n-2]}
    type=
    (( has_type )) && type=${f[1]}

    pct=${pct%\%}
    [[ $pct == *[!0-9]* || -z $pct ]] && continue

    is_pseudo "${type:-$src}" && continue
    is_pseudo "$src" && continue
    (( use_allow )) && [[ -z ${allow[$mount]} ]] && continue
    [[ -n ${seen[$mount]} ]] && continue
    seen[$mount]=1

    if (( pct > 0 )); then
        printf -v pcttext '(%2d%%)' "$pct"
        printf '['
        progressbar "$pct"
        printf ' '
        shade "$pcttext"
        printf '] '
        shade "$mount"
        printf '\n'
    fi
done <<< "$df_out"
