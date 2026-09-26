#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Bash Theme: REZOR
#
#  Segment colors:
#    status     → black bg  (errors, root, bg jobs)
#    user@host  → black bg, white fg
#    path       → blue bg,  black fg
#    git        → green     (clean & pushed)
#                 magenta   (committed, not pushed)
#                 orange    (staged, not committed)
#                 yellow    (modified/untracked, not staged)
#                 red       (deleted or conflicted files)
#
#  Requires a Powerline-patched / Nerd Font for the  glyph.
#  e.g. MesloLGS NF, FiraCode Nerd Font, JetBrains Mono NF
# ─────────────────────────────────────────────────────────────

PROMPT_DIRTRIM=${PROMPT_DIRTRIM:-2}

SEGMENT_SEPARATOR=$'\ue0b0'
BRANCH_SYMBOL=$'\ue0a0'

# ── ANSI helpers ──────────────────────────────────────────────

_ansi_fg() {
  case $1 in
    black)   printf '\[\e[30m\]' ;;
    red)     printf '\[\e[31m\]' ;;
    green)   printf '\[\e[32m\]' ;;
    yellow)  printf '\[\e[33m\]' ;;
    blue)    printf '\[\e[34m\]' ;;
    magenta) printf '\[\e[38;5;93m\]' ;;
    cyan)    printf '\[\e[36m\]' ;;
    white)   printf '\[\e[37m\]' ;;
    orange)  printf '\[\e[38;5;166m\]' ;;
    default) printf '\[\e[39m\]' ;;
  esac
}

_ansi_bg() {
  case $1 in
    black)   printf '\[\e[40m\]' ;;
    red)     printf '\[\e[41m\]' ;;
    green)   printf '\[\e[42m\]' ;;
    yellow)  printf '\[\e[43m\]' ;;
    blue)    printf '\[\e[44m\]' ;;
    magenta) printf '\[\e[48;5;93m\]' ;; 
    cyan)    printf '\[\e[46m\]' ;;
    white)   printf '\[\e[47m\]' ;;
    orange)  printf '\[\e[48;5;166m\]' ;;
  esac
}

_ansi_reset() { printf '\[\e[0m\]'; }

# ── Segment builder ───────────────────────────────────────────

_CURRENT_BG='NONE'

_segment() {
  local bg=$1 fg=$2 content=$3

  if [[ $_CURRENT_BG == 'NONE' ]]; then
    # first segment
    _PR+="$(_ansi_bg "$bg")$(_ansi_fg "$fg") ${content} "

  elif [[ $_CURRENT_BG != "$bg" ]]; then
    # FIXED: arrow now belongs to PREVIOUS segment (current bg)
    _PR+="$(_ansi_bg "$bg")$(_ansi_fg "$_CURRENT_BG")${SEGMENT_SEPARATOR}"

    # new segment content
    _PR+="$(_ansi_bg "$bg")$(_ansi_fg "$fg") ${content} "

  else
    _PR+="$(_ansi_fg "$fg") ${content} "
  fi

  _CURRENT_BG=$bg
}

_segment_end() {
  _PR+="$(_ansi_reset)$(_ansi_fg "$_CURRENT_BG")${SEGMENT_SEPARATOR}$(_ansi_reset) "
  _CURRENT_BG='NONE'
}

# ── Segments ────────────────────────────────────────────────

_seg_status() {
  local retval=$1
  local symbols=''
  ((retval != 0)) && symbols+="$(_ansi_fg red)✘"
  ((UID == 0)) && symbols+="$(_ansi_fg yellow)⚡"
  compgen -j &>/dev/null && symbols+="$(_ansi_fg cyan)⚙"
  [[ -n $symbols ]] && _segment black default "$symbols"
}

_seg_context() {
  local user
  user=$(whoami)
  if [[ $user != "${DEFAULT_USER:-}" || -n ${SSH_CLIENT:-} ]]; then
    _segment black white "$user@\h"
  fi
}

_seg_dir() {
  _segment blue black '\w'
}

_seg_git() {
  git rev-parse --is-inside-work-tree &>/dev/null || return

  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null \
    || git describe --tags --exact-match 2>/dev/null \
    || git rev-parse --short HEAD 2>/dev/null)

  local deleted=0 conflicted=0 staged=0 modified=0 untracked=0

  while IFS= read -r line; do
    local x="${line:0:1}" y="${line:1:1}"
    [[ $x == D || $y == D ]] && deleted=1
    [[ $x == U || $y == U || $x$y == AA || $x$y == DD ]] && conflicted=1
    [[ $x =~ [MARCT] ]] && staged=1
    [[ $y =~ [MT] ]] && modified=1
    [[ $x$y == '??' ]] && untracked=1
  done < <(git status --porcelain 2>/dev/null)

  local pushed=0
  local remote
  remote=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
  if [[ -n $remote ]]; then
    local ahead
    ahead=$(git rev-list --count "${remote}..HEAD" 2>/dev/null || echo 1)
    [[ $ahead -eq 0 ]] && pushed=1
  fi

  local bg fg
  if   [[ $deleted -eq 1 || $conflicted -eq 1 ]]; then
    bg=red; fg=white
  elif [[ $modified -eq 1 || $untracked -eq 1 ]]; then
    bg=yellow; fg=black
  elif [[ $staged -eq 1 ]]; then
    bg=orange; fg=white
  elif [[ $pushed -eq 0 ]]; then
    bg=magenta; fg=white
  else
    bg=green; fg=black
  fi

  local dirty=''
  [[ $deleted -eq 1 || $conflicted -eq 1 || \
     $modified -eq 1 || $untracked -eq 1 || \
     $staged -eq 1 ]] && dirty=' ●'

  _segment "$bg" "$fg" "${BRANCH_SYMBOL} ${branch}${dirty}"
}

# ── Prompt ───────────────────────────────────────────────────

_build_prompt() {
  local RETVAL=$?
  _CURRENT_BG='NONE'
  _PR=''

  _seg_status "$RETVAL"
  _seg_context
  _seg_dir
  _seg_git
  _segment_end

  PS1=$_PR
}

PROMPT_COMMAND="_build_prompt"
PS2="$(_ansi_fg blue)… $(_ansi_reset)"
