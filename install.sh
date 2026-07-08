#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/cg-vpn.sh"
BIN_DIR="$HOME/.local/bin"
CMD_NAME="vpn"
BASHRC="$HOME/.bashrc"

echo "Installing $CMD_NAME..."

# Rendre le script exécutable
chmod +x "$SCRIPT"

# Créer ~/.local/bin si besoin
mkdir -p "$BIN_DIR"

# Créer ou mettre à jour le lien symbolique
ln -sf "$SCRIPT" "$BIN_DIR/$CMD_NAME"
echo "  ✅ Symlink: $BIN_DIR/$CMD_NAME → $SCRIPT"

# Ajouter ~/.local/bin au PATH si absent du .bashrc
if ! grep -q 'HOME/.local/bin' "$BASHRC" 2>/dev/null; then
  echo '' >> "$BASHRC"
  echo '# Added by cg-vpn install.sh' >> "$BASHRC"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASHRC"
  echo "  ✅ Added ~/.local/bin to PATH in $BASHRC"
else
  echo "  ✓  ~/.local/bin already in $BASHRC"
fi

# Installer la complétion bash
COMPLETION_DIR="$HOME/.local/share/bash-completion/completions"
mkdir -p "$COMPLETION_DIR"
cp "$SCRIPT_DIR/completion.bash" "$COMPLETION_DIR/$CMD_NAME"
echo "  ✅ Bash completion: $COMPLETION_DIR/$CMD_NAME"

echo ""
echo "Done."
echo "  → Open a new terminal to use '$CMD_NAME' with tab completion."
echo "    (or run: source ~/.bashrc  if ~/.local/bin was not yet in your PATH)"
