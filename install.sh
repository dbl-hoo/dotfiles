#!/usr/bin/env bash
set -euo pipefail

# ---------
# CONFIG (edit these)
# ---------
DOTFILES_REPO_SSH="git@github.com:dbl-hoo/dotfiles.git"
DOTFILES_DIR="/home/kirkham/.config/kirkham-dotfiles"
DOTFILES_BRANCH="main"
TARGET_USER="kirkham"

# If you want to allow password auth and not disable it, we won't touch sshd here.
# This script only sets up user/shell/dotfiles.

# ---------
# Helpers
# ---------
log() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33mWARN: %s\033[0m\n" "$*"; }
die() { printf "\n\033[1;31mERROR: %s\033[0m\n" "$*"; exit 1; }

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run this as root (or with sudo)."
  fi
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

# ---------
# Main
# ---------
need_root

log "Detecting OS"
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  echo "OS: ${PRETTY_NAME:-unknown}"
else
  warn "No /etc/os-release found. Continuing anyway."
fi

log "Updating apt + installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

# fastfetch is in Debian 12+; if it's missing we'll fallback to installing from GitHub later.
PKGS=(
  ca-certificates
  curl
  git
  sudo
  zsh
  locales
  tzdata
  openssh-client
  fontconfig
)

# Try to include fastfetch if available
if apt-cache show fastfetch >/dev/null 2>&1; then
  PKGS+=(fastfetch)
else
  warn "fastfetch not found in apt repos. Will install via GitHub release later."
fi

apt-get install -y "${PKGS[@]}"

log "Ensuring locale exists (en_US.UTF-8)"
if ! locale -a | grep -qi '^en_US\.utf8$'; then
  sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen || true
  locale-gen
fi
update-locale LANG=en_US.UTF-8 || true

log "Ensuring user '${TARGET_USER}' exists"
if ! id -u "${TARGET_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${TARGET_USER}"
  passwd "${TARGET_USER}" || true
  warn "User created. You were prompted to set a password. (If you skipped, set it with: passwd ${TARGET_USER})"
else
  echo "User exists: ${TARGET_USER}"
fi

log "Ensuring '${TARGET_USER}' is in sudo group"
usermod -aG sudo "${TARGET_USER}"

log "Setting default shell to zsh for '${TARGET_USER}'"
ZSH_PATH="$(command -v zsh)"
chsh -s "${ZSH_PATH}" "${TARGET_USER}" || true

log "Preparing dotfiles directory: ${DOTFILES_DIR}"
install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_USER}" "$(dirname "${DOTFILES_DIR}")"
if [[ -d "${DOTFILES_DIR}/.git" ]]; then
  log "Dotfiles repo already present; pulling latest"
  sudo -u "${TARGET_USER}" git -C "${DOTFILES_DIR}" fetch --all
  sudo -u "${TARGET_USER}" git -C "${DOTFILES_DIR}" checkout "${DOTFILES_BRANCH}"
  sudo -u "${TARGET_USER}" git -C "${DOTFILES_DIR}" pull --ff-only
else
  log "Cloning dotfiles repo"
  # NOTE: requires that kirkham can auth to GitHub (ssh key or https token).
  sudo -u "${TARGET_USER}" git clone --branch "${DOTFILES_BRANCH}" "${DOTFILES_REPO_SSH}" "${DOTFILES_DIR}"
fi

log "Installing Oh My Zsh for '${TARGET_USER}' (non-interactive)"
OMZ_DIR="/home/${TARGET_USER}/.oh-my-zsh"
if [[ ! -d "${OMZ_DIR}" ]]; then
  sudo -u "${TARGET_USER}" sh -c \
    "RUNZSH=no CHSH=no KEEP_ZSHRC=yes ZSH='${OMZ_DIR}' \
     $(printf '%q' "bash") -c \"$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\""
else
  echo "Oh My Zsh already installed at ${OMZ_DIR}"
fi

log "Installing Powerlevel10k theme (p10k)"
P10K_DIR="${OMZ_DIR}/custom/themes/powerlevel10k"
if [[ ! -d "${P10K_DIR}" ]]; then
  sudo -u "${TARGET_USER}" git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${P10K_DIR}"
