_vpn_complete() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  local commands="config check-config set-default import-zip import list up down status version update"

  _vpn_connection_names() {
    local creds="$HOME/.config/cg-vpn/credentials.json"
    if [[ -f "$creds" ]]; then
      jq -r 'keys[]' "$creds" 2>/dev/null
    else
      nmcli -t -f NAME,TYPE con show 2>/dev/null | grep ':vpn$' | cut -d: -f1
    fi
  }

  case "$COMP_CWORD" in
    1)
      COMPREPLY=($(compgen -W "$commands" -- "$cur"))
      ;;
    2)
      case "$prev" in
        up|down|set-default)
          COMPREPLY=($(compgen -W "$(_vpn_connection_names)" -- "$cur"))
          ;;
        config)
          COMPREPLY=($(compgen -W "set" -- "$cur"))
          ;;
        import|import-zip)
          COMPREPLY=($(compgen -f -- "$cur"))
          ;;
      esac
      ;;
    3)
      case "${COMP_WORDS[1]}" in
        import|import-zip)
          COMPREPLY=($(compgen -W "$(_vpn_connection_names)" -- "$cur"))
          ;;
        config)
          [[ "$prev" == "set" ]] && COMPREPLY=($(compgen -f -- "$cur"))
          ;;
      esac
      ;;
  esac
}

complete -F _vpn_complete vpn
