#!/usr/bin/env bash
set -euo pipefail

# ---------
# CONFIG
# ---------
DOTFILES_REPO_SSH="${DOTFILES_REPO_SSH:-git@github.com:dbl-hoo/dotfiles.git}"
DOTFILES_REPO_HTTPS="${DOTFILES_REPO_HTTPS:-https://github.com/dbl-hoo/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-/home/kirkham/.config/kirkham-dotfiles}"
DOTFILES_BRANCH="${DOTFILES_BRANCH:-main}"
TARGET_USER="${TARGET_USER:-kirkham}"

# ---------
# Helpers
# ---------
log()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\n\033[1;33mWARN: %s\033[0m\n" "$*"; }
die()  { printf "\n\033[1;31mERROR: %s\033[0m\n" "$*"; exit 1; }

need_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    die "Run this as root (or with sudo)."
  fi
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

run_as_user() {
  local user="$1"; shift
  sudo -u "$user" -H bash -lc "$*"
}

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

log "Removing stale apt sources (if any)"
rm -f /etc/apt/sources.list.d/gierrt.list /etc/apt/keyrings/gierrt.gpg

log "Updating apt + installing dependencies"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y

PKGS=(
  ca-certificates
  curl
  git
  sudo
  zsh
  locales
  tzdata
  openssh-client
  gnupg
  wget
  eza
)

apt-get install -y "${PKGS[@]}"

log "Installing main packages"
OPTIONAL_PKGS=(fontconfig bat)

# fastfetch (check repo availability)
if apt-cache show fastfetch >/dev/null 2>&1; then
  OPTIONAL_PKGS+=(fastfetch)
fi

apt-get install -y "${OPTIONAL_PKGS[@]}" || true

log "Creating symlinks for bat"
# Debian names the 'bat' executable 'batcat' to avoid conflicts
if has_cmd batcat && ! has_cmd bat; then
  ln -sf /usr/bin/batcat /usr/local/bin/bat
fi

log "Ensuring locale exists (en_US.UTF-8)"
if ! locale -a | grep -qi '^en_US\.utf8$'; then
  sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen || true
  locale-gen
fi
update-locale LANG=en_US.UTF-8 || true

log "Ensuring user '${TARGET_USER}' exists"
if ! id -u "${TARGET_USER}" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "${TARGET_USER}"
  echo "Please set a password for ${TARGET_USER}:"
  passwd "${TARGET_USER}"
else
  echo "User exists: ${TARGET_USER}"
fi

TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
if [[ -z "${TARGET_HOME}" ]]; then
  die "Could not determine home directory for ${TARGET_USER}"
fi

log "Ensuring '${TARGET_USER}' is in sudo group"
usermod -aG sudo "${TARGET_USER}"
if ! grep -q "^%sudo" /etc/sudoers; then
  echo "%sudo ALL=(ALL:ALL) ALL" >> /etc/sudoers
fi

log "Setting default shell to zsh"
ZSH_PATH="$(command -v zsh)"
chsh -s "${ZSH_PATH}" "${TARGET_USER}" || true

log "Preparing dotfiles directory: ${DOTFILES_DIR}"
mkdir -p "$(dirname "${DOTFILES_DIR}")"
chown "${TARGET_USER}:${TARGET_USER}" "$(dirname "${DOTFILES_DIR}")"

if [[ -d "${DOTFILES_DIR}/.git" ]]; then
  log "Dotfiles repo already present; pulling latest"
  sudo -u "${TARGET_USER}" git -C "${DOTFILES_DIR}" fetch --all
  sudo -u "${TARGET_USER}" git -C "${DOTFILES_DIR}" checkout "${DOTFILES_BRANCH}"
  sudo -u "${TARGET_USER}" git -C "${DOTFILES_DIR}" pull --ff-only
else
  log "Cloning dotfiles repo"
  if ! sudo -u "${TARGET_USER}" git clone --branch "${DOTFILES_BRANCH}" "${DOTFILES_REPO_SSH}" "${DOTFILES_DIR}"; then
    warn "SSH clone failed. Falling back to HTTPS."
    sudo -u "${TARGET_USER}" git clone --branch "${DOTFILES_BRANCH}" "${DOTFILES_REPO_HTTPS}" "${DOTFILES_DIR}"
  fi
fi

log "Linking configs"
ZSHRC_SRC="${DOTFILES_DIR}/zsh/zshrc"
P10K_SRC="${DOTFILES_DIR}/zsh/p10k.zsh"
FF_SRC="${DOTFILES_DIR}/fastfetch/config.jsonc"

ZSHRC_DST="${TARGET_HOME}/.zshrc"
P10K_DST="${TARGET_HOME}/.p10k.zsh"
FF_DIR="${TARGET_HOME}/.config/fastfetch"
FF_DST="${FF_DIR}/config.jsonc"

run_as_user "${TARGET_USER}" "mkdir -p '${FF_DIR}'"

[[ -f "${ZSHRC_SRC}" ]] && run_as_user "${TARGET_USER}" "ln -sf '${ZSHRC_SRC}' '${ZSHRC_DST}'"
[[ -f "${P10K_SRC}" ]] && run_as_user "${TARGET_USER}" "ln -sf '${P10K_SRC}' '${P10K_DST}'"
[[ -f "${FF_SRC}" ]] && run_as_user "${TARGET_USER}" "ln -sf '${FF_SRC}' '${FF_DST}'"

log "Installing zsh plugins"
PLUGIN_DIR="${TARGET_HOME}/.zsh/plugins"
run_as_user "${TARGET_USER}" "mkdir -p '${PLUGIN_DIR}'"

run_as_user "${TARGET_USER}" "
  set -euo pipefail
  cd '${PLUGIN_DIR}'

  clone_or_update() {
    local name=\"\$1\"
    local url=\"\$2\"
    if [[ -d \"\$name/.git\" ]]; then
      git -C \"\$name\" pull --ff-only
    else
      git clone --depth=1 \"\$url\" \"\$name\"
    fi
  }

  clone_or_update powerlevel10k https://github.com/romkatv/powerlevel10k.git
  clone_or_update zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
  clone_or_update zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
"

log "Installing fastfetch (GitHub fallback)"
if ! has_cmd fastfetch; then
  ARCH="$(dpkg --print-architecture)"
  if [[ "${ARCH}" == "amd64" ]]; then
    tmpdir="$(mktemp -d)"
    url="$(curl -fsSL https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep -Eo 'https://[^"]+amd64\.deb' | head -n1 || true)"
    if [[ -n "${url}" ]]; then
      curl -fsSL "${url}" -o "${tmpdir}/fastfetch.deb"
      dpkg -i "${tmpdir}/fastfetch.deb" || apt-get -f install -y
    fi
    rm -rf "${tmpdir}"
  fi
fi

log "Done."