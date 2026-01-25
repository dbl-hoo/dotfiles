#!/usr/bin/env bash
set -e

echo "==> Installing managed bashrc"

TARGET="$HOME/.bashrc"
cp bashrc "$TARGET"
chmod 644 "$TARGET"

echo "==> Ensuring fastfetch is installed"

if ! command -v fastfetch >/dev/null 2>&1; then
  if command -v apt >/dev/null 2>&1; then
    echo "Installing fastfetch via apt"
    sudo apt update
    sudo apt install -y fastfetch
  else
    echo "fastfetch not installed (unsupported package manager)"
  fi
else
  echo "fastfetch already installed"
fi

echo "==> Done"
echo "Log out and back in to see changes."