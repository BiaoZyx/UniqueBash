#=================================
#                         _
# _ __ _ _ ___ _ __  _ __| |_
#| '_ \ '_/ _ \ '  \| '_ \  _|
#| .__/_| \___/_|_|_| .__/\__|
#|_|                |_|
#      (~/.bashrc.d/prompt.bashrc)
# ================================

# If using tty, set prompt style to 1, else set to 2
if [[ "$(tty 2>/dev/null)" == *tty* ]]; then
    PROMPT_STYLE=2
else
    PROMPT_STYLE=1
fi

export SHOW_USER_HOST=0  # 1 to show user@host in prompt, 0 to hide

# Flyline - enhanced Bash experience
if [[ -f "$HOME/.local/lib/libflyline.so" ]]; then
    enable -f "$HOME/.local/lib/libflyline.so" flyline
fi

# ------------------------------
# Prompt core: colors, git, builders
# ------------------------------

# Colors Definitions
R='\[\033[0m\]'     # Reset
BR='\[\033[30m\]'   # Black - Regular
BB='\[\033[1;30m\]' # Black - Bold

# Unused Colors Definitions
#R1='\[\033[1;31m\]' # Red
#G1='\[\033[1;32m\]' # Green
#Y1='\[\033[1;33m\]' # Yellow
#B1='\[\033[1;34m\]' # Blue
#M1='\[\033[1;35m\]' # Magenta
#C1='\[\033[1;36m\]' # Cyan

W1='\[\033[1;37m\]' # White

# Dark Colors Definitions
dR1='\[\033[0;31m\]' # Dark Red
dG1='\[\033[0;32m\]' # Dark Green
dY1='\[\033[0;33m\]' # Dark Yellow
dB1='\[\033[0;34m\]' # Dark Blue
dM1='\[\033[0;35m\]' # Dark Magenta
dC1='\[\033[0;36m\]' # Dark Cyan

# Background Colors Definitions
BG_BLACK='\[\033[40m\]'
BG_RED='\[\033[41m\]'
BG_GREEN='\[\033[42m\]'
BG_YELLOW='\[\033[43m\]'
BG_BLUE='\[\033[44m\]'
BG_MAGENTA='\[\033[45m\]'
BG_CYAN='\[\033[46m\]'
BG_WHITE='\[\033[47m\]'

# Prompt style and git cache settings
GIT_PROMPT_CACHE_TTL=3
#PROMPT_STYLE=1
PROMPT_STYLE_COUNT=2
PROMPT_STYLE_NAMES=(Powerline ASCII)
__git_info_cache=''
__git_info_cache_time=0
__git_info_cwd=''

