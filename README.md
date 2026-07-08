# cg-vpn

A minimal Bash utility to manage multiple OpenVPN connections on Linux, using NetworkManager under the hood.

Built primarily for [CyberGhost VPN](https://www.cyberghostvpn.com), but since it relies on standard OpenVPN profiles and `nmcli`, it should work with any VPN provider that supplies `.ovpn` config files.

> **Tested on:** Ubuntu 24.04 with CyberGhost VPN. Other providers and distributions may work but have not been tested.

Built for personal use, but feel free to use it, fork it, and improve it.

---

## Why this exists

Many VPN providers (including CyberGhost) supply `.ovpn` config files but no native Linux CLI. Managing several connections (different countries, different accounts) through NetworkManager's GUI quickly becomes tedious. This script wraps `nmcli` into a simple `vpn` command with tab completion.

---

## Requirements

- Linux with [NetworkManager](https://networkmanager.dev/)
- `nmcli` (usually installed with NetworkManager)
- `jq` (for credential management)
- `unzip` (only needed for `vpn import-zip`)
- Bash 4+

Install dependencies on Debian/Ubuntu:

```bash
sudo apt install network-manager jq unzip
```

---

## Installation

```bash
git clone https://github.com/yourname/cg-vpn.git
cd cg-vpn
./install.sh
source ~/.bashrc
```

This will:
- Add `vpn` as a command in `~/.local/bin/`
- Install bash tab completion in `~/.local/share/bash-completion/completions/`

---

## Setup

### 1. Create a credentials file

CyberGhost generates a unique username/password per device and protocol. Get them from your [CyberGhost account](https://my.cyberghostvpn.com/) under **My Devices → Configure Device → OpenVPN**.

Create `~/.config/cg-vpn/credentials.json`:

```json
{
  "canada": {
    "username": "your_cyberghost_username",
    "password": "your_cyberghost_password",
    "default": true
  },
  "usa": {
    "username": "another_username",
    "password": "another_password"
  }
}
```

Or import an existing JSON file:

```bash
vpn config set ~/my-credentials.json
```

### 2. Import a VPN profile

Download the `.ovpn` file (or `.zip`) from CyberGhost, then import it using the matching credential name:

```bash
vpn import ~/downloads/canada.ovpn canada
# or
vpn import-zip ~/downloads/canada.zip canada
```

### 3. Connect

```bash
vpn up           # uses the default connection
vpn up canada    # explicit connection name
```

---

## Usage

```
vpn config                        # show current credentials file
vpn config set <file.json>        # import a credentials file
vpn check-config                  # verify credentials file
vpn set-default <connection_name> # set the default connection
vpn import <file.ovpn> <name>     # import an OpenVPN profile
vpn import-zip <file.zip> <name>  # import from a zip archive
vpn list                          # list all VPN connections
vpn up [connection_name]          # connect (uses default if omitted)
vpn down [connection_name]        # disconnect
vpn status                        # show active VPN connections
```

Tab completion works for both commands and connection names:

```bash
vpn up <TAB>         # lists your connection names
vpn set-default <TAB>
```

---

## Notes

- IPv6 is disabled on connect and restored on disconnect, to prevent leaks.
- Credentials are stored locally in `~/.config/cg-vpn/credentials.json` (chmod 600).
- Only one VPN connection is active at a time — `vpn up` automatically disconnects any existing VPN before connecting.

---

## Possible improvements

Contributions and suggestions are welcome. Some ideas:

- [ ] `vpn add <name>` interactive wizard to add credentials without editing JSON manually
- [ ] `vpn remove <name>` to delete both the nmcli connection and credentials entry
- [ ] DNS leak check after connecting
- [ ] Support for other VPN protocols (WireGuard)
- [ ] Fish / Zsh completion scripts

---

## License

[MIT](LICENSE) — free to use, modify, and distribute.
