#!/usr/bin/env bash
# build-deb.sh — Builds a .deb package for cgvpn
# Usage: ./build-deb.sh [version]
#   version defaults to 1.0.0
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="${1:-1.0.0}"
PKG_NAME="cgvpn"
ARCH="all"
DEB_FILE="${SCRIPT_DIR}/${PKG_NAME}_${VERSION}_${ARCH}.deb"

# ── Temp staging directory ────────────────────────────────────────────────────
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
PKG_DIR="$STAGING/$PKG_NAME"

# ── Directory layout ──────────────────────────────────────────────────────────
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/lib/cgvpn"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/bash-completion/completions"
mkdir -p "$PKG_DIR/usr/share/doc/cgvpn"

# ── DEBIAN/control ────────────────────────────────────────────────────────────
cat > "$PKG_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Architecture: $ARCH
Maintainer: Olivier <olivier@example.com>
Depends: jq, network-manager, unzip
Description: CyberGhost VPN manager for NetworkManager
 A minimal Bash utility to manage multiple OpenVPN connections on Linux
 using nmcli. Works with any provider that supplies .ovpn config files.
EOF

# ── Main script ───────────────────────────────────────────────────────────────
install -m 755 "$SCRIPT_DIR/cg-vpn.sh" "$PKG_DIR/usr/lib/cgvpn/cg-vpn.sh"

# Thin wrapper so the real script lives under /usr/lib and stays editable
cat > "$PKG_DIR/usr/bin/vpn" <<'WRAPPER'
#!/usr/bin/env bash
exec /usr/lib/cgvpn/cg-vpn.sh "$@"
WRAPPER
chmod 755 "$PKG_DIR/usr/bin/vpn"

# ── Bash completion ───────────────────────────────────────────────────────────
install -m 644 "$SCRIPT_DIR/completion.bash" \
  "$PKG_DIR/usr/share/bash-completion/completions/vpn"

# ── Docs ──────────────────────────────────────────────────────────────────────
install -m 644 "$SCRIPT_DIR/README.md" "$PKG_DIR/usr/share/doc/cgvpn/README.md"

# ── Build ─────────────────────────────────────────────────────────────────────
dpkg-deb --build --root-owner-group "$PKG_DIR" "$DEB_FILE"

echo ""
echo "Package built: $DEB_FILE"
echo ""
echo "Install with:"
echo "  sudo apt install $DEB_FILE"
echo "    (or: sudo dpkg -i $DEB_FILE)"
echo ""
echo "Remove with:"
echo "  sudo apt remove $PKG_NAME"
