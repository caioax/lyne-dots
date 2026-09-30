#!/bin/bash
# =============================================================================
# ask.sh - Questionnaire: every question before anything is installed
# =============================================================================
# A question is a function that draws its screen, stores the result in
# ANSWERS[id] and returns 0 (next), 1 (back), 2 (quit) or 3 (skipped: it
# doesn't apply to the answers so far). ask_run walks the list with Esc going
# back, so every answer can be changed until the review screen.
# Usage: source ui.sh, then this file
# =============================================================================

declare -A ANSWERS
ASK_POS=""

# ask_run <question function>...  → 0 when the last one was answered, 1 when
# the user quit
ask_run() {
    local -a questions=("$@")
    local i=0 dir=1 rc
    while ((i < ${#questions[@]})); do
        ASK_POS="$((i + 1))/${#questions[@]}"
        "${questions[i]}"
        rc=$?
        case $rc in
        0) dir=1 i=$((i + 1)) ;;
        1) dir=-1 i=$((i - 1)) ;;
        2) return 1 ;;
        3) i=$((i + dir)) ;;
        esac
        # Back from (or skipping past) the first question stays on it
        if ((i < 0)); then
            i=0 dir=1
        fi
    done
    return 0
}

# Splits "value|label|description|default" options into the arrays of the
# calling function (ask_multi/ask_single declare them local)
_ask_parse() {
    local opt v l d on
    for opt in "$@"; do
        IFS='|' read -r v l d on <<<"$opt"
        _vals+=("$v") _labels+=("$l") _descs+=("$d") _defaults+=("${on:-0}")
        ((${#l} + 2 > _label_w)) && _label_w=$((${#l} + 2))
    done
}

# A question can draw more between its text and its options: it sets
# ASK_EXTRA (local) to a function that adds the lines
_ask_header() {
    ui_frame
    ui_banner
    ui_title "$1" "$ASK_POS"
    if [[ -n "$2" ]]; then
        ui_text "$2" "$C_DIM"
    fi
    UI_LINES+=("")
    if [[ -n "${ASK_EXTRA:-}" ]]; then
        "$ASK_EXTRA"
    fi
}

# One list row: cursor, mark, padded label and the description in what's left
_ask_row() {
    local selected=$1 mark=$2 label=$3 desc=$4
    local cursor="  " style=""
    if ((selected)); then
        cursor="$G_CURSOR "
        style=$C_SEL
    fi
    local rest=$((UI_WIDTH - 2 - ${#mark} - 1 - _label_w))
    local line="$style$cursor$mark $(ui_pad "$label" "$_label_w")$C_RESET"
    ((rest > 3)) && line+="$C_DIM$(ui_fit "$desc" "$rest")$C_RESET"
    ui_add "$line"
}

# ask_multi <id> <title> <text> <option>...
# Checkboxes; ANSWERS[id] = the checked values separated by spaces
ask_multi() {
    local id=$1 title=$2 text=$3
    shift 3
    local -a _vals=() _labels=() _descs=() _defaults=() on=()
    local _label_w=0 cur=0 i n
    _ask_parse "$@"
    n=${#_vals[@]}

    for ((i = 0; i < n; i++)); do
        if [[ -v "ANSWERS[$id]" ]]; then
            [[ " ${ANSWERS[$id]} " == *" ${_vals[i]} "* ]] && on[i]=1 || on[i]=0
        else
            on[i]=${_defaults[i]}
        fi
    done

    while true; do
        _ask_header "$title" "$text"
        for ((i = 0; i < n; i++)); do
            local mark=$G_OFF
            ((on[i])) && mark=$G_ON
            _ask_row $((i == cur)) "$mark" "${_labels[i]}" "${_descs[i]}"
        done
        ui_hint "$G_UPDOWN move $G_DOT space toggle $G_DOT a all/none $G_DOT enter next $G_DOT esc back $G_DOT q quit"
        ui_flush

        ui_read_key
        case $KEY in
        up | k) cur=$(((cur - 1 + n) % n)) ;;
        down | j | tab) cur=$(((cur + 1) % n)) ;;
        space | x) on[cur]=$((1 - on[cur])) ;;
        a | A)
            # All on, or all off when everything already is
            local all=1 v=1
            for ((i = 0; i < n; i++)); do ((on[i])) || all=0; done
            ((all)) && v=0
            for ((i = 0; i < n; i++)); do on[i]=$v; done
            ;;
        enter | right | l)
            local picked=()
            for ((i = 0; i < n; i++)); do ((on[i])) && picked+=("${_vals[i]}"); done
            ANSWERS[$id]="${picked[*]}"
            return 0
            ;;
        esc | left | h) return 1 ;;
        q | Q | eof) return 2 ;;
        esac
    done
}

# ask_single <id> <title> <text> <option>...
# One choice (the option marked default, or the saved answer, starts
# selected); ANSWERS[id] = its value
ask_single() {
    local id=$1 title=$2 text=$3
    shift 3
    local -a _vals=() _labels=() _descs=() _defaults=()
    local _label_w=0 cur=0 i n
    _ask_parse "$@"
    n=${#_vals[@]}

    for ((i = 0; i < n; i++)); do
        if [[ -v "ANSWERS[$id]" ]]; then
            [[ "${ANSWERS[$id]}" == "${_vals[i]}" ]] && cur=$i
        elif ((_defaults[i])); then
            cur=$i
        fi
    done

    while true; do
        _ask_header "$title" "$text"
        for ((i = 0; i < n; i++)); do
            local mark=$G_RADIO_OFF
            ((i == cur)) && mark=$G_RADIO_ON
            _ask_row $((i == cur)) "$mark" "${_labels[i]}" "${_descs[i]}"
        done
        ui_hint "$G_UPDOWN move $G_DOT enter choose $G_DOT esc back $G_DOT q quit"
        ui_flush

        ui_read_key
        case $KEY in
        up | k) cur=$(((cur - 1 + n) % n)) ;;
        down | j | tab) cur=$(((cur + 1) % n)) ;;
        enter | space | right | l)
            ANSWERS[$id]=${_vals[cur]}
            return 0
            ;;
        esc | left | h) return 1 ;;
        q | Q | eof) return 2 ;;
        esac
    done
}

# ask_review <title> <text> <"Key|value">...
# Summary before installing: enter starts, esc goes back to change something
ask_review() {
    local title=$1 text=$2
    shift 2
    local row key value key_w=11
    _ask_header "$title" "$text"
    for row in "$@"; do
        key=${row%%|*} value=${row#*|}
        ui_add "$C_BOLD$(ui_pad "$key" "$key_w")$C_RESET$(ui_fit "$value" $((UI_WIDTH - key_w)))"
    done
    ui_hint "enter start $G_DOT esc back $G_DOT q quit"
    ui_flush

    while true; do
        ui_read_key
        case $KEY in
        enter) return 0 ;;
        esc | left | h) return 1 ;;
        q | Q | eof) return 2 ;;
        esac
    done
}

# Answers from a file instead of the screens (--answers): "id=value" lines,
# "#" comments. Unknown ids are kept; missing ones take the defaults
ask_load() {
    local line key
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        key=${line%%=*}
        key=${key//[[:space:]]/}
        ANSWERS[$key]=${line#*=}
    done <"$1"
}
