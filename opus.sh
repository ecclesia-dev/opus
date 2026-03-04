#!/bin/sh
# opus — Traditional Divine Office (1962 Breviary) in the terminal
# All 8 canonical hours with proper texts for the day
# Data: Divinum Officium project (MIT licensed)

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DATA="${OPUS_DATA:-${SCRIPT_DIR}/data}"
PSALMS="$DATA/Psalterium/Psalmorum"
SPECIAL="$DATA/Psalterium/Special"
PSALMI="$DATA/Psalterium/Psalmi"
PRAYERS="$DATA/Psalterium/Common/Prayers.txt"
TEMPORA="$DATA/Tempora"
SANCTI="$DATA/Sancti"

# Defaults
LANG_MODE="english"
TARGET_DATE=""

# ─── Argument parsing ─────────────────────────────────────────────
HOUR=""
while [ $# -gt 0 ]; do
    case "$1" in
        --date)   TARGET_DATE="$2"; shift 2 ;;
        --latin)  LANG_MODE="latin"; shift ;;
        --english) LANG_MODE="english"; shift ;;
        -h|--help|help) HOUR="help"; shift ;;
        -*)       echo "Unknown option: $1"; exit 1 ;;
        *)        HOUR="$1"; shift ;;
    esac
done

# ─── Date computation ─────────────────────────────────────────────
if [ -n "$TARGET_DATE" ]; then
    echo "$TARGET_DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' || {
        echo "Error: date must be YYYY-MM-DD"; exit 1
    }
    YEAR=$(echo "$TARGET_DATE" | cut -d- -f1)
    MONTH=$(echo "$TARGET_DATE" | cut -d- -f2 | sed 's/^0//')
    DAY=$(echo "$TARGET_DATE" | cut -d- -f3 | sed 's/^0//')
    DOW_NUM=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" "+%u" 2>/dev/null || \
              date -d "$TARGET_DATE" "+%u" 2>/dev/null || echo "1")
    DISPLAY_DATE=$(date -j -f "%Y-%m-%d" "$TARGET_DATE" "+%A, %B %d, %Y" 2>/dev/null || \
                   date -d "$TARGET_DATE" "+%A, %B %d, %Y" 2>/dev/null || echo "$TARGET_DATE")
    MM_DD=$(printf '%02d-%02d' "$MONTH" "$DAY")
else
    YEAR=$(date "+%Y")
    MONTH=$(date "+%-m" 2>/dev/null || date "+%m" | sed 's/^0//')
    DAY=$(date "+%-d" 2>/dev/null || date "+%d" | sed 's/^0//')
    DOW_NUM=$(date "+%u")
    DISPLAY_DATE=$(date "+%A, %B %d, %Y")
    MM_DD=$(date "+%m-%d")
fi

case "$DOW_NUM" in
    1) DOW="Feria II";  DOW_IDX=1 ;;
    2) DOW="Feria III"; DOW_IDX=2 ;;
    3) DOW="Feria IV";  DOW_IDX=3 ;;
    4) DOW="Feria V";   DOW_IDX=4 ;;
    5) DOW="Feria VI";  DOW_IDX=5 ;;
    6) DOW="Sabbato";   DOW_IDX=6 ;;
    7) DOW="Dominica";  DOW_IDX=0 ;;
    *) DOW="Feria II";  DOW_IDX=1 ;;
esac

# ─── Easter computation (Meeus/Jones/Butcher) ────────────────────
compute_easter() {
    _y=$1
    _a=$((_y % 19))
    _b=$((_y / 100))
    _c=$((_y % 100))
    _d=$((_b / 4))
    _e=$((_b % 4))
    _f=$(((_b + 8) / 25))
    _g=$(((_b - _f + 1) / 3))
    _h=$(((19 * _a + _b - _d - _g + 15) % 30))
    _i=$((_c / 4))
    _k=$((_c % 4))
    _l=$(((32 + 2 * _e + 2 * _i - _h - _k) % 7))
    _m=$(((_a + 11 * _h + 22 * _l) / 451))
    EASTER_MONTH=$(((_h + _l - 7 * _m + 114) / 31))
    EASTER_DAY=$(((_h + _l - 7 * _m + 114) % 31 + 1))
}

# Julian Day Number for date arithmetic
jdn() {
    _jy=$1; _jm=$2; _jd=$3
    _ja=$(((14 - _jm) / 12))
    _jyy=$((_jy + 4800 - _ja))
    _jmm=$((_jm + 12 * _ja - 3))
    echo $((_jd + (153 * _jmm + 2) / 5 + 365 * _jyy + _jyy / 4 - _jyy / 100 + _jyy / 400 - 32045))
}

# ─── Liturgical season detection ──────────────────────────────────
compute_easter "$YEAR"
EASTER_JDN=$(jdn "$YEAR" "$EASTER_MONTH" "$EASTER_DAY")
TODAY_JDN=$(jdn "$YEAR" "$MONTH" "$DAY")
DAYS_FROM_EASTER=$((TODAY_JDN - EASTER_JDN))

# Advent 1 Sunday
_nov27_jdn=$(jdn "$YEAR" 11 27)
_nov27_dow=$(( (_nov27_jdn + 1) % 7 ))
if [ "$_nov27_dow" -eq 6 ]; then
    ADVENT1_JDN=$_nov27_jdn
else
    ADVENT1_JDN=$((_nov27_jdn + (6 - _nov27_dow)))
fi

