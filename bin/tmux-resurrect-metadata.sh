#!/usr/bin/env bash
d=$'\t'

pane_format() {
  local format
  format+="#{session_name}"
  format+="${d}"
  format+="#{window_index}"
  format+="${d}"
  format+="#{pane_index}"
  format+="${d}"
  format+="#{pane_id}"
  echo "$format"
}

# pane_virtualenv() {
#   local pane_id="$1"
#   tmux show-window-option -v -t "$pane_id" "@virtualenv$pane_id" 2>/dev/null || true
# }

get_window_ids() {
  tmux list-windows -F '#{window_id}'
}

get_panes() {
  tmux list-panes -a -F "$(pane_format)"
}

dump_metadata() {
  # local session_name window_number pane_index pane_id
  # tmux list-panes -a -F "$(pane_format)" |
  # while IFS=$d read -r session_name window_number pane_index pane_id; do
  #   # not saving panes from grouped sessions
  #   if is_session_grouped "$session_name"; then
  #     continue
  #   fi
  #   local venv
  #   venv=$(pane_virtualenv "$pane_id")

  #   if [ -n "$venv" ]; then
  #     echo "virtualenv${d}${session_name}${d}${window_number}${d}${pane_index}${d}${venv}"
  #   fi
  # done

  # dump global options
  tmux show-options -g |
  awk -F' ' '{ st = index($0," "); if ($1 ~ "@resurrect-metadata-" ) print "metadata" "\t" "global" "\t" $1 "\t" substr($0,st+1)}'

  # TODO dump window options

  # dump pane options
  local session_name window_index pane_index pane_id prefix
  while IFS="$d" read -r session_name window_index pane_index pane_id
  do
    prefix="metadata${d}pane${d}$session_name${d}$window_index${d}$pane_index${d}"
    tmux show-options -p -t "$pane_id" |
      awk -F' ' '{ st = index($0," "); if ($1 ~ "@resurrect-metadata-" ) print "'"$prefix"'" $1 "\t" substr($0,st+1)}'
  done < <(get_panes)
}

restore_metadata() {
  local _1 _2 session_name window_index pane_index key value
  awk 'BEGIN { FS="\t"; OFS="\t" } $1 == "metadata" && $2 == "pane"' "$(last_resurrect_file)" |
  while read -r _1 _2 session_name window_index pane_index key value; do
    tmux set-option -p -t "$session_name:$window_index.$pane_index" "$key" "$( eval "echo -e -n $value" )"
  done
  awk 'BEGIN { FS="\t"; OFS="\t" } $1 == "metadata" && $2 == "global"' "$(last_resurrect_file)" |
  while read -r _1 _2 key value; do
    tmux set-option -g "$key" "$( eval "echo -e -n $value" )"
  done
}

install() {
  CURRENT_DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  tmux set-option -gq "@resurrect-hook-post-save-layout" "$CURRENT_DIR/tmux-resurrect-metadata.sh save"
  tmux set-option -gq "@resurrect-hook-pre-restore-history" "$CURRENT_DIR/tmux-resurrect-metadata.sh restore"
}

_add_line_to_file() {
  local pattern="$1"
  local line="$2"
  local file="$3"

  sed -i.bak -e "s#.*/$pattern.*#$line#" "$file"
  if ! grep -q "$pattern" "$file"; then
    # Not there, add to end
    echo "$line" >> "$file"
  fi
}


main() {
  local path
  path=$(dirname "$(tmux show-option -gv "@resurrect-restore-script-path")")
  source "$path/variables.sh"
  source "$path/helpers.sh"

  # set after we have sourced the helpers from tmux-resurrect
  set -eu -o pipefail
  shopt -s inherit_errexit

  case "$1" in
    install)
      install
      ;;
    # set-meta)
    #   # Are we currently inside a tmux session
    #   if [ -n "${TMUX_PANE-}" ]; then
    #     tmux set-option "@resurrect-metadata-${TMUX_PANE}-$2" "$3"
    #   fi
    #   ;;
    # remove-meta)
    #   if [ -n "${TMUX_PANE-}" ]; then
    #     tmux set-option -u "@resurrect-metadata-${TMUX_PANE}-$2"
    #   fi
    #   ;;
    save)
      dump_metadata >> "$2"
      ;;
    restore)
      restore_metadata
      ;;
  esac
}

main "$@"
