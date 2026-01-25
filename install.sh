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

log "Updating apt + installing packages"
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
)

# nice-to-haves (optional)
OPTIONAL_PKGS=(fontconfig bat eza)

# fastfetch (prefer apt if available)
if apt-cache show fastfetch >/dev/null 2>&1; then
  PKGS+=(fastfetch)
else
  warn "fastfetch not found in apt repos. Will install via GitHub release later (amd64 only)."
fi

apt-get install -y "${PKGS[@]}"
apt-get install -y "${OPTIONAL_PKGS[@]}" || true

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
  warn "User created. If you skipped password, set it with: passwd ${TARGET_USER}"
else
  echo "User exists: ${TARGET_USER}"
fi

TARGET_HOME="$(getent passwd "${TARGET_USER}" | cut -d: -f6)"
if [[ -z "${TARGET_HOME}" ]]; then
  die "Could not determine home directory for ${TARGET_USER}"
fi

log "Ensuring '${TARGET_USER}' is in sudo group"
usermod -aG sudo "${TARGET_USER}"

log "Setting default shell to zsh for '${TARGET_USER}'"
ZSH_PATH="$(command -v zsh)"
chsh -s "${ZSH_PATH}" "${TARGET_USER}" || true

log "Preparing dotfiles directory: ${DOTFILES_DIR}"
install -d -m 0755 -o "${TARGET_USER}" -g "${TARGET_USER}" "$(dirname "${DOTFILES_DIR}")"

clone_repo() {
  local url="$1"
  run_as_user "${TARGET_USER}" "git clone --branch '${DOTFILES_BRANCH}' '${url}' '${DOTFILES_DIR}'"
}

if [[ -d "${DOTFILES_DIR}/.git" ]]; then
  log "Dotfiles repo already present; pulling latest"
  run_as_user "${TARGET_USER}" "git -C '${DOTFILES_DIR}' fetch --all"
  run_as_user "${TARGET_USER}" "git -C '${DOTFILES_DIR}' checkout '${DOTFILES_BRANCH}'"
  run_as_user "${TARGET_USER}" "git -C '${DOTFILES_DIR}' pull --ff-only"
else
  log "Cloning dotfiles repo"
  # Try SSH first, fall back to HTTPS (avoids needing the user's GitHub SSH key on the server)
  if clone_repo "${DOTFILES_REPO_SSH}"; then
    echo "Cloned via SSH."
  else
    warn "SSH clone failed. Falling back to HTTPS."
    clone_repo "${DOTFILES_REPO_HTTPS}"
  fi
fi

log "Linking configs from dotfiles repo into ${TARGET_HOME}"

# Your repo layout (per what you showed):
#   zsh/zshrc
#   zsh/p10k.zsh
#   fastfetch/config.jsonc

ZSHRC_SRC="${DOTFILES_DIR}/zsh/zshrc"
P10K_SRC="${DOTFILES_DIR}/zsh/p10k.zsh"
FF_SRC="${DOTFILES_DIR}/fastfetch/config.jsonc"

ZSHRC_DST="${TARGET_HOME}/.zshrc"
P10K_DST="${TARGET_HOME}/.p10k.zsh"
FF_DIR="${TARGET_HOME}/.config/fastfetch"
FF_DST="${FF_DIR}/config.jsonc"

run_as_user "${TARGET_USER}" "mkdir -p '${FF_DIR}'"

if [[ -f "${ZSHRC_SRC}" ]]; then
  run_as_user "${TARGET_USER}" "ln -sf '${ZSHRC_SRC}' '${ZSHRC_DST}'"
else
  warn "Missing ${ZSHRC_SRC}. (Repo should contain zsh/zshrc)"
fi

if [[ -f "${P10K_SRC}" ]]; then
  run_as_user "${TARGET_USER}" "ln -sf '${P10K_SRC}' '${P10K_DST}'"
else
  warn "Missing ${P10K_SRC}. (Repo should contain zsh/p10k.zsh)"
fi

if [[ -f "${FF_SRC}" ]]; then
  run_as_user "${TARGET_USER}" "ln -sf '${FF_SRC}' '${FF_DST}'"
else
  warn "Missing ${FF_SRC}. (Repo should contain fastfetch/config.jsonc)"
fi

log "Installing zsh plugins into ${TARGET_HOME}/.zsh/plugins (as ${TARGET_USER})"
PLUGIN_DIR="${TARGET_HOME}/.zsh/plugins"
run_as_user "${TARGET_USER}" "mkdir -p '${PLUGIN_DIR}'"

run_as_user "${TARGET_USER}" "
  set -euo pipefail
  cd '${PLUGIN_DIR}'

  clone_or_update() {
    local name=\"\$1\"
    local url=\"\$2\"
    if [[ -d \"\$name/.git\" ]]; then
      echo \"Updating \$name...\"
      git -C \"\$name\" pull --ff-only
    else
      echo \"Cloning \$name...\"
      git clone --depth=1 \"\$url\" \"\$name\"
    fi
  }

  clone_or_update powerlevel10k https://github.com/romkatv/powerlevel10k.git
  clone_or_update zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
  clone_or_update zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git
"

log "Installing fastfetch if apt didn't provide it"
if ! has_cmd fastfetch; then
  warn "fastfetch not installed via apt. Installing from GitHub latest release (amd64 only)."

  ARCH="$(dpkg --print-architecture)"
  if [[ "${ARCH}" != "amd64" ]]; then
    warn "Non-amd64 architecture (${ARCH}). Skipping fastfetch GitHub install."
  else
    tmpdir="$(mktemp -d)"
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
echo "Test:"
echo "  su - ${TARGET_USER}"
echo "  echo \$SHELL"
echo "  ls -al ~/.zsh/plugins"