EPIPHANY_JDN=$(jdn "$YEAR" 1 6)
SEPTUAGESIMA_JDN=$((EASTER_JDN - 63))
ASH_WEDNESDAY_JDN=$((EASTER_JDN - 46))
PASSION_SUNDAY_JDN=$((EASTER_JDN - 14))
PENTECOST_JDN=$((EASTER_JDN + 49))

get_season() {
    if [ "$MONTH" -eq 12 ] && [ "$DAY" -ge 25 ]; then
        SEASON="Nat"; SEASON_LONG="Christmastide"
        TEMPORA_KEY="Nat$(printf '%02d' "$DAY")"
    elif [ "$MONTH" -eq 1 ] && [ "$DAY" -le 5 ]; then
        SEASON="Nat"; SEASON_LONG="Christmastide"
        TEMPORA_KEY="Nat$(printf '%02d' "$((DAY + 25))")"
    elif [ "$TODAY_JDN" -ge "$ADVENT1_JDN" ]; then
        _adv_week=$(((TODAY_JDN - ADVENT1_JDN) / 7 + 1))
        [ "$_adv_week" -gt 4 ] && _adv_week=4
        SEASON="Adv"; SEASON_LONG="Advent"
        TEMPORA_KEY="Adv${_adv_week}-${DOW_IDX}"
    elif [ "$MONTH" -eq 1 ] && [ "$DAY" -le 13 ]; then
        SEASON="Epi"; SEASON_LONG="Epiphanytide"
        _epi_week=$(((TODAY_JDN - EPIPHANY_JDN) / 7 + 1))
        [ "$_epi_week" -lt 1 ] && _epi_week=1
        TEMPORA_KEY="Epi${_epi_week}-${DOW_IDX}"
    elif [ "$DAYS_FROM_EASTER" -lt -63 ]; then
        SEASON="Epi"; SEASON_LONG="After Epiphany"
        _epi_weeks=$(((TODAY_JDN - EPIPHANY_JDN) / 7 + 1))
        [ "$_epi_weeks" -lt 1 ] && _epi_weeks=1
        [ "$_epi_weeks" -gt 6 ] && _epi_weeks=6
        TEMPORA_KEY="Epi${_epi_weeks}-${DOW_IDX}"
    elif [ "$DAYS_FROM_EASTER" -lt -46 ]; then
        _pre_week=$(((TODAY_JDN - SEPTUAGESIMA_JDN) / 7 + 1))
        SEASON="Quadp"; SEASON_LONG="Septuagesima"
        TEMPORA_KEY="Quadp${_pre_week}-${DOW_IDX}"
    elif [ "$DAYS_FROM_EASTER" -lt -14 ]; then
        _quad_week=$(((TODAY_JDN - ASH_WEDNESDAY_JDN) / 7 + 1))
        SEASON="Quad"; SEASON_LONG="Lent"
        TEMPORA_KEY="Quad${_quad_week}-${DOW_IDX}"
    elif [ "$DAYS_FROM_EASTER" -lt 0 ]; then
        _quad_week=$(((TODAY_JDN - ASH_WEDNESDAY_JDN) / 7 + 1))
        SEASON="Quad5"; SEASON_LONG="Passiontide"
        TEMPORA_KEY="Quad${_quad_week}-${DOW_IDX}"
    elif [ "$DAYS_FROM_EASTER" -lt 49 ]; then
        _pasc_week=$((DAYS_FROM_EASTER / 7))
        SEASON="Pasch"; SEASON_LONG="Paschal Time"
        TEMPORA_KEY="Pasc${_pasc_week}-${DOW_IDX}"
    elif [ "$DAYS_FROM_EASTER" -lt 56 ]; then
        SEASON="Pent"; SEASON_LONG="After Pentecost"
        TEMPORA_KEY="Pent01-${DOW_IDX}"
    else
        _pent_week=$(((TODAY_JDN - PENTECOST_JDN) / 7 + 1))
        [ "$_pent_week" -gt 24 ] && _pent_week=24
        SEASON="Pent"; SEASON_LONG="After Pentecost"
        TEMPORA_KEY=$(printf 'Pent%02d-%d' "$_pent_week" "$DOW_IDX")
    fi
}

get_season

get_season_section_key() {
    case "$SEASON" in
        Adv)   echo "Adv" ;;
        Nat)   echo "Nat" ;;
        Epi)   echo "Epi" ;;
        Quadp) echo "Quad" ;;
        Quad)  echo "Quad" ;;
        Quad5) echo "Quad5" ;;
        Pasch) echo "Pasch" ;;
        *)     echo "" ;;
    esac
}

SEASON_KEY=$(get_season_section_key)

# ─── Core functions ───────────────────────────────────────────────

get_section() {
    _file="$1"; _section="$2"
    [ -f "$_file" ] || return 0
    awk -v sect="[$_section]" '
        $0 == sect { found=1; next }
        /^\[/ && found { exit }
        found && !/^\$/ && !/^@/ { print }
    ' "$_file"
}

get_section_raw() {
    _file="$1"; _section="$2"
    [ -f "$_file" ] || return 0
    awk -v sect="[$_section]" '
        $0 == sect { found=1; next }
        /^\[/ && found { exit }
        found && !/^@/ { print }
    ' "$_file"
}

format_text() {
    sed 's/^v\. /  /
         s/^r\. /  /
         s/^V\. /  ℣. /
         s/^R\. /  ℟. /
         s/^R\.br\. /  ℟. /
         s/^R\.br /  ℟. /
         s/^_$//
         s/^\* /  /
         s/^\$Deo gratias/  ℟. Thanks be to God./
         s/^\$Tu autem/  ℣. But thou, O Lord, have mercy upon us.\n  ℟. Thanks be to God./
         s/^\$Per Dominum/  Through Jesus Christ thy Son our Lord. ℟. Amen./
         s/^\$Per eumdem/  Through the same Jesus Christ our Lord. ℟. Amen./
         s/^\$Oremus/  ℣. Let us pray./
         s/^\$ant//
         s/^!\(.*\)/  [\1]/
         s/^&Gloria1/  ℣. Glory be to the Father, and to the Son, and to the Holy Ghost./
         s/^&Gloria/  ℣. Glory be to the Father, and to the Son, and to the Holy Ghost.\n  ℟. As it was in the beginning, is now, and ever shall be, world without end. Amen./
         s/^&teDeum//
         s|^/:.*:/||
         s/^\$/  /' | grep -v '^$'
}

print_psalm() {
    _num="$1"; _from="$2"; _to="$3"
    _file="$PSALMS/Psalm${_num}.txt"
    [ -f "$_file" ] || return 0
    if [ -n "$_from" ] && [ -n "$_to" ]; then
        printf '\n  Psalm %s:%s-%s\n\n' "$_num" "$_from" "$_to"
        awk -v from="$_from" -v to="$_to" '
        /^[0-9]+:[0-9]/ {
            split($0, a, ":"); vstr = a[2]; gsub(/[^0-9].*/, "", vstr); v = vstr + 0
            if (v >= from+0 && v <= to+0) {
                line = $0; sub(/^[0-9]+:[0-9]+[a-z]? /, "", line)
                gsub(/\$ant/, "", line)
                if (line != "") print "  " line
            }
        }' "$_file"
    else
        printf '\n  Psalm %s\n\n' "$_num"
        awk '/^[0-9]+:[0-9]/ {
            line = $0; sub(/^[0-9]+:[0-9]+[a-z]? /, "", line)
            gsub(/\$ant/, "", line)
            if (line != "") print "  " line
        }
        /^\(/ { print "  " $0 }' "$_file"
    fi
}

parse_and_print_psalm() {
    _ref=$(echo "$1" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/^\[//;s/\]$//;s/'//g")
    [ -z "$_ref" ] && return 0
    _pnum=$(echo "$_ref" | sed 's/(.*//'); _range=$(echo "$_ref" | grep -o '([^)]*)' | tr -d '()')
    if [ -n "$_range" ]; then
        _from=$(echo "$_range" | cut -d- -f1 | sed 's/[a-z]*$//')
        _to=$(echo "$_range" | cut -d- -f2 | sed 's/[a-z]*$//')
        print_psalm "$_pnum" "$_from" "$_to"
    else
        print_psalm "$_pnum" "" ""
    fi
}

print_psalm_list() {
    echo "$1" | tr ',' '\n' | while IFS= read -r _pref; do
        _pref=$(echo "$_pref" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$_pref" ] && continue
        echo "$_pref" | grep -q '^\[' && continue
        echo "$_pref" | grep -qE '^;;' && continue
        parse_and_print_psalm "$_pref"
    done
}

get_collect() {
    _collect=""
    [ -f "$TEMPORA/${TEMPORA_KEY}.txt" ] && _collect=$(get_section_raw "$TEMPORA/${TEMPORA_KEY}.txt" "Oratio")
    if [ -z "$_collect" ] && [ "$DOW_IDX" -ne 0 ]; then
        _sun_key=$(echo "$TEMPORA_KEY" | sed "s/-${DOW_IDX}\$/-0/")
        [ -f "$TEMPORA/${_sun_key}.txt" ] && _collect=$(get_section_raw "$TEMPORA/${_sun_key}.txt" "Oratio")
    fi
    echo "$_collect"
}

get_saint_name() {
    _sf="$SANCTI/${MM_DD}.txt"
    [ -f "$_sf" ] || return 0
    get_section "$_sf" "Officium" | head -1
}

print_header() {
    _label="$1"; _saint=$(get_saint_name)
    printf '\n%s\n\n' "══════════════════════════════════════"
    printf '  %s\n' "$_label"
    printf '  %s\n' "$DISPLAY_DATE"
    printf '  %s\n' "$SEASON_LONG"
    [ -n "$_saint" ] && printf '  %s\n' "$_saint"
    printf '\n%s\n\n' "══════════════════════════════════════"
}

print_closing() {
    printf '\n  ── Closing ──\n\n'
    printf '  ℣. Dómine, exáudi oratiónem meam.\n'
    printf '  ℟. Et clamor meus ad te véniat.\n\n'
    _collect=$(get_collect)
    if [ -n "$_collect" ]; then
        printf '  ── Collect ──\n\n'
        printf '  ℣. Let us pray.\n\n'
        echo "$_collect" | format_text
        printf '\n'
    fi
    printf '\n  ℣. Benedicámus Dómino.\n'
    printf '  ℟. Deo grátias.\n\n'
    printf '  ℣. Fidélium ánimæ, per misericórdiam Dei,\n'
    printf '     requiéscant in pace.\n'
    printf '  ℟. Amen.\n'
    printf '\n%s\n' "══════════════════════════════════════"
}

print_gloria() {
    printf '\n  ℣. Glory be to the Father, and to the Son,\n'
    printf '     and to the Holy Ghost.\n'
    printf '  ℟. As it was in the beginning, is now, and ever shall be,\n'
    printf '     world without end. Amen.\n'
}

# ─── MATINS ───────────────────────────────────────────────────────
print_matins() {
    print_header "Matins — Office of Readings"

    printf '  ℣. O Lord, ✠ open thou my lips.\n'
    printf '  ℟. And my mouth shall declare thy praise.\n\n'

    # Invitatory
    printf '  ── Invitatory ──\n\n'
    _invit_key="Invit"
    case "$SEASON" in
        Adv)   _invit_key="Invit Adv" ;;
        Quad)  _invit_key="Invit Quad" ;;
        Quad5) _invit_key="Invit Quad5_" ;;
        Pasch) _invit_key="Invit Pasch" ;;
    esac
    _invit=$(get_section "$SPECIAL/Matutinum Special.txt" "$_invit_key")
    if [ -z "$_invit" ]; then
        _invit=$(get_section "$SPECIAL/Matutinum Special.txt" "Invit")
    fi
    if [ -n "$_invit" ]; then
        _inv_line=$(echo "$_invit" | grep "^${DOW}" | head -1)
        if [ -n "$_inv_line" ]; then
            printf '  Ant. %s\n\n' "$(echo "$_inv_line" | sed 's/^[^=]*= //')"
        else
            printf '  Ant. %s\n\n' "$(echo "$_invit" | head -1)"
        fi
    fi

    # Invitatory Psalm 94
    printf '  Psalm 94 (Venite exsultémus)\n\n'
    awk '/^94:[0-9]/ {
        line = $0; sub(/^[0-9]+:[0-9]+[a-z]? /, "", line)
        gsub(/\$ant/, "", line)
        if (line != "") print "  " line
    }' "$PSALMS/Psalm94C.txt"
    print_gloria
    printf '\n'

    # Hymn
    printf '  ── Hymn ──\n\n'
    _hymn_key="Day${DOW_IDX} Hymnus"
    case "$SEASON" in
        Adv)   _hymn_key="Hymnus Adv" ;;
        Quad)  _hymn_key="Hymnus Quad" ;;
        Quad5) _hymn_key="Hymnus Quad5" ;;
        Pasch) _hymn_key="Hymnus Pasch" ;;
    esac
    _hymn=$(get_section "$SPECIAL/Matutinum Special.txt" "$_hymn_key")
    [ -n "$_hymn" ] && echo "$_hymn" | format_text
    printf '\n'

    # Nocturns — psalms from Psalmi matutinum
    _mat_section="Day${DOW_IDX}"
    _mat_psalms=$(get_section_raw "$PSALMI/Psalmi matutinum.txt" "$_mat_section")
    if [ -z "$_mat_psalms" ]; then
        _mat_psalms=$(get_section_raw "$PSALMI/Psalmi matutinum.txt" "Daya${DOW_IDX}")
    fi

    if [ -n "$_mat_psalms" ]; then
        _line_num=0
        _nocturn=0
        echo "$_mat_psalms" | while IFS= read -r _line; do
            [ -z "$_line" ] && continue
            if echo "$_line" | grep -q ';;'; then
                if [ "$_line_num" -eq 0 ]; then
                    _nocturn=1; printf '\n  ═══ Nocturn I ═══\n'
                elif [ "$_line_num" -eq 6 ]; then
                    _nocturn=2; printf '\n  ═══ Nocturn II ═══\n'
                elif [ "$_line_num" -eq 12 ]; then
                    _nocturn=3; printf '\n  ═══ Nocturn III ═══\n'
                fi
                _ant=$(echo "$_line" | sed 's/;;.*//')
                _prefs=$(echo "$_line" | sed 's/.*;;//')
                [ -n "$_ant" ] && printf '\n  Ant. %s\n' "$_ant"
                echo "$_prefs" | tr ';' '\n' | while IFS= read -r _p; do
                    _p=$(echo "$_p" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/'//g")
                    [ -z "$_p" ] && continue
                    parse_and_print_psalm "$_p"
                done
                print_gloria
                _line_num=$((_line_num + 1))
            elif echo "$_line" | grep -q '^V\.'; then
                printf '\n  %s\n' "$(echo "$_line" | sed 's/^V\./℣./')"
            elif echo "$_line" | grep -q '^R\.'; then
                printf '  %s\n' "$(echo "$_line" | sed 's/^R\./℟./')"
            fi
        done
    fi

    # Lessons
    printf '\n\n  ── Lessons ──\n'
    _tf="$TEMPORA/${TEMPORA_KEY}.txt"
    if [ ! -f "$_tf" ] && [ "$DOW_IDX" -ne 0 ]; then
        _tf="$TEMPORA/$(echo "$TEMPORA_KEY" | sed "s/-${DOW_IDX}\$/-0/").txt"
    fi
    if [ -f "$_tf" ]; then
        for _ln in 1 2 3; do
            _lesson=$(get_section_raw "$_tf" "Lectio${_ln}")
            if [ -n "$_lesson" ]; then
                printf '\n  ── Lesson %s ──\n\n' "$_ln"
                echo "$_lesson" | format_text
                printf '\n'
            fi
        done
    fi

    # Te Deum on Sundays (not in Lent)
    if [ "$DOW_IDX" -eq 0 ] && [ "$SEASON" != "Quad" ] && [ "$SEASON" != "Quad5" ]; then
        printf '\n  ── Te Deum ──\n\n'
        get_section "$PRAYERS" "Te Deum" | format_text
        printf '\n'
    fi

    print_closing
}

# ─── LAUDS ────────────────────────────────────────────────────────
print_lauds() {
    print_header "Lauds — Morning Prayer"

    printf '  ℣. O God, ✠ come to my assistance.\n'
    printf '  ℟. O Lord, make haste to help me.\n'
    print_gloria
    printf '\n'

    # Hymn
    printf '  ── Hymn ──\n\n'
    _hymn=""
    [ -n "$SEASON_KEY" ] && _hymn=$(get_section "$SPECIAL/Major Special.txt" "Hymnus ${SEASON_KEY} Laudes")
    [ -z "$_hymn" ] && _hymn=$(get_section "$SPECIAL/Major Special.txt" "Hymnus Day${DOW_IDX} Laudes")
    [ -n "$_hymn" ] && echo "$_hymn" | format_text
    printf '\n'

    # Psalms
    printf '  ── Psalms ──\n'
    _ps=$(get_section_raw "$PSALMI/Psalmi major.txt" "Day${DOW_IDX} Laudes1")
    if [ -n "$_ps" ]; then
        echo "$_ps" | while IFS= read -r _line; do
            [ -z "$_line" ] && continue
            if echo "$_line" | grep -q ';;'; then
                _ant=$(echo "$_line" | sed 's/;;.*//')
                _pref=$(echo "$_line" | sed 's/.*;;//')
                [ -n "$_ant" ] && printf '\n  Ant. %s\n' "$_ant"
                echo "$_pref" | tr ';' '\n' | while IFS= read -r _p; do
                    _p=$(echo "$_p" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/'//g")
                    [ -z "$_p" ] && continue
                    parse_and_print_psalm "$_p"
                done
                print_gloria
            fi
        done
    fi
    printf '\n'

    # Little Chapter
    printf '  ── Little Chapter ──\n\n'
    _cap=""
    [ -n "$SEASON_KEY" ] && _cap=$(get_section_raw "$SPECIAL/Major Special.txt" "${SEASON_KEY} Laudes_")
    [ -z "$_cap" ] && { [ "$DOW_IDX" -eq 0 ] && _cap=$(get_section_raw "$SPECIAL/Major Special.txt" "Dominica Laudes") || _cap=$(get_section_raw "$SPECIAL/Major Special.txt" "Feria Laudes"); }
    [ -n "$_cap" ] && echo "$_cap" | format_text
    printf '\n'

    # Responsory
    printf '  ── Responsory ──\n\n'
    _resp=""
    [ -n "$SEASON_KEY" ] && _resp=$(get_section_raw "$SPECIAL/Major Special.txt" "Responsory ${SEASON_KEY} Laudes")
    [ -z "$_resp" ] && { [ "$DOW_IDX" -eq 0 ] && _resp=$(get_section_raw "$SPECIAL/Major Special.txt" "Responsory Dominica Laudes_") || _resp=$(get_section_raw "$SPECIAL/Major Special.txt" "Responsory Feria Laudes"); }
    [ -n "$_resp" ] && echo "$_resp" | format_text
    printf '\n'

    # Benedictus antiphon
    _ant2=""
    [ -f "$TEMPORA/${TEMPORA_KEY}.txt" ] && _ant2=$(get_section "$TEMPORA/${TEMPORA_KEY}.txt" "Ant 2")
    if [ -z "$_ant2" ] && [ "$DOW_IDX" -ne 0 ]; then
        _sk=$(echo "$TEMPORA_KEY" | sed "s/-${DOW_IDX}\$/-0/")
        [ -f "$TEMPORA/${_sk}.txt" ] && _ant2=$(get_section "$TEMPORA/${_sk}.txt" "Ant 2")
    fi
    if [ -n "$_ant2" ]; then
        printf '  ── Canticle of Zachary (Benedictus) ──\n\n'
        printf '  Ant. %s\n' "$_ant2"
        print_psalm "231" "" ""
        print_gloria
        printf '\n'
    fi

    print_closing
}

# ─── PRIME ────────────────────────────────────────────────────────
print_prime() {
    print_header "Prime — First Hour"

    printf '  ℣. O God, ✠ come to my assistance.\n'
    printf '  ℟. O Lord, make haste to help me.\n'
    print_gloria
    printf '\n'

    # Hymn
    printf '  ── Hymn ──\n\n'
    get_section "$SPECIAL/Prima Special.txt" "Hymnus Prima" | format_text
    printf '\n'

    # Psalms
    printf '  ── Psalms ──\n'
    _pd=$(get_section "$PSALMI/Psalmi minor.txt" "Prima")
    if [ -n "$_pd" ]; then
        _dl=$(echo "$_pd" | grep "^${DOW}" | head -1)
        if [ -n "$_dl" ]; then
            _ant=$(echo "$_dl" | sed 's/^[^=]*= //')
            [ -n "$_ant" ] && printf '\n  Ant. %s\n' "$_ant"
            _next=$(echo "$_pd" | grep -A1 "^${DOW}" | tail -1)
            echo "$_next" | grep -qE '^[0-9]' && print_psalm_list "$_next"
        fi
    fi
    print_gloria
    printf '\n'

    # Little Chapter
    printf '  ── Little Chapter ──\n\n'
    _ck=""
    case "$SEASON" in Adv|Nat|Epi|Quad|Quad5|Pasch) _ck="$SEASON" ;; *) [ "$DOW_IDX" -eq 0 ] && _ck="Dominica" || _ck="Per Annum" ;; esac
    _cap=$(get_section_raw "$SPECIAL/Prima Special.txt" "$_ck")
    [ -z "$_cap" ] && { [ "$DOW_IDX" -eq 0 ] && _cap=$(get_section_raw "$SPECIAL/Prima Special.txt" "Dominica") || _cap=$(get_section_raw "$SPECIAL/Prima Special.txt" "Feria"); }
    [ -n "$_cap" ] && echo "$_cap" | format_text
    printf '\n'

    # Responsory
    printf '  ── Responsory ──\n\n'
    _resp=$(get_section_raw "$SPECIAL/Prima Special.txt" "Responsory")
    [ -n "$_resp" ] && echo "$_resp" | format_text
    printf '\n'

    print_closing
}

