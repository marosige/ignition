#!/usr/bin/env bash

# Ignition — Mac setup with Ansible
# Usage (first time): bash -c "$(curl -fsSL https://raw.githubusercontent.com/marosige/ignition/main/bootstrap.sh)"
# Usage (after):      bash ~/.ignition/bootstrap.sh

set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;92m'
BLUE='\033[0;94m'
YELLOW='\033[0;33m'
RED='\033[0;91m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[✔]${NC} $*"; }
task() { echo -e "${BLUE}[>]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
fail() { echo -e "${RED}[✖]${NC} $*"; exit 1; }
ask()  { read -p "$(echo -e "${YELLOW}[?]${NC} $* (y/n) ")" -n 1 -r; echo; }

IGNITION_ROOT="$HOME/.ignition"
IGNITION_REPO_URL="https://github.com/marosige/ignition.git"

# ── 1. Get the repo ──────────────────────────────────────────────────────────
if [ -d "$IGNITION_ROOT" ]; then
  task "Updating Ignition..."
  git -C "$IGNITION_ROOT" pull --rebase --autostash || fail "git pull failed"
  ok "Up to date"
else
  command -v git &>/dev/null || fail "git is not installed"
  task "Cloning Ignition..."
  git clone "$IGNITION_REPO_URL" "$IGNITION_ROOT" || fail "git clone failed"
  ok "Cloned to $IGNITION_ROOT"
fi

cd "$IGNITION_ROOT"

# ── 2. Install Homebrew ───────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  task "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || fail "Homebrew install failed"
  ok "Homebrew installed"
fi

# The installer updates future shells; load Homebrew into this shell as well.
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif ! command -v brew &>/dev/null; then
  fail "Homebrew was installed but could not be found"
fi

# ── 3. Install Ansible ───────────────────────────────────────────────────────
if ! command -v ansible &>/dev/null; then
  task "Installing Ansible..."
  brew install ansible || fail "Ansible install failed"
  ok "Ansible installed"
fi

# ── 4. Install Ansible collections ──────────────────────────────────────────
task "Installing Ansible collections..."
ansible-galaxy collection install -r requirements.yml -p ~/.ansible/collections
ok "Collections ready"

# ── 5. Choose profile ────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Choose setup profile:${NC}"
echo "  1) Personal"
echo "  2) Work"
echo "  3) Exit"
read -p "$(echo -e "${YELLOW}[?]${NC} Enter choice: ")" -n 1 -r
echo

case $REPLY in
  1) PLAYBOOK="playbooks/personal.yml" ;;
  2) PLAYBOOK="playbooks/work.yml" ;;
  *) warn "Exiting"; exit 0 ;;
esac

# ── 6. Run ───────────────────────────────────────────────────────────────────
echo ""
warn "This will install packages and change system preferences."
ask "Continue?"

  if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  ansible-playbook "$PLAYBOOK"
  echo ""
  ok "Done! Re-run anytime: bash ~/.ignition/bootstrap.sh"
else
  warn "Cancelled"
fi