else
  echo "Powerlevel10k already installed at ${P10K_DIR}"
fi

log "Linking zsh config from dotfiles repo"
# Expect these paths inside your dotfiles repo:
#   zsh/.zshrc
#   zsh/.p10k.zsh
#   fastfetch/config.jsonc

ZSHRC_SRC="${DOTFILES_DIR}/zsh/.zshrc"
P10K_SRC="${DOTFILES_DIR}/zsh/.p10k.zsh"
FF_SRC="${DOTFILES_DIR}/fastfetch/config.jsonc"

ZSHRC_DST="/home/${TARGET_USER}/.zshrc"
P10K_DST="/home/${TARGET_USER}/.p10k.zsh"

if [[ ! -f "${ZSHRC_SRC}" ]]; then
  warn "Missing ${ZSHRC_SRC}. Create it in your repo."
else
  rm -f "${ZSHRC_DST}"
  ln -s "${ZSHRC_SRC}" "${ZSHRC_DST}"
  chown -h "${TARGET_USER}:${TARGET_USER}" "${ZSHRC_DST}"
fi

if [[ ! -f "${P10K_SRC}" ]]; then
  warn "Missing ${P10K_SRC}. Create it in your repo."
else
  rm -f "${P10K_DST}"
  ln -s "${P10K_SRC}" "${P10K_DST}"
  chown -h "${TARGET_USER}:${TARGET_USER}" "${P10K_DST}"
fi

log "Setting up fastfetch config (symlink)"
FF_DIR="/home/${TARGET_USER}/.config/fastfetch"
install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_USER}" "${FF_DIR}"

if [[ -f "${FF_SRC}" ]]; then
  rm -f "${FF_DIR}/config.jsonc"
  ln -s "${FF_SRC}" "${FF_DIR}/config.jsonc"
  chown -h "${TARGET_USER}:${TARGET_USER}" "${FF_DIR}/config.jsonc"
else
  warn "Missing ${FF_SRC}. Create it in your repo (copied from Mac is fine)."
fi

log "Ensuring fastfetch runs on interactive zsh login (if configured in .zshrc, this is redundant)"
# We won't force-edit your .zshrc (since it's from repo), but we can sanity-check.
if [[ -f "${ZSHRC_SRC}" ]] && ! grep -q 'fastfetch' "${ZSHRC_SRC}"; then
  warn ".zshrc does not reference fastfetch. Add 'fastfetch' (guarded) in your repo zsh/.zshrc if desired."
fi

log "Installing fastfetch if apt didn't provide it"
if ! has_cmd fastfetch; then
  warn "fastfetch not installed via apt. We'll install from GitHub latest release (amd64 only)."

  ARCH="$(dpkg --print-architecture)"
  if [[ "${ARCH}" != "amd64" ]]; then
    warn "Non-amd64 architecture (${ARCH}). Skipping fastfetch GitHub install. Install manually for this arch."
  else
    tmpdir="$(mktemp -d)"
    # Pull latest .deb from GitHub releases
    # This avoids needing jq; we scrape the API.
    url="$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest \
      | grep -Eo 'https://[^"]+amd64\.deb' | head -n1 || true)"
    if [[ -z "${url}" ]]; then
      warn "Could not find fastfetch amd64 .deb from GitHub API. Skipping."
    else
      log "Downloading: ${url}"
      curl -fsSL "${url}" -o "${tmpdir}/fastfetch.deb"
      dpkg -i "${tmpdir}/fastfetch.deb" || apt-get -f install -y
    fi
    rm -rf "${tmpdir}"
  fi
fi

log "Done."
echo
echo "Next:"
echo "  1) Make sure kirkham can auth to GitHub for ${DOTFILES_REPO_SSH} (ssh key or switch repo URL to https)."
echo "  2) Log in as kirkham:  ssh kirkham@<host>"
echo "  3) You should land in zsh + p10k, and fastfetch should run if your repo .zshrc does it."