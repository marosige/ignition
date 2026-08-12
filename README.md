# Ignition

Personal macOS setup using Ansible + chezmoi.

## What this does

- Creates directories (`~/workspace`, `~/bin`, `~/tmp`, etc.)
- Installs packages and apps (Homebrew, Casks, MAS)
- Applies macOS preferences (Dock, Finder, Keyboard, Trackpad, Security, ...)
- Configures Dock items
- Installs VS Code extensions
- Applies dotfiles through chezmoi

## Setup

### First run

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marosige/ignition/main/bootstrap.sh)"
```

### Re-run (update + apply changes)

```bash
bash ~/.ignition/bootstrap.sh
```

The same script handles both cases — clones on first run, pulls on subsequent runs.

## Daily use

```bash
bash ~/.ignition/bootstrap.sh
```

Or directly if you know which profile:

```bash
cd ~/.ignition && ansible-playbook playbooks/personal.yml
cd ~/.ignition && ansible-playbook playbooks/personal.yml --check --diff  # dry run
```

## Structure

- `playbooks/site.yml`: common base playbook
- `playbooks/personal.yml`: personal wrapper
- `playbooks/work.yml`: work wrapper
- `playbooks/profiles/personal.yml`: personal overrides
- `playbooks/profiles/work.yml`: work overrides
- `roles/*`: reusable setup roles

## Customize

- Common settings: `roles/*/defaults/main.yml`
- Personal/work differences: `playbooks/profiles/*.yml`

## Notes

- Repository now contains only the Ansible setup.
- Personal/work differences live in `playbooks/profiles/*.yml`.
