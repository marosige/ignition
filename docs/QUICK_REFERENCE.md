# Quick Reference

## Installation

```bash
# One-liner (recommended)
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marosige/ignition/main/download.sh)"

# Or local
git clone https://github.com/marosige/ignition.git ~/.ignition
cd ~/.ignition
bash bootstrap.sh
```

## Common commands

```bash
cd ~/.ignition

# Run full setup
ansible-playbook playbooks/personal.yml   # or work.yml

# Dry run (show what would change)
ansible-playbook playbooks/personal.yml --check

# Diff (show exact changes)
ansible-playbook playbooks/personal.yml --diff

# Run only one role
ansible-playbook playbooks/personal.yml --tags homebrew

# Verbose output
ansible-playbook playbooks/personal.yml -vvv

# Update Ansible collections
ansible-galaxy collection install -r requirements.yml
```

## Customization

### Change system preferences
Edit `roles/macos/defaults/main.yml`

Example: Slower keyboard repeat
```yaml
macos_keyboard_key_repeat: 10    # instead of 2
```

Then re-run:
```bash
ansible-playbook playbooks/personal.yml
```

### Add packages
Edit `roles/homebrew/defaults/main.yml` or `playbooks/personal.yml`:

```yaml
homebrew_extra_casks:
  - vlc
  - obsidian
```

### Change dock apps
Edit `playbooks/personal.yml`:

```yaml
dock_apps:
  - { spacer: true }
  - /Applications/Google Chrome.app
  - /Applications/VS Code.app
  - { spacer: true }
  - /Applications/Slack.app
```

### Add a new preference
1. Add task to `roles/macos/tasks/file.yml`
2. Add variable to `roles/macos/defaults/main.yml`
3. Re-run playbook

Example task:
```yaml
- name: "System | My new preference"
  community.general.osx_defaults:
    domain: com.apple.something
    key: PreferenceKey
    type: bool
    value: "{{ my_new_preference }}"
```

## File locations

```
~/.ignition/
├── bootstrap.sh           ← Start here
├── playbooks/
│   ├── personal.yml       ← Edit for personal settings
│   └── work.yml          ← Edit for work settings
├── roles/
│   ├── macos/defaults/main.yml       ← All system preferences here
│   ├── homebrew/defaults/main.yml    ← All packages here
│   ├── dock/defaults/main.yml        ← Dock preferences
│   └── vscode/defaults/main.yml      ← VS Code extensions
└── group_vars/all.yml     ← Shared variables
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Ansible not found | `brew install ansible` |
| Task fails with permission denied | Run with `become: true` in task |
| Dock apps revert after rerun | Make sure they're in `dock_apps` list |
| Preferences not applying | Check if task requires `become: true` |
| Want to debug a task | Use `--check` and `--diff` flags |

## Comparison with old bash version

| What | Old bash | New Ansible |
|-----|----------|------------|
| Run setup | `bash ignition/ignition.sh` | `ansible-playbook playbooks/personal.yml` |
| Check what changes | Not possible | `--check --diff` |
| Add preference | Edit bash script + add to script folder | Edit YAML variable |
| Run again safely | ❌ Risky | ✅ Yes, totally safe |
| Customize per machine | Create new bash script | Override playbook vars |

## Next steps

1. **Customize your setup**
   ```bash
   cd ~/.ignition
   vim playbooks/personal.yml
   vim roles/macos/defaults/main.yml
   ```

2. **Create a dotfiles repo** (optional but recommended)
   - Follow [docs/CHEZMOI_TEMPLATE.md](docs/CHEZMOI_TEMPLATE.md)
   - Update `chezmoi_dotfiles_repo` in `roles/chezmoi/defaults/main.yml`

3. **Commit to version control** (if forking)
   ```bash
   git add -A
   git commit -m "Customize for my Mac"
   git push
   ```

4. **Share or backup**
   - Fork on GitHub for easy re-cloning
   - Keep in sync across machines

## More info

- [README.md](../README.md) — Full documentation
- [FEATURES.md](FEATURES.md) — Complete feature list
- [MIGRATION.md](MIGRATION.md) — Upgrading from old bash version
- [CHEZMOI_TEMPLATE.md](CHEZMOI_TEMPLATE.md) — Dotfiles setup
