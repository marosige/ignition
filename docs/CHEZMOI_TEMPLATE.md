# chezmoi dotfiles template structure
#
# When you create a separate dotfiles repo, use this as a starter.
# chezmoi automatically applies these files to your home directory,
# with full support for templates, conditions, and secrets.
#
# Directory structure:
#
# ~/.local/share/chezmoi/
# ├── .chezmoi.yaml                    # Local config (not checked in)
# ├── .chezmoidata.yaml                # Data for templates (not checked in)
# ├── home
# │   ├── exact_.config/               # Recursively manage ~/.config
# │   ├── exact_.local/share/          # ~/.local/share
# │   ├── .bashrc
# │   ├── .fishrc
# │   ├── .gitconfig                   # Can be templated
# │   ├── .zshrc
# │   └── run_before_*.sh              # Run before other files
# └── .install.yaml                    # Installation script (optional)
#
# Key patterns:
#
# - Files starting with `.` are preserved
# - `exact_` prefix means chezmoi will remove files not in this dir
# - `run_before_` scripts run before applying
# - `run_after_` scripts run after applying
# - `{{ .variable }}` for template substitution
# - Templates can use `{{ if .personal }}` for conditional sections
#
# Example .chezmoidata.yaml:
# ```yaml
# personal: true  # or false for work machine
# email: gergely@example.com
# name: Gergely Marosi
# ```
#
# To use this:
# 1. Create a new public GitHub repo: https://github.com/marosige/dotfiles
# 2. Copy this template structure
# 3. Add your dotfiles (git config, shell config, etc.)
# 4. Push to GitHub
# 5. Change `chezmoi_dotfiles_repo` in roles/chezmoi/defaults/main.yml
