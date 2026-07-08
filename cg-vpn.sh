#!/usr/bin/env bash
set -euo pipefail

# === CONFIGURATION CYBERGHOST ===
CREDENTIALS_FILE="$HOME/.config/cg-vpn/credentials.json"

get_default() {
  jq -r 'to_entries[] | select(.value.default == true) | .key' "$CREDENTIALS_FILE" 2>/dev/null | head -n 1 || true
}

get_creds() {
  local name="$1"
  if ! jq -e --arg n "$name" '.[$n]' "$CREDENTIALS_FILE" > /dev/null 2>&1; then
    echo "ERROR: no credentials found for '$name' in $CREDENTIALS_FILE"
    echo "Add an entry like: { \"$name\": { \"username\": \"...\", \"password\": \"...\" } }"
    exit 1
  fi
  VPN_USERNAME="$(jq -r --arg n "$name" '.[$n].username' "$CREDENTIALS_FILE")"
  VPN_PASSWORD="$(jq -r --arg n "$name" '.[$n].password' "$CREDENTIALS_FILE")"
}

cmd="${1:-}"

usage() {
  echo "Usage:"
  echo "  vpn config                        # show current credentials file"
  echo "  vpn config set <file.json>        # import a credentials file"
  echo "  vpn check-config"
  echo "  vpn set-default <connection_name>"
  echo "  vpn import-zip <file.zip> <connection_name>"
  echo "  vpn import <file.ovpn> <connection_name>"
  echo "  vpn list"
  echo "  vpn up [connection_name]          # uses default if omitted"
  echo "  vpn down [connection_name]        # uses active or default if omitted"
  echo "  vpn status"
  echo "  vpn version"
  echo "  vpn update                        # update to latest release (.deb only)"
  exit 1
}

