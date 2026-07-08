# cg-vpn

A minimal Bash utility to manage multiple OpenVPN connections on Linux, using NetworkManager under the hood.

Built primarily for [CyberGhost VPN](https://www.cyberghostvpn.com), but since it relies on standard OpenVPN profiles and `nmcli`, it should work with any VPN provider that supplies `.ovpn` config files.

> **Tested on:** Ubuntu 24.04 with CyberGhost VPN. Other providers and distributions may work but have not been tested.

Built for personal use, but feel free to use it, fork it, and improve it.

---

## Why this exists

Many VPN providers (including CyberGhost) supply `.ovpn` config files but no native Linux CLI. Managing several connections (different countries, different accounts) through NetworkManager's GUI quickly becomes tedious. This script wraps `nmcli` into a simple `vpn` command with tab completion.

---

## Complete example

```bash
# Import credentials
vpn config set ~/my-credentials.json

# Import a VPN profile from the .zip downloaded directly from CyberGhost (recommended)
vpn import-zip ~/downloads/canada.zip canada

# Set it as default so you can omit the name later
vpn set-default canada

# Check everything looks good
vpn check-config
vpn list

# Connect
vpn up
# ✅ Connected (IPv6 disabled to prevent leaks)

# Check status
vpn status

# Disconnect
vpn down
# ✅ Disconnected (IPv6 restored)
```

---

## Installation

### Install from GitHub Releases (recommended)

Download and install the latest `.deb` package directly:

```bash
curl -fsSL -o /tmp/cgvpn.deb \
  $(curl -fsSL https://api.github.com/repos/revilofr/cgvpn/releases/latest \
    | grep browser_download_url | cut -d'"' -f4 | head -1)
sudo apt install /tmp/cgvpn.deb
```

`apt` installs all required dependencies automatically — no manual setup needed.

Then open a new terminal — `vpn` will be available with tab completion.

Remove with:

```bash
sudo apt remove cgvpn
```

### Install from source (for contributors)

```bash
git clone https://github.com/revilofr/cgvpn.git
cd cgvpn
./install.sh
```

> If `~/.local/bin` was not already in your `PATH`, run `source ~/.bashrc` first.

Dependencies must be installed manually (see [Requirements](#requirements) below).

---

## Requirements

> Only needed for source installs — the `.deb` package handles this automatically.

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

## Publishing a new release

Releases are built and published automatically by GitHub Actions when a version tag is pushed.

```bash
git tag v1.2.3
git push origin v1.2.3
```

This triggers the CI workflow which builds `cgvpn_1.2.3_all.deb` and attaches it to a new GitHub Release.

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

Download the `.zip` directly from CyberGhost (**My Devices → Configure Device → OpenVPN → Download**), then import it using the matching credential name:

```bash
vpn import-zip ~/downloads/canada.zip canada
```

Alternatively, if you only have a `.ovpn` file:

```bash
vpn import ~/downloads/canada.ovpn canada
```

### 3. Connect

```bash
vpn up           # uses the default connection
vpn up canada    # explicit connection name
```

---

## Updating

### Via .deb (recommended install)

```bash
vpn update
```

Checks the latest release on GitHub, asks for confirmation, then downloads and installs the new `.deb` automatically.

### Via source install

```bash
cd ~/path/to/cgvpn
git pull
./install.sh
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
vpn version                       # show installed version
vpn update                        # update to latest release (.deb only)
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