# ─── MINOR HOURS ──────────────────────────────────────────────────
print_minor_hour() {
    _hour="$1"; _label="$2"
    print_header "$_label"

    printf '  ℣. O God, ✠ come to my assistance.\n'
    printf '  ℟. O Lord, make haste to help me.\n'
    print_gloria
    printf '\n'

    # Hymn
    printf '  ── Hymn ──\n\n'
    get_section "$SPECIAL/Minor Special.txt" "Hymnus $_hour" | format_text
    printf '\n'

    # Psalms
    printf '  ── Psalms ──\n'
    _pd=$(get_section "$PSALMI/Psalmi minor.txt" "$_hour")
    if [ -n "$_pd" ]; then
        _dl=$(echo "$_pd" | grep "^${DOW}" | head -1)
        [ -z "$_dl" ] && _dl=$(echo "$_pd" | grep "^Sabato" | head -1)
        if [ -n "$_dl" ]; then
            _ant=$(echo "$_dl" | sed 's/^[^=]*= //')
            printf '\n  Ant. %s\n' "$_ant"
            _next=$(echo "$_pd" | grep -A1 "^${DOW}" | tail -1)
            [ -z "$_next" ] && _next=$(echo "$_pd" | grep -A1 "^Sabato" | tail -1)
            echo "$_next" | grep -qE '^[0-9]' && print_psalm_list "$_next"
        fi
    fi
    print_gloria
    printf '\n'

    # Little Chapter
    printf '  ── Little Chapter ──\n\n'
    _cap=""
    if [ -n "$SEASON_KEY" ]; then
        _cap=$(get_section_raw "$SPECIAL/Minor Special.txt" "${SEASON_KEY} $_hour")
        [ -z "$_cap" ] && _cap=$(get_section_raw "$SPECIAL/Minor Special.txt" "${SEASON_KEY} ${_hour}_")
    fi
    if [ -z "$_cap" ]; then
        [ "$DOW_IDX" -eq 0 ] && { _cap=$(get_section_raw "$SPECIAL/Minor Special.txt" "Dominica $_hour"); [ -z "$_cap" ] && _cap=$(get_section_raw "$SPECIAL/Minor Special.txt" "Dominica ${_hour}_"); } \
        || { _cap=$(get_section_raw "$SPECIAL/Minor Special.txt" "Feria $_hour"); [ -z "$_cap" ] && _cap=$(get_section_raw "$SPECIAL/Minor Special.txt" "Feria ${_hour}_"); }
    fi
    [ -n "$_cap" ] && echo "$_cap" | format_text
    printf '\n'

    # Responsory
    printf '  ── Responsory ──\n\n'
    _resp=""
    [ -n "$SEASON_KEY" ] && _resp=$(get_section_raw "$SPECIAL/Minor Special.txt" "Responsory breve ${SEASON_KEY} $_hour")
    if [ -z "$_resp" ]; then
        [ "$DOW_IDX" -eq 0 ] && _resp=$(get_section_raw "$SPECIAL/Minor Special.txt" "Responsory breve Dominica $_hour") \
        || _resp=$(get_section_raw "$SPECIAL/Minor Special.txt" "Responsory breve Feria $_hour")
    fi
    [ -n "$_resp" ] && echo "$_resp" | format_text
    printf '\n'

    # Versicle
    printf '  ── Versicle ──\n\n'
    _vers=""
    if [ -n "$SEASON_KEY" ]; then
        _vers=$(get_section "$SPECIAL/Minor Special.txt" "Versum ${SEASON_KEY} $_hour")
        [ -z "$_vers" ] && _vers=$(get_section "$SPECIAL/Minor Special.txt" "Versum ${SEASON_KEY} ${_hour}_")
    fi
    if [ -z "$_vers" ]; then
        [ "$DOW_IDX" -eq 0 ] && { _vers=$(get_section "$SPECIAL/Minor Special.txt" "Versum Dominica $_hour"); [ -z "$_vers" ] && _vers=$(get_section "$SPECIAL/Minor Special.txt" "Versum Dominica ${_hour}_"); } \
        || _vers=$(get_section "$SPECIAL/Minor Special.txt" "Versum Feria $_hour")
    fi
    [ -n "$_vers" ] && echo "$_vers" | format_text
    printf '\n'

    print_closing
}