case "$cmd" in

  config)
    subcmd="${2:-}"
    case "$subcmd" in
      set)
        src="${3:-}"
        [[ -n "$src" ]] || { echo "Usage: vpn config set <file.json>"; exit 1; }
        [[ -f "$src" ]] || { echo "ERROR: file not found: $src"; exit 1; }
        jq . "$src" > /dev/null 2>&1 || { echo "ERROR: $src is not valid JSON"; exit 1; }
        mkdir -p "$(dirname "$CREDENTIALS_FILE")"
        chmod 700 "$(dirname "$CREDENTIALS_FILE")"
        cp "$src" "$CREDENTIALS_FILE"
        chmod 600 "$CREDENTIALS_FILE"
        echo "✅ Credentials imported from: $src"
        echo "   Location: $CREDENTIALS_FILE"
        ;;
      "")
        echo "Location: $CREDENTIALS_FILE"
        echo ""
        if [[ -f "$CREDENTIALS_FILE" ]]; then
          cat "$CREDENTIALS_FILE"
        else
          echo "(file not found — run: vpn check-config)"
        fi
        ;;
      *)
        echo "Unknown subcommand: $subcmd"
        echo "Usage: vpn config [set <file.json>]"
        exit 1
        ;;
    esac
    ;;

  check-config)
    echo "Config file location: $CREDENTIALS_FILE"
    if [[ -f "$CREDENTIALS_FILE" ]]; then
      echo "✅ File found."
      echo ""
      echo "Entries:"
      jq -r 'to_entries[] | "\(.key) \(.value.default // false)"' "$CREDENTIALS_FILE" | while read -r key is_default; do
        if [[ "$is_default" == "true" ]]; then
          echo "  - $key  [default]"
        else
          echo "  - $key"
        fi
      done
    else
      echo "❌ File not found."
      echo ""
      read -rp "Create an initialized credentials file? [y/N] " answer
      if [[ "$answer" =~ ^[Yy]$ ]]; then
        mkdir -p "$(dirname "$CREDENTIALS_FILE")"
        chmod 700 "$(dirname "$CREDENTIALS_FILE")"
        cat > "$CREDENTIALS_FILE" <<'EOF'
{
  "connection_name": {
    "username": "your_cyberghost_username",
    "password": "your_cyberghost_password"
  }
}
EOF
        chmod 600 "$CREDENTIALS_FILE"
        echo "✅ Created: $CREDENTIALS_FILE"
        echo "Edit it to replace the placeholder values."
      else
        echo "Aborted."
      fi
    fi
    ;;

  set-default)
    name="${2:-}"
    [[ -n "$name" ]] || usage
    [[ -f "$CREDENTIALS_FILE" ]] || { echo "ERROR: $CREDENTIALS_FILE not found. Run: vpn check-config"; exit 1; }
    if ! jq -e --arg n "$name" '.[$n]' "$CREDENTIALS_FILE" > /dev/null 2>&1; then
      echo "ERROR: no entry '$name' in $CREDENTIALS_FILE"
      exit 1
    fi
    previous="$(get_default)"
    if [[ -n "$previous" && "$previous" != "$name" ]]; then
      echo "Replacing default: $previous → $name"
    fi
    # with_entries ensures exactly one entry has default:true
    updated="$(jq --arg n "$name" '
      with_entries(
        if .key == $n then .value.default = true
        else del(.value.default)
        end
      )' "$CREDENTIALS_FILE")"
    echo "$updated" > "$CREDENTIALS_FILE"
    echo "✅ Default connection set to: $name"
    ;;

  import-zip)
    zipfile="${2:-}"
    name="${3:-}"
    [[ -f "$zipfile" ]] || { echo "ERROR: file not found: $zipfile"; exit 1; }
    [[ -n "$name" ]] || usage

    get_creds "$name"

    certdir="$HOME/.config/cg-vpn/certs/$name"
    mkdir -p "$certdir"
    chmod 700 "$certdir"

    echo "Extracting zip..."
    unzip -q -o "$zipfile" -d "$certdir"

    ovpn="$(find "$certdir" -name "*.ovpn" | head -n 1)"
    [[ -n "$ovpn" ]] || { echo "ERROR: no .ovpn file found in zip"; exit 1; }

    echo "Importing OpenVPN profile from zip..."
    nmcli connection import type openvpn file "$ovpn"

    imported="$(nmcli -t -f NAME con show | tail -n 1)"

    nmcli connection modify "$imported" connection.id "$name"
    nmcli connection modify "$name" vpn.user-name "$VPN_USERNAME"
    nmcli connection modify "$name" vpn.secrets "password=$VPN_PASSWORD"

    echo "✅ Imported as: $name with credentials saved"
    ;;

  import)
    ovpn="${2:-}"
    name="${3:-}"
    [[ -f "$ovpn" ]] || { echo "ERROR: file not found: $ovpn"; exit 1; }
    [[ -n "$name" ]] || usage

    get_creds "$name"

    echo "Importing OpenVPN profile..."
    nmcli connection import type openvpn file "$ovpn"

    imported="$(nmcli -t -f NAME con show | tail -n 1)"

    nmcli connection modify "$imported" connection.id "$name"
    nmcli connection modify "$name" vpn.user-name "$VPN_USERNAME"
    nmcli connection modify "$name" vpn.secrets "password=$VPN_PASSWORD"

    echo "✅ Imported as: $name with credentials saved"
    ;;

  up)
    name="${2:-}"
    if [[ -z "$name" ]]; then
      name="$(get_default)"
      if [[ -z "$name" ]]; then
        echo "ERROR: no connection name given and no default set."
        echo "Use: vpn set-default <connection_name>"
        exit 1
      fi
      echo "Using default connection: $name"
    fi

    # Couper toutes les connexions VPN actives avant de se connecter
    active_vpns="$(nmcli -t -f NAME,TYPE con show --active | grep ':vpn$' | cut -d: -f1 || true)"
    if [[ -n "$active_vpns" ]]; then
      while IFS= read -r vpn; do
        echo "Disconnecting: $vpn"
        nmcli connection down "$vpn"
      done <<< "$active_vpns"
    fi

    echo "Connecting: $name"
    nmcli connection up "$name"

    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null
    echo "✅ Connected (IPv6 disabled to prevent leaks)"
    ;;

  down)
    name="${2:-}"
    if [[ -z "$name" ]]; then
      name="$(nmcli -t -f NAME,TYPE con show --active | grep ':vpn$' | cut -d: -f1 | head -n 1 || true)"
      if [[ -z "$name" ]]; then
        echo "No active VPN connection."
        exit 0
      fi
    fi

    echo "Disconnecting: $name"
    nmcli connection down "$name"

    sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null
    sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0 > /dev/null
    echo "✅ Disconnected (IPv6 restored)"
    ;;

  list)
    echo "Available VPN connections:"
    echo ""
    connections="$(nmcli -t -f NAME,TYPE con show | grep ':vpn$' | cut -d: -f1 || true)"
    if [[ -z "$connections" ]]; then
      echo "  (none imported yet)"
    else
      active="$(nmcli -t -f NAME,TYPE con show --active | grep ':vpn$' | cut -d: -f1 || true)"
      default_conn="$([[ -f "$CREDENTIALS_FILE" ]] && get_default || true)"
      while IFS= read -r name; do
        label=""
        [[ "$name" == "$default_conn" ]] && label="$label [default]"
        echo "$active" | grep -qx "$name" && label="$label [active]"
        echo "    $name$label"
      done <<< "$connections"
    fi
    echo ""
    echo "Examples:"
    if [[ -n "$connections" ]]; then
      first="$(echo "$connections" | head -n 1)"
      echo "  vpn up $first"
      echo "  vpn down $first"
    fi
    echo "  vpn import-zip <file.zip> <connection_name>"
    ;;

  status)
    echo "Active VPN connections:"
    nmcli -t -f NAME,TYPE con show --active | grep vpn || echo "None"
    ;;

  version)
    pkg_version="$(dpkg -s cgvpn 2>/dev/null | grep '^Version:' | cut -d' ' -f2)"
    if [[ -n "$pkg_version" ]]; then
      echo "cgvpn $pkg_version"
    else
      echo "cgvpn dev (source install)"
    fi
    ;;

  update)
    current="$(dpkg -s cgvpn 2>/dev/null | grep '^Version:' | cut -d' ' -f2)"
    if [[ -z "$current" ]]; then
      echo "ERROR: cgvpn was not installed via .deb."
      echo "To update a source install: git pull && ./install.sh"
      exit 1
    fi

    echo "Current version: $current"
    echo "Checking for updates..."

    api="$(curl -fsSL https://api.github.com/repos/revilofr/cgvpn/releases/latest)"
    latest_tag="$(echo "$api" | grep '"tag_name"' | cut -d'"' -f4)"
    latest="${latest_tag#v}"
    download_url="$(echo "$api" | grep browser_download_url | cut -d'"' -f4 | head -1)"

    if [[ "$current" == "$latest" ]]; then
      echo "Already up to date ($current)."
      exit 0
    fi

    echo "New version available: $latest"
    read -rp "Install? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

    tmp="$(mktemp /tmp/cgvpn_XXXXXX.deb)"
    trap 'rm -f "$tmp"' EXIT
    curl -fsSL -o "$tmp" "$download_url"
    sudo apt install "$tmp"
    echo "✅ Updated to $latest"
    ;;

  *)
    usage
    ;;
esac
