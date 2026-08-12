# Migration Guide: Bash → Ansible + chezmoi

## For existing Ignition users

Your old setup still works in `system/`. The new Ansible setup is completely separate and won't conflict.

### Why migrate?

| Feature | Old Bash | New Ansible |
|---------|----------|-------------|
| Idempotent (safe to re-run) | ❌ No — runs blindly | ✅ Yes — only applies changes |
| Easy to read | ❌ Bash is complex | ✅ YAML is declarative |
| Version control | ⚠️ Yes, but brittle | ✅ Version everything |
| Status quo tracking | ❌ No — drift unknown | ✅ Yes — know exactly what's set |
| Custom logic | ✅ Bash is flexible | ✅ Ansible + Jinja2 templates |
| Error handling | ⚠️ Basic (|| exit=1) | ✅ Robust error reporting |

### How to migrate

#### Step 1: Review the new structure

```bash
cd ~/.ignition
# Look at the new roles
ls -la roles/
cat playbooks/personal.yml
```

#### Step 2: Customize for your setup

1. **Preferences**: Edit `roles/macos/defaults/main.yml` to match your old settings
   - Search for the old preference value in `system/unix-mac/preferences/*.sh`
   - Find the corresponding variable in defaults/main.yml
   - Update it

2. **Packages**: Edit `roles/homebrew/defaults/main.yml`
   - Copy your package list from `system/unix-mac/dotfiles/Brewfile.*`
   - Add personal/work packages to the playbook vars

3. **Dock layout**: Update `playbooks/personal.yml` or `work.yml`
   - Copy apps from `system/unix-mac-personal/preferences/dock.sh`
   - Translate to YAML format

4. **Dotfiles**: Prepare chezmoi repo
   - Create `https://github.com/yourusername/dotfiles`
   - Follow [docs/CHEZMOI_TEMPLATE.md](docs/CHEZMOI_TEMPLATE.md)
   - Update `chezmoi_dotfiles_repo` in `roles/chezmoi/defaults/main.yml`

#### Step 3: Test on a non-production machine first

```bash
# Dry run (don't apply, just show what would happen)
ansible-playbook playbooks/personal.yml --check

# Actually run it
ansible-playbook playbooks/personal.yml
```

#### Step 4: Verify it worked

```bash
# Check dock
defaults read com.apple.dock tilesize

# Check keyboard
defaults read NSGlobalDomain KeyRepeat

# Check trackpad
defaults read NSGlobalDomain com.apple.trackpad.scaling
```

#### Step 5: Keep the old setup as backup

Don't delete `system/` until you're 100% confident. You can still use:

```bash
# Old setup (still works)
cd ~/.ignition
bash ignition/ignition.sh
```

### Common gotchas

#### "The playbook overwrites all my dock icons!"

That's correct — this is idempotent behavior. To preserve existing apps, include them in the `dock_apps` list in your playbook.

#### "Some preferences aren't applying"

Check if they require `sudo`:
- Many keyboard/accessibility settings do
- Ansible will prompt you for your password
- You can also add `become: true` to any task

#### "I want to keep my old bash scripts but use Ansible for preferences"

That works! You can:
1. Run Ansible for preferences/packages
2. Keep your custom bash scripts in `system/`
3. Run both

They don't conflict.

### Debugging

#### See what would change
```bash
ansible-playbook playbooks/personal.yml --diff
```

#### Run a specific role
```bash
ansible-playbook playbooks/personal.yml --tags macos
```

#### Run in verbose mode
```bash
ansible-playbook playbooks/personal.yml -vvv
```

#### Run a single task
```bash
ansible localhost -m community.general.osx_defaults \
  -a "domain=com.apple.dock key=tilesize type=int value=32"
```

### Questions?

- Ansible docs: https://docs.ansible.com/
- community.general collection: https://docs.ansible.com/ansible/latest/collections/community/general/
- chezmoi docs: https://www.chezmoi.io/
