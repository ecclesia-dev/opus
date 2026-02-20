#!/bin/sh
# opus — Traditional Divine Office (1962 Breviary) in the terminal
# Outputs the proper texts for a given canonical hour and date
# Data: Divinum Officium project (github.com/DivinumOfficium/divinum-officium)

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DATA="${OPUS_DATA:-${SCRIPT_DIR}/data}"
PSALMS="$DATA/Psalterium/Psalmorum"
SPECIAL="$DATA/Psalterium/Special"
PSALMI="$DATA/Psalterium/Psalmi"

# Get date info
export TZ
DOW_NUM=$(date "+%u")  # 1=Mon 7=Sun
DISPLAY_DATE=$(date "+%A, %B %d, %Y")

# Map day of week
case "$DOW_NUM" in
    1) DOW="Feria II" ;;
    2) DOW="Feria III" ;;
    3) DOW="Feria IV" ;;
    4) DOW="Feria V" ;;
    5) DOW="Feria VI" ;;
    6) DOW="Sabbato" ;;
    7) DOW="Dominica" ;;
esac

# Extract a section from a DO data file
# Usage: get_section "file" "Section Name"
get_section() {
    _file="$1"
    _section="$2"
    [ -f "$_file" ] || return 1
    awk -v sect="[$_section]" '
        $0 == sect { found=1; next }
        /^\[/ && found { exit }
        found { print }
    ' "$_file"
}

# Get psalm text by number, with optional verse range
# Usage: get_psalm 118 33 48
get_psalm() {
    _num="$1"
    _from="$2"
    _to="$3"
    _file="$PSALMS/Psalm${_num}.txt"
    [ -f "$_file" ] || return 1
    if [ -n "$_from" ] && [ -n "$_to" ]; then
        awk -F: -v from="$_num:$_from" -v to="$_num:$_to" '
            { ref = $1 ":" $2; sub(/ .*/, "", ref) }
            ref >= from && ref <= to { sub(/^[0-9]+:[0-9]+[a-z]? /, "", $0); print }
        ' "$_file"
    else
        sed 's/^[0-9]*:[0-9]*[a-z]* //' "$_file"
    fi
}

# Parse psalm reference like "118(33-48)" or "79" or "79(2-8)"
parse_and_print_psalm() {
    _ref=$(echo "$1" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    _ref=$(echo "$_ref" | sed 's/^\[//;s/\]$//')  # strip optional brackets
    
    _pnum=$(echo "$_ref" | sed "s/(.*//; s/'//g")
    _range=$(echo "$_ref" | grep -o '([^)]*)' | tr -d '()')
    
    if [ -n "$_range" ]; then
        _from=$(echo "$_range" | cut -d- -f1 | tr -d "'" | sed 's/[a-z]*$//')
        _to=$(echo "$_range" | cut -d- -f2 | tr -d "'" | sed 's/[a-z]*$//')
        printf '\n  Psalm %s:%s-%s\n\n' "$_pnum" "$_from" "$_to"
    else
        printf '\n  Psalm %s\n\n' "$_pnum"
    fi
    
    _file="$PSALMS/Psalm${_pnum}.txt"
    if [ -f "$_file" ]; then
        if [ -n "$_from" ] && [ -n "$_to" ]; then
            awk -F: -v pn="$_pnum" -v from="$_from" -v to="$_to" '
            BEGIN { split("", a) }
            /^[0-9]+:[0-9]/ {
                vstr = $2
                gsub(/[^0-9].*/, "", vstr)
                v = vstr + 0
                if (v >= from+0 && v <= to+0) {
                    line = $0
                    sub(/^[0-9]+:[0-9]+[a-z]? /, "", line)
                    print "  " line
                }
            }' "$_file"
        else
            sed 's/^[0-9]*:[0-9]*[a-z]* /  /' "$_file"
        fi
    fi
}

# Format DO markup for terminal output
format_text() {
    sed 's/^v\. /  /
         s/^V\. /  ℣. /
         s/^R\. /  ℟. /
         s/^R\.br\. /  ℟. /
         s/^_$/  /
         s/^\* /  /
         s/^\$/  /
         s/^!/  /
         s/&Gloria/  ℣. Glory be to the Father, and to the Son, and to the Holy Ghost.\n  ℟. As it was in the beginning, is now, and ever shall be, world without end. Amen./'
}

# Determine the liturgical season/key for today
# This is simplified — proper implementation would compute Easter
get_season_key() {
    # For now use Feria/Dominica
    echo "$DOW"
}

# Print a minor hour (Terce, Sext, None)
print_minor_hour() {
    _hour="$1"  # Tertia, Sexta, Nona
    _label="$2" # Terce, Sext, None
    
    SEASON=$(get_season_key)
    
    printf '%s\n\n' "══════════════════════════════════════"
    printf '  %s\n' "$_label"
    printf '  %s\n' "$DISPLAY_DATE"
    printf '%s\n\n' "══════════════════════════════════════"
    
    # Opening versicle
    printf '  ℣. O God, ✠ come to my assistance.\n'
    printf '  ℟. O Lord, make haste to help me.\n\n'
    printf '  Glory be to the Father, and to the Son,\n'
    printf '  and to the Holy Ghost.\n'
    printf '  As it was in the beginning, is now, and ever shall be,\n'
    printf '  world without end. Amen.\n\n'
    
    # Hymn
    printf '  ── Hymn ──\n\n'
    get_section "$SPECIAL/Minor Special.txt" "Hymnus $_hour" | format_text
    printf '\n'
    
    # Psalms — look up which psalms for this day and hour
    _psalm_line=$(get_section "$PSALMI/Psalmi minor.txt" "$_hour" | grep "^${SEASON}" | head -1)
    
    if [ -n "$_psalm_line" ]; then
        # Extract antiphon (before =) and psalm refs (after =)
        _antiphon=$(echo "$_psalm_line" | sed 's/ = .*//' | sed "s/^${SEASON} = //; s/^[^ ]* = //")
        _psalms=$(echo "$_psalm_line" | sed 's/.*= //')
        _antiphon=$(echo "$_psalms" | sed 's/[0-9].*//')
        _psalms=$(echo "$_psalm_line" | awk -F= '{print $NF}')
        
        # Re-parse: line format is "Day = Antiphon text\npsalm,psalm,psalm"
        # Actually format is: "Feria VI = Antiphon text\n79(2-8), 79(9-20), 81"
        _data=$(get_section "$PSALMI/Psalmi minor.txt" "$_hour" | grep -A1 "^${SEASON}")
        _ant_line=$(echo "$_data" | head -1)
        _psalm_refs=$(echo "$_data" | tail -1)
        
        # Antiphon
        _ant=$(echo "$_ant_line" | sed "s/^[^=]*= //")
        printf '  ── Antiphon ──\n\n'
        printf '  %s\n\n' "$_ant"
        
        printf '  ── Psalms ──\n'
        
        # Parse comma-separated psalm references
        echo "$_psalm_refs" | tr ',' '\n' | while read -r _pref; do
            _pref=$(echo "$_pref" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -z "$_pref" ] && continue
            echo "$_pref" | grep -q '^\[' && continue  # skip optional psalms in brackets
            parse_and_print_psalm "$_pref"
        done
    fi
    
    printf '\n'
    
    # Little chapter (capitulum) — from Tempora or Minor Special
    _cap=$(get_section "$SPECIAL/Minor Special.txt" "${SEASON} ${_hour}")
    if [ -n "$_cap" ]; then
        printf '  ── Little Chapter ──\n\n'
        echo "$_cap" | format_text
        printf '\n'
    fi
    
    # Responsory
    _resp=$(get_section "$SPECIAL/Minor Special.txt" "Responsory breve ${SEASON} ${_hour}")
    if [ -n "$_resp" ]; then
        printf '  ── Responsory ──\n\n'
        echo "$_resp" | format_text
        printf '\n'
    fi
    
    # Versicle
    _vers=$(get_section "$SPECIAL/Minor Special.txt" "Versum ${SEASON} ${_hour}")
    if [ -z "$_vers" ]; then
        _vers=$(get_section "$SPECIAL/Minor Special.txt" "Versum ${SEASON} ${_hour}_")
    fi
    if [ -n "$_vers" ]; then
        printf '  ── Versicle ──\n\n'
        echo "$_vers" | format_text
        printf '\n'
    fi
    
    # Closing
    printf '  ℣. Dómine, exáudi oratiónem meam.\n'
    printf '  ℟. Et clamor meus ad te véniat.\n\n'
    printf '  ℣. Benedicámus Dómino.\n'
    printf '  ℟. Deo grátias.\n\n'
    printf '  ℣. Fidélium ánimæ, per misericórdiam Dei,\n'
    printf '     requiéscant in pace.\n'
    printf '  ℟. Amen.\n'
    printf '\n%s\n' "══════════════════════════════════════"
}

# Print Lauds or Vespers
print_major_hour() {
    _hour="$1"  # Laudes, Vespera
    _label="$2"
    
    printf '%s\n\n' "══════════════════════════════════════"
    printf '  %s\n' "$_label"
    printf '  %s\n' "$DISPLAY_DATE"
    printf '%s\n\n' "══════════════════════════════════════"
    
    # Opening
    printf '  ℣. O God, ✠ come to my assistance.\n'
    printf '  ℟. O Lord, make haste to help me.\n\n'
    printf '  Glory be to the Father, and to the Son,\n'
    printf '  and to the Holy Ghost.\n'
    printf '  As it was in the beginning, is now, and ever shall be,\n'
    printf '  world without end. Amen.\n\n'
    
    # Hymn
    printf '  ── Hymn ──\n\n'
    _hymn_key="Hymnus Day${DOW_NUM} ${_hour}"
    _hymn=$(get_section "$SPECIAL/Major Special.txt" "$_hymn_key")
    if [ -z "$_hymn" ]; then
        _hymn_key="Hymnus Day0 ${_hour}"
        _hymn=$(get_section "$SPECIAL/Major Special.txt" "$_hymn_key")
    fi
    if [ -n "$_hymn" ]; then
        echo "$_hymn" | format_text
    fi
    printf '\n'
    
    # Psalms
    printf '  ── Psalms ──\n'
    _psalm_data=$(get_section "$PSALMI/Psalmi major.txt" "$_hour")
    if [ -n "$_psalm_data" ]; then
        _day_line=$(echo "$_psalm_data" | grep "^${DOW}" | head -1)
        if [ -z "$_day_line" ]; then
            _day_line=$(echo "$_psalm_data" | grep "^Dominica" | head -1)
        fi
        if [ -n "$_day_line" ]; then
            _refs=$(echo "$_day_line" | awk -F= '{print $NF}')
            echo "$_refs" | tr ',' '\n' | while read -r _pref; do
                _pref=$(echo "$_pref" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                [ -z "$_pref" ] && continue
                echo "$_pref" | grep -q '^\[' && continue
                parse_and_print_psalm "$_pref"
            done
        fi
    fi
    printf '\n'
    
    # Little chapter from Tempora
    printf '  ── Little Chapter ──\n\n'
    _cap=$(get_section "$SPECIAL/Major Special.txt" "${DOW} ${_hour}")
    if [ -n "$_cap" ]; then
        echo "$_cap" | format_text
    fi
    printf '\n'
    
    printf '  ℣. Dómine, exáudi oratiónem meam.\n'
    printf '  ℟. Et clamor meus ad te véniat.\n\n'
    printf '  ℣. Benedicámus Dómino.\n'
    printf '  ℟. Deo grátias.\n'
    printf '\n%s\n' "══════════════════════════════════════"
}

# Print Compline
print_compline() {
    printf '%s\n\n' "══════════════════════════════════════"
    printf '  Compline — Night Prayer\n'
    printf '  %s\n' "$DISPLAY_DATE"
    printf '%s\n\n' "══════════════════════════════════════"
    
    # Compline is mostly fixed
    printf '  ℣. Turn us then, O God, our saviour.\n'
    printf '  ℟. And let thy anger cease from us.\n\n'
    printf '  ℣. O God, ✠ come to my assistance.\n'
    printf '  ℟. O Lord, make haste to help me.\n\n'
    printf '  Glory be to the Father, and to the Son,\n'
    printf '  and to the Holy Ghost.\n'
    printf '  As it was in the beginning, is now, and ever shall be,\n'
    printf '  world without end. Amen.\n\n'
    
    # Hymn
    printf '  ── Hymn ──\n\n'
    get_section "$SPECIAL/Minor Special.txt" "Hymnus Completorium" | format_text
    printf '\n'
    
    # Psalms 4, 30(2-6), 90, 133
    printf '  ── Psalms ──\n'
    for _p in "4" "30" "90" "133"; do
        parse_and_print_psalm "$_p"
    done
    printf '\n'
    
    # Nunc dimittis
    printf '  ── Canticle of Simeon ──\n\n'
    printf '  Save us, O Lord, while waking,\n'
    printf '  and guard us while sleeping;\n'
    printf '  that awake we may watch with Christ,\n'
    printf '  and asleep we may rest in peace.\n\n'
    printf '  Now thou dost dismiss thy servant, O Lord,\n'
    printf '  according to thy word in peace;\n'
    printf '  Because my eyes have seen thy salvation,\n'
    printf '  Which thou hast prepared before the face\n'
    printf '  of all peoples:\n'
    printf '  A light to the revelation of the Gentiles,\n'
    printf '  and the glory of thy people Israel.\n\n'
    
    printf '  ℣. Dómine, exáudi oratiónem meam.\n'
    printf '  ℟. Et clamor meus ad te véniat.\n\n'
    
    # Marian antiphon (varies by season — Salve Regina in ordinary time / after Pentecost)
    printf '  ── Marian Antiphon ──\n\n'
    printf '  Salve, Regína, Mater misericórdiæ,\n'
    printf '  vita, dulcédo, et spes nostra, salve.\n'
    printf '  Ad te clamámus, éxsules fílii Hevæ.\n'
    printf '  Ad te suspirámus, geméntes et flentes\n'
    printf '  in hac lacrimárum valle.\n'
    printf '  Eia ergo, advocáta nostra,\n'
    printf '  illos tuos misericórdes óculos\n'
    printf '  ad nos convérte.\n'
    printf '  Et Jesum, benedíctum fructum ventris tui,\n'
    printf '  nobis post hoc exsílium osténde.\n'
    printf '  O clemens, O pia, O dulcis Virgo María.\n'
    
    printf '\n%s\n' "══════════════════════════════════════"
}

# Print Prime
print_prime() {
    print_minor_hour_generic "Prima" "Prime — First Hour"
}

print_minor_hour_generic() {
    _hour="$1"
    _label="$2"
    
    printf '%s\n\n' "══════════════════════════════════════"
    printf '  %s\n' "$_label"
    printf '  %s\n' "$DISPLAY_DATE"
    printf '%s\n\n' "══════════════════════════════════════"
    
    printf '  ℣. O God, ✠ come to my assistance.\n'
    printf '  ℟. O Lord, make haste to help me.\n\n'
    printf '  Glory be to the Father, and to the Son,\n'
    printf '  and to the Holy Ghost.\n'
    printf '  As it was in the beginning, is now, and ever shall be,\n'
    printf '  world without end. Amen.\n\n'
    
    # Prime has its own psalms
    printf '  ── Psalms ──\n'
    _psalm_data=$(get_section "$PSALMI/Psalmi minor.txt" "$_hour")
    if [ -n "$_psalm_data" ]; then
        _day_data=$(echo "$_psalm_data" | grep -A1 "^${DOW}")
        _ant_line=$(echo "$_day_data" | head -1)
        _psalm_refs=$(echo "$_day_data" | tail -1)
        
        if [ -n "$_ant_line" ]; then
            _ant=$(echo "$_ant_line" | sed "s/^[^=]*= //")
            printf '\n  Ant. %s\n' "$_ant"
        fi
        
        echo "$_psalm_refs" | tr ',' '\n' | while read -r _pref; do
            _pref=$(echo "$_pref" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            [ -z "$_pref" ] && continue
            echo "$_pref" | grep -q '^\[' && continue
            parse_and_print_psalm "$_pref"
        done
    fi
    
    printf '\n'
    printf '  ℣. Dómine, exáudi oratiónem meam.\n'
    printf '  ℟. Et clamor meus ad te véniat.\n\n'
    printf '  ℣. Benedicámus Dómino.\n'
    printf '  ℟. Deo grátias.\n'
    printf '\n%s\n' "══════════════════════════════════════"
}

# Main
usage() {
    printf 'opus — Traditional Divine Office (1962 Breviary)\n\n'
    printf 'Usage: opus [hour]\n\n'
    printf 'Hours:\n'
    printf '  lauds      Morning Prayer (Laudes)\n'
    printf '  prime      First Hour (Prima)\n'
    printf '  terce      Third Hour (Tertia)\n'
    printf '  sext       Sixth Hour (Sexta)\n'
    printf '  none       Ninth Hour (Nona)\n'
    printf '  vespers    Evening Prayer (Vesperae)\n'
    printf '  compline   Night Prayer (Completorium)\n\n'
    printf 'Without arguments, prints the current hour.\n'
}

# Auto-detect current hour if none given
auto_hour() {
    _h=$(date "+%H")
    if [ "$_h" -lt 7 ]; then echo "lauds"
    elif [ "$_h" -lt 9 ]; then echo "prime"
    elif [ "$_h" -lt 11 ]; then echo "terce"
    elif [ "$_h" -lt 14 ]; then echo "sext"
    elif [ "$_h" -lt 17 ]; then echo "none"
    elif [ "$_h" -lt 20 ]; then echo "vespers"
    else echo "compline"
    fi
}

HOUR="${1:-$(auto_hour)}"

case "$HOUR" in
    lauds)    print_major_hour "Laudes" "Lauds — Morning Prayer" ;;
    prime)    print_prime ;;
    terce)    print_minor_hour "Tertia" "Terce — Third Hour" ;;
    sext)     print_minor_hour "Sexta" "Sext — Sixth Hour" ;;
    none)     print_minor_hour "Nona" "None — Ninth Hour" ;;
    vespers)  print_major_hour "Vespera" "Vespers — Evening Prayer" ;;
    compline) print_compline ;;
    -h|--help|help) usage ;;
    *) usage; exit 1 ;;
esac
