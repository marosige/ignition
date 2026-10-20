# Ignition

Personal macOS setup with Ansible.

## Run

First run on a new Mac:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marosige/ignition/main/bootstrap.sh)"
```

Run again later:

```bash
bash ~/.ignition/bootstrap.sh
```

Preview changes without applying them:

```bash
cd ~/.ignition
ansible-playbook playbooks/personal.yml --check --diff
```

## Edit

- `playbooks/personal.yml`: personal apps, Dock items, and startup apps
- `playbooks/work.yml`: work-specific apps, Dock items, and startup apps
- `roles/*/defaults/main.yml`: shared packages and macOS preferences
- `roles/*/tasks/main.yml`: implementation for each setup area