# PWD Collapse Function
_collapse() {
  local home_dir path
  if [[ -n "$HOME" && "$HOME" == /* ]]; then
    home_dir=$(cd -- "$HOME" 2>/dev/null && pwd) || home_dir=""
  else
    home_dir=""
  fi

  path="${PWD:-$(pwd -P 2>/dev/null)}"
  [[ -z "$path" ]] && return

  if [[ "$path" == "/" ]]; then
    echo "/"
    return
  elif [[ -n "$home_dir" && "$path" == "$home_dir" ]]; then
    echo "~"
    return
  fi

  if [[ -n "$home_dir" && "$path" == "$home_dir/"* ]]; then
    path="~${path:${#home_dir}}"
  fi

  local leading_slash=""
  if [[ "$path" == /* ]]; then
    leading_slash="/"
    path="${path#/}"
  fi

  local IFS="/"
  local segments=()
  read -ra segments <<< "$path"
  local last_index=$(( ${#segments[@]} - 1 ))
  local result="${leading_slash}"

  for i in "${!segments[@]}"; do
    local seg="${segments[i]}"
    if (( i < last_index )); then
      if [[ -n "$seg" ]]; then
        if [[ "$seg" == .* ]]; then
          result+="${seg:0:2}"
        else
          result+="${seg:0:1}"
        fi
      fi
      result+="/"
    else
      result+="$seg"
    fi
  done

  echo "$result"
}

# Git Branch and Status Function
_git_info() {
    local now
    now=$(date +%s)
    # Cache by PWD + TTL: skip all git forks when cwd unchanged
    if [[ -n "$__git_info_cache_time" && "$PWD" == "$__git_info_cwd" && $((now - __git_info_cache_time)) -lt GIT_PROMPT_CACHE_TTL ]]; then
        printf '%s' "$__git_info_cache"
        return
    fi
    __git_info_cwd="$PWD"

    # Only compute inside a git work tree to avoid needless overhead
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        __git_info_cache=''
        __git_info_cache_time=$now
        return
    fi

    local b r="" s line xy x y tok
    b=$(git branch --show-current 2>/dev/null) || return

    # GIT_OPTIONAL_LOCKS=0 lowers git status lock overhead
    s=$(GIT_OPTIONAL_LOCKS=0 git status --porcelain=2 --branch --untracked-files=normal 2>/dev/null) || return

    local ahead=0 behind=0
    local staged=0 unstaged=0 untracked=0 conflicts=0
    local ab_line=""
    while IFS= read -r line; do
        case "$line" in
            \#\ branch.ab\ *)
                ab_line="${line#\# branch.ab }"
                ;;
            "1 "*|"2 "*)
                # porcelain=2: 2nd field is the XY status pair
                xy="${line#* }"; xy="${xy%% *}"
                x="${xy:0:1}"; y="${xy:1:1}"
                [[ "$x" != "." && "$x" != " " ]] && staged=$((staged + 1))
                [[ "$y" != "." && "$y" != " " ]] && unstaged=$((unstaged + 1))
                ;;
            "u "*)
                conflicts=$((conflicts + 1))
                ;;
            "?"*)
                untracked=$((untracked + 1))
                ;;
        esac
    done <<< "$s"

    if [[ -n "$ab_line" ]]; then
        for tok in $ab_line; do
            case "$tok" in
                +*) ahead="${tok#+}";;
                -*) behind="${tok#-}";;
            esac
        done
        ahead="${ahead:-0}"; behind="${behind:-0}"
    fi

    # Build status string
    if (( conflicts > 0 )); then
        r=" ✦${conflicts}"          # Conflicts take precedence
    elif (( staged + unstaged + untracked == 0 )); then
        r=" ○"                       # Clean
    else
        r=" ●"                       # Dirty
        (( staged > 0 ))    && r="$r +${staged}"
        (( unstaged > 0 ))  && r="$r ~${unstaged}"
        (( untracked > 0 )) && r="$r …${untracked}"  # Untracked files
    fi

    # Branch name + status
    local branch_info=" ${b}${r}"

    # Remote sync status
    if (( ahead > 0 )); then
        branch_info="$branch_info ↑${ahead}"
    fi
    if (( behind > 0 )); then
        branch_info="$branch_info ↓${behind}"
    fi

    __git_info_cache="$branch_info"
    __git_info_cache_time=$now

    printf '%s' "$branch_info "
}

# ====== Core: Build Powerline Prompt ======
_powerline_prompt() {
  # Use the passed exit code / pipe status; fall back to saved context
  local ec="${1:-${_saved_ec:-$?}}"
  local pstatus=()
  if [[ $# -gt 1 ]]; then
    shift
    pstatus=("$@")
  else
    pstatus=("${_saved_ps[@]}")
    if [[ ${#pstatus[@]} -eq 0 ]]; then
      pstatus=("${PIPESTATUS[@]}")
    fi
  fi

  # Any non-zero in the pipeline (e.g. true|false|true) must be reported
  local any_err=0 s
  for s in "${pstatus[@]}"; do
    if (( s != 0 )); then any_err=1; break; fi
  done

  local git="$(_git_info)"

  # Status icon and color
  local st_icon=""
  local st_bg="${BG_GREEN}"
  local st_fg="${BR}"
  local st_arr_fg="${dG1}"

  if (( any_err )); then
    if [[ ${#pstatus[@]} -gt 1 ]]; then
      local IFS='|'
      local pipe_info="${pstatus[*]}"
      st_icon=" ✕${pipe_info}"
    else
      st_icon=" ✕${ec}"
    fi
    st_bg="${BG_RED}"
    st_fg="${W1}"
    st_arr_fg="${dR1}"
  fi

  # Build Powerline segments
  local s1 s2 s3 s4
  if [[ $SHOW_USER_HOST -eq 1 ]]; then
    s1="${BG_CYAN}${BB} \u@\h ${R}${dC1}${BG_BLUE}"
  else
    s1=""
  fi
  s2="${BG_BLUE}${W1} $(_collapse) ${R}"
  s3=""
  if [[ -n "$git" ]]; then
    s2+="${BG_BLACK}${dB1}${BG_YELLOW}"
    s3="${BG_YELLOW}${BR}${git}${R}${BG_BLACK}${dY1}${st_bg}"
  else
    s3="${BG_BLACK}${dB1}${st_bg}"
  fi
  # Status segment: show icon only when there is an error
  if [[ -n "$st_icon" ]]; then
    s4="${st_bg}${st_fg}${st_icon} ${R}${st_arr_fg}"
  else
    s4="${st_bg}${st_fg}${R}${st_arr_fg}"   # keep a space so the arrow isn't tight
  fi

  PS1="${R}\[\033[1;30m\]───${R}\n${s1}${s2}${s3}${s4} ${R}"
}

__prompt_set_powerline() {
  PROMPT_STYLE=1
}

__prompt_set_ascii() {
  PROMPT_STYLE=2
}

__prompt_toggle_style() {
  if [[ $PROMPT_STYLE -eq 1 ]]; then
    PROMPT_STYLE=2
  else
    PROMPT_STYLE=1
  fi
}

_build_prompt() {
  # Saved exit code and pipe status from PROMPT_COMMAND
  local ec="${_saved_ec:-0}"
  local pstatus=()
  if [[ ${#_saved_ps[@]} -gt 0 ]]; then
    pstatus=("${_saved_ps[@]}")
  else
    pstatus=("${PIPESTATUS[@]}")
  fi

  local any_err=0 s
  for s in "${pstatus[@]}"; do
    if (( s != 0 )); then any_err=1; break; fi
  done

  case "$PROMPT_STYLE" in
    1)
      _powerline_prompt "${ec}" "${pstatus[@]}"
      ;;
    2)
      # === 8-color ASCII style ===
      local git="$(_git_info)"
      local path="$(_collapse)"
      local git_part=""

      if [[ -n "$git" ]]; then
        local clean_git="${git///}"
        clean_git="${clean_git//○/-}"
        clean_git="${clean_git//●/*}"
        clean_git="${clean_git//✦/!}"
        clean_git="${clean_git//↑/[ahead]}"
        clean_git="${clean_git//↓/[behind]}"
        clean_git="${clean_git//+/ +}"
        clean_git="${clean_git//~/ ~}"
        clean_git="${clean_git//…/ .}"
        # Collapse repeated spaces and trim (pure bash, no forks)
        while [[ "$clean_git" == *"  "* ]]; do clean_git="${clean_git//  / }"; done
        clean_git="${clean_git#"${clean_git%%[![:space:]]*}"}"
        clean_git="${clean_git%"${clean_git##*[![:space:]]}"}"
        git_part=" (${dY1}${clean_git}${R})"
      fi

      # Exit code / pipeline status
      local st=""
      if (( any_err )); then
        if [[ ${#pstatus[@]} -gt 1 ]]; then
          local IFS='|'
          local pipe_info="${pstatus[*]}"
          st=" ${dR1}[✕${pipe_info}]${R}"
        else
          st=" ${dR1}[${ec}]${R}"
        fi
      fi

      # Prompt `>` color reflects any error in the pipeline
      local prompt_color="${dG1}"
      if (( any_err )); then
        prompt_color="${dR1}"
      fi

      PS1="\n${dC1}\u${R}@${dM1}\h${R}:${dB1}${path}${R}${git_part}${st}\n${prompt_color}> ${R}"
      ;;
  esac
}
