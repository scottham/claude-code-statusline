#!/usr/bin/env bash
# Claude Code native statusline
# Replicates: Model | Ctx% | git-branch | (+lines,-lines)
#             Reset | Session% | Weekly Reset | Weekly%
#
# Setup:
#   chmod +x ~/.claude/statusline.sh
#   Add to ~/.claude/settings.json:
#   { "statusLine": { "type": "command", "command": "~/.claude/statusline.sh" } }

input=$(cat)

# ── ANSI colors ──────────────────────────────────────────────
CYAN='\033[36m'
YELLOW='\033[33m'
MAGENTA='\033[35m'
DIM='\033[2m'
RESET='\033[0m'

SEP="${DIM} | ${RESET}"

# ── Parse JSON ───────────────────────────────────────────────
_jq() { echo "$input" | jq -r "${1} // ${2}" 2>/dev/null; }

model=$(_jq '.model.display_name' '"Unknown"')
ctx_pct=$(_jq '.context_window.used_percentage' '0')
lines_added=$(_jq '.cost.total_lines_added' '0')
lines_removed=$(_jq '.cost.total_lines_removed' '0')
cwd=$(_jq '.workspace.current_dir // .cwd' '""')

session_pct=$(_jq '.rate_limits.five_hour.used_percentage' '0')
five_hour_reset=$(_jq '.rate_limits.five_hour.resets_at' '0')
weekly_pct=$(_jq '.rate_limits.seven_day.used_percentage' '0')
seven_day_reset=$(_jq '.rate_limits.seven_day.resets_at' '0')

# ── Git branch ───────────────────────────────────────────────
git_branch=""
if [ -n "$cwd" ]; then
    git_branch=$(git -C "$cwd" branch --show-current 2>/dev/null)
fi
[ -z "$git_branch" ] && git_branch="no-branch"

# ── Format countdown ─────────────────────────────────────────
fmt_remaining() {
    local ts=$1
    local now
    now=$(date +%s)
    local diff=$(( ts - now ))
    if [ "$diff" -le 0 ]; then
        echo "now"
        return
    fi
    local d=$(( diff / 86400 ))
    local h=$(( (diff % 86400) / 3600 ))
    local m=$(( (diff % 3600) / 60 ))
    if [ "$d" -gt 0 ]; then
        printf "%dd %dhr %dm" "$d" "$h" "$m"
    else
        printf "%dhr %dm" "$h" "$m"
    fi
}

five_hr_str=$(fmt_remaining "$five_hour_reset")
seven_day_str=$(fmt_remaining "$seven_day_reset")

# ── Format numbers ───────────────────────────────────────────
ctx_f=$(printf "%.1f" "$ctx_pct")
session_f=$(printf "%.1f" "$session_pct")
weekly_f=$(printf "%.1f" "$weekly_pct")

lines_added=${lines_added%.*}     # strip decimal if any
lines_removed=${lines_removed%.*}

# ── Line 1: Model | Ctx | Branch | Lines ─────────────────────
printf "${CYAN}Model: %s${RESET}${SEP}" "$model"
printf "${YELLOW}Ctx: %s%%${RESET}${SEP}" "$ctx_f"
printf "${MAGENTA}⌇%s${RESET}${SEP}" "$git_branch"
printf "${YELLOW}(+%s,-%s)${RESET}\n" "$lines_added" "$lines_removed"

# ── Line 2: Reset | Session | Weekly Reset | Weekly ──────────
printf "${CYAN}Reset: %s${RESET}${SEP}" "$five_hr_str"
printf "${YELLOW}Session: %s%%${RESET}${SEP}" "$session_f"
printf "${MAGENTA}Weekly Reset: %s${RESET}${SEP}" "$seven_day_str"
printf "${YELLOW}Weekly: %s%%${RESET}\n" "$weekly_f"
