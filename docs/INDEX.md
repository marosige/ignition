# Ignition Documentation

Welcome! Here's where to find what you need.

## Getting Started

- **[README.md](../README.md)** ← Start here
  - Overview of Ignition 2.0
  - Quick start instructions
  - How the system works
  - Customization guide

- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** ← For common tasks
  - Installation commands
  - Common Ansible commands
  - File locations
  - Troubleshooting quick answers

## For Users

- **[FEATURES.md](FEATURES.md)** — Complete inventory
  - Every directory created
  - Every package installed
  - Every system preference
  - Full feature list

- **[MIGRATION.md](MIGRATION.md)** — Upgrading from old bash version
  - Why to migrate
  - Step-by-step migration guide
  - Common gotchas
  - Debugging tips

## For Developers

- **[CHEZMOI_TEMPLATE.md](CHEZMOI_TEMPLATE.md)** — Dotfiles with chezmoi
  - How to create a dotfiles repo
  - chezmoi file structure
  - Template examples
  - Secrets management

## Reference

- **[BUILD_SUMMARY.md](BUILD_SUMMARY.md)** — What was built
  - Complete file inventory
  - Architecture overview
  - Improvements over original
  - File statistics

## Quick Navigation

### I want to...

- **...install Ignition on a new Mac**
  → See [README.md](../README.md) Quick start section

- **...change a system preference**
  → Edit `roles/macos/defaults/main.yml`, then see [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for run command

- **...add a new package**
  → Edit `roles/homebrew/defaults/main.yml` or add to playbook vars

- **...customize the dock**
  → Edit `dock_apps` in `playbooks/personal.yml` or `playbooks/work.yml`

- **...migrate from old bash version**
  → See [MIGRATION.md](MIGRATION.md)

- **...set up dotfiles with chezmoi**
  → See [CHEZMOI_TEMPLATE.md](CHEZMOI_TEMPLATE.md)

- **...know what Ignition does**
  → See [FEATURES.md](FEATURES.md)

- **...see what was built**
  → See [BUILD_SUMMARY.md](BUILD_SUMMARY.md)

- **...debug or troubleshoot**
  → See [QUICK_REFERENCE.md](QUICK_REFERENCE.md) Troubleshooting section

## File Structure

```
~/.ignition/
├── README.md                    ← Main documentation
├── ansible.cfg                  ← Ansible settings
├── bootstrap.sh                 ← Start here
├── download.sh                  ← One-liner installer
├── requirements.yml             ← Ansible collections
├── inventory.yml                ← Localhost inventory
├── group_vars/
│   └── all.yml                 ← Shared variables
├── playbooks/
│   ├── personal.yml            ← Personal Mac setup
│   └── work.yml                ← Work Mac setup
├── roles/                       ← Ansible roles
│   ├── directories/
│   ├── homebrew/
│   ├── shell/
│   ├── macos/                  ← System preferences
│   ├── dock/
│   ├── vscode/
│   └── chezmoi/
└── docs/                        ← This directory
    ├── INDEX.md                ← You are here
    ├── README.md               (see ../README.md)
    ├── QUICK_REFERENCE.md
    ├── FEATURES.md
    ├── MIGRATION.md
    ├── CHEZMOI_TEMPLATE.md
    └── BUILD_SUMMARY.md
```

## Support

- Ansible documentation: https://docs.ansible.com/
- Ansible collection (community.general): https://docs.ansible.com/ansible/latest/collections/community/general/
- chezmoi documentation: https://www.chezmoi.io/
- GitHub issues: https://github.com/marosige/ignition/issues

## Contributing

Found a bug or want to add a feature?

1. Fork the repository
2. Create a branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test with `ansible-playbook playbooks/personal.yml --check`
5. Commit and push
6. Open a pull request

See [../README.md](../README.md) Contributing section for details.