# ─── VESPERS ──────────────────────────────────────────────────────
print_vespers() {
    print_header "Vespers — Evening Prayer"

    printf '  ℣. O God, ✠ come to my assistance.\n'
    printf '  ℟. O Lord, make haste to help me.\n'
    print_gloria
    printf '\n'

    # Hymn
    printf '  ── Hymn ──\n\n'
    _hymn=""
    [ -n "$SEASON_KEY" ] && _hymn=$(get_section "$SPECIAL/Major Special.txt" "Hymnus ${SEASON_KEY} Vespera")
    [ -z "$_hymn" ] && _hymn=$(get_section "$SPECIAL/Major Special.txt" "Hymnus Day${DOW_IDX} Vespera")
    [ -n "$_hymn" ] && echo "$_hymn" | format_text
    printf '\n'

    # Psalms
    printf '  ── Psalms ──\n'
    _ps=$(get_section_raw "$PSALMI/Psalmi major.txt" "Day${DOW_IDX} Vespera")
    if [ -n "$_ps" ]; then
        echo "$_ps" | while IFS= read -r _line; do
            [ -z "$_line" ] && continue
            if echo "$_line" | grep -q ';;'; then
                _ant=$(echo "$_line" | sed 's/;;.*//')
                _pref=$(echo "$_line" | sed 's/.*;;//')
                [ -n "$_ant" ] && printf '\n  Ant. %s\n' "$_ant"
                echo "$_pref" | tr ';' '\n' | while IFS= read -r _p; do
                    _p=$(echo "$_p" | sed "s/^[[:space:]]*//;s/[[:space:]]*$//;s/'//g")
                    [ -z "$_p" ] && continue
                    parse_and_print_psalm "$_p"
                done
                print_gloria
            fi
        done
    fi
    printf '\n'

    # Little Chapter
    printf '  ── Little Chapter ──\n\n'
    _cap=""
    [ -n "$SEASON_KEY" ] && { _cap=$(get_section_raw "$SPECIAL/Major Special.txt" "${SEASON_KEY} Vespera"); [ -z "$_cap" ] && _cap=$(get_section_raw "$SPECIAL/Major Special.txt" "${SEASON_KEY} Vespera_"); }
    [ -z "$_cap" ] && { [ "$DOW_IDX" -eq 0 ] && _cap=$(get_section_raw "$SPECIAL/Major Special.txt" "Dominica Vespera_") || _cap=$(get_section_raw "$SPECIAL/Major Special.txt" "Responsory Feria Vespera_"); }
    [ -n "$_cap" ] && echo "$_cap" | format_text
    printf '\n'

    # Responsory
    printf '  ── Responsory ──\n\n'
    _resp=""
    [ -n "$SEASON_KEY" ] && { _resp=$(get_section_raw "$SPECIAL/Major Special.txt" "Responsory ${SEASON_KEY} Vespera"); [ -z "$_resp" ] && _resp=$(get_section_raw "$SPECIAL/Major Special.txt" "Responsory ${SEASON_KEY} Vespera_"); }
    [ -z "$_resp" ] && { [ "$DOW_IDX" -eq 0 ] && _resp=$(get_section_raw "$SPECIAL/Major Special.txt" "Responsory Dominica Vespera") || _resp=$(get_section_raw "$SPECIAL/Major Special.txt" "Responsory Feria Vespera_"); }
    [ -n "$_resp" ] && echo "$_resp" | format_text
    printf '\n'

    # Magnificat
    _ant3=""
    [ -f "$TEMPORA/${TEMPORA_KEY}.txt" ] && _ant3=$(get_section "$TEMPORA/${TEMPORA_KEY}.txt" "Ant 3")
    if [ -z "$_ant3" ] && [ "$DOW_IDX" -ne 0 ]; then
        _sk=$(echo "$TEMPORA_KEY" | sed "s/-${DOW_IDX}\$/-0/")
        [ -f "$TEMPORA/${_sk}.txt" ] && _ant3=$(get_section "$TEMPORA/${_sk}.txt" "Ant 3")
    fi
    if [ -n "$_ant3" ]; then
        printf '  ── Canticle of Our Lady (Magnificat) ──\n\n'
        printf '  Ant. %s\n' "$_ant3"
        print_psalm "232" "" ""
        print_gloria
        printf '\n'
    fi

    print_closing
}

# ─── COMPLINE ─────────────────────────────────────────────────────
print_compline() {
    print_header "Compline — Night Prayer"

    # Short lesson
    printf '  ── Short Lesson ──\n\n'
    get_section "$SPECIAL/Minor Special.txt" "Lectio Completorium" | format_text
    printf '\n\n'

    printf '  ℣. Turn us then, ✠ O God, our saviour.\n'
    printf '  ℟. And let thy anger cease from us.\n\n'
    printf '  ℣. O God, ✠ come to my assistance.\n'
    printf '  ℟. O Lord, make haste to help me.\n'
    print_gloria
    printf '\n'

    # Hymn
    printf '  ── Hymn ──\n\n'
    get_section "$SPECIAL/Minor Special.txt" "Hymnus Completorium" | format_text
    printf '\n'

    # Psalms
    printf '  ── Psalms ──\n'
    _cd=$(get_section "$PSALMI/Psalmi minor.txt" "Completorium")
    if [ -n "$_cd" ]; then
        _dl=$(echo "$_cd" | grep "^${DOW}" | head -1)
        [ -z "$_dl" ] && _dl=$(echo "$_cd" | grep "^Dominica" | head -1)
        if [ -n "$_dl" ]; then
            _ant=$(echo "$_dl" | sed 's/^[^=]*= //')
            [ -n "$_ant" ] && printf '\n  Ant. %s\n' "$_ant"
            _next=$(echo "$_cd" | grep -A1 "^${DOW}" | tail -1)
            [ -z "$_next" ] && _next=$(echo "$_cd" | grep -A1 "^Dominica" | tail -1)
            echo "$_next" | grep -qE '^[0-9]' && print_psalm_list "$_next"
        fi
    fi
    print_gloria
    printf '\n'

    # Little Chapter
    printf '  ── Little Chapter ──\n\n'
    get_section_raw "$SPECIAL/Minor Special.txt" "Completorium_" | format_text
    printf '\n'

    # Responsory
    printf '  ── Responsory ──\n\n'
    get_section_raw "$SPECIAL/Minor Special.txt" "Responsory Completorium" | format_text
    printf '\n'

    # Nunc Dimittis
    printf '  ── Canticle of Simeon (Nunc Dimittis) ──\n\n'
    _cant=$(get_section "$SPECIAL/Minor Special.txt" "Ant 4")
    [ -n "$_cant" ] && printf '  Ant. %s\n\n' "$_cant"
    print_psalm "233" "" ""
    print_gloria
    printf '\n'

    # Collect
    printf '  ── Collect ──\n\n'
    printf '  ℣. Let us pray.\n\n'
    get_section "$PRAYERS" "Oratio Visita_" | format_text
    printf '\n'
    printf '  Through Jesus Christ our Lord. ℟. Amen.\n\n'

    printf '  ℣. Benedicámus Dómino.\n'
    printf '  ℟. Deo grátias.\n\n'
    printf '  May almighty God grant us a quiet night and a perfect end.\n'
    printf '  ℟. Amen.\n\n'

    # Marian Antiphon (varies by season)
    printf '  ── Marian Antiphon ──\n\n'
    case "$SEASON" in
        Adv|Nat)
            printf '  Alma Redemptoris Mater\n\n'
            printf '  O loving Mother of our Redeemer,\n'
            printf '  gate of heaven, star of the sea,\n'
            printf '  hasten to aid thy fallen people\n'
            printf '  who strive to rise once more.\n'
            printf '  Thou who didst bring forth thy holy Creator,\n'
            printf '  while all nature marvelled,\n'
            printf '  Virgin before and after\n'
            printf '  thou didst receive that Ave from the mouth of Gabriel;\n'
            printf '  have mercy on us sinners.\n' ;;
        Quad|Quad5|Quadp)
            printf '  Ave, Regína Cælórum\n\n'
            printf '  Hail, O Queen of Heaven enthroned.\n'
            printf '  Hail, by Angels Mistress owned.\n'
            printf '  Root of Jesse, Gate of Morn\n'
            printf '  Whence the world'"'"'s true light was born.\n\n'
            printf '  Glorious Virgin, joy to thee,\n'
            printf '  Loveliest whom in Heaven they see;\n'
            printf '  Fairest thou, where all are fair,\n'
            printf '  Plead with Christ our sins to spare.\n' ;;
        Pasch)
            printf '  Regína Cæli\n\n'
            printf '  O Queen of Heaven, rejoice, alleluia:\n'
            printf '  For he whom thou didst merit to bear, alleluia,\n'
            printf '  Has risen as he said, alleluia.\n'
            printf '  Pray for us to God, alleluia.\n' ;;
        *)
            printf '  Salve, Regína\n\n'
            printf '  Hail, holy Queen, Mother of mercy,\n'
            printf '  our life, our sweetness, and our hope.\n'
            printf '  To thee do we cry, poor banished children of Eve.\n'
            printf '  To thee do we send up our sighs,\n'
            printf '  mourning and weeping in this valley of tears.\n'
            printf '  Turn then, most gracious advocate,\n'
            printf '  thine eyes of mercy toward us.\n'
            printf '  And after this our exile,\n'
            printf '  show unto us the blessed fruit of thy womb, Jesus.\n'
            printf '  O clement, O loving, O sweet Virgin Mary.\n' ;;
    esac

    printf '\n%s\n' "══════════════════════════════════════"
}

# ─── Auto-detect hour ─────────────────────────────────────────────
auto_hour() {
    _h=$(date "+%H")
    if   [ "$_h" -lt 5 ];  then echo "matins"
    elif [ "$_h" -lt 7 ];  then echo "lauds"
    elif [ "$_h" -lt 9 ];  then echo "prime"
    elif [ "$_h" -lt 11 ]; then echo "terce"
    elif [ "$_h" -lt 13 ]; then echo "sext"
    elif [ "$_h" -lt 15 ]; then echo "none"
    elif [ "$_h" -lt 19 ]; then echo "vespers"
    else echo "compline"
    fi
}

# ─── Usage ─────────────────────────────────────────────────────────
usage() {
    cat <<'EOF'
opus — Traditional Divine Office (1962 Breviary)

Usage: opus [hour] [options]

Hours:
  matins       Office of Readings (midnight–5am)
  lauds        Morning Prayer (5–7am)
  prime        First Hour (7–9am)
  terce        Third Hour (9–11am)
  sext         Sixth Hour (11am–1pm)
  none         Ninth Hour (1–3pm)
  vespers      Evening Prayer (3–7pm)
  compline     Night Prayer (7pm–midnight)

Options:
  --date YYYY-MM-DD   Office for a specific date
  --english           English only (default)
  --latin             Latin only (planned — data pending)
  --help              Show this help

Without arguments, prints the current hour based on time of day.
EOF
}

# ─── Latin mode notice ────────────────────────────────────────────
if [ "$LANG_MODE" = "latin" ]; then
    echo "Note: Latin texts not yet available in data set. Showing English."
    LANG_MODE="english"
fi

# ─── Main dispatch ────────────────────────────────────────────────
[ -z "$HOUR" ] && HOUR=$(auto_hour)

case "$HOUR" in
    matins|matutinum)       print_matins ;;
    lauds|laudes)           print_lauds ;;
    prime|prima)            print_prime ;;
    terce|tertia)           print_minor_hour "Tertia" "Terce — Third Hour" ;;
    sext|sexta)             print_minor_hour "Sexta" "Sext — Sixth Hour" ;;
    none|nona)              print_minor_hour "Nona" "None — Ninth Hour" ;;
    vespers|vespera)        print_vespers ;;
    compline|completorium)  print_compline ;;
    help)                   usage ;;
    *)                      usage; exit 1 ;;
esac
