# Ignition 2.0 Features Reference

Complete inventory of everything your new Ignition setup handles.

## Directories created

- `~/bin` — Custom scripts
- `~/tmp` — Temporary files
- `~/workspace` — Git repositories (root)
- `~/workspace/work` — Work projects
- `~/workspace/personal` — Personal projects
- `~/workspace/playground` — Experimental projects
- `~/workspace/third` — Third-party libraries/sources

## Packages installed

### Base (all machines)
- **Ignition tools**: mas, dockutil, gum, chezmoi
- **CLI**: bash 5+, fish, midnight-commander, tldr, tree, wget, imagemagick, ffmpeg, yt-dlp, speedtest-cli, btop, neofetch
- **Development**: git, git-lfs
- **Casks**: mysides, fork, VSCode, Android Studio, Temurin JDK, the-unarchiver, android-file-transfer, Chrome, YT Music, monitorcontrol, ChatGPT, logi-options+, appcleaner
- **Mac App Store**: Magnet, Amphetamine

### Personal (add via `playbooks/personal.yml`)
- messenger, whatsapp, slack, discord, zoom, skype, audacity, sweet-home3d, balenaetcher, philips-hue-sync, ukelele, coconutbattery, 8bitdo-ultimate-software, iMovie

### Work (add via `playbooks/work.yml`)
- microsoft-teams, microsoft-office, adobe-acrobat-reader, figma, Xcode

## System preferences configured

### Accessibility (7 settings)
- Shake mouse cursor to locate
- Hold ⌃⌥ for temporary zoom
- Zoom with Ctrl+scroll
- Zoom follows keyboard focus
- Zoom style (fullscreen/picture-in-picture)

### Date & Time (7 settings)
- Timezone (Europe/Budapest by default)
- Network time sync
- Time server
- Auto-timezone from location
- Clock format (digital/analog)
- Flashing date separators
- Menu bar clock format

### Desktop (8 settings)
- Click wallpaper to reveal desktop
- Show/hide desktop icons
- Show/hide hard drives, external drives, removable media, servers
- Hot corner configuration (all 4 corners + modifiers)

### Displays (4 settings)
- Auto brightness
- Font smoothing level
- HiDPI display modes
- Subpixel rendering

### Finder (12 settings)
- Show file extensions
- Show hidden files
- Default view style (column, icon, list, gallery)
- Show path bar
- Warn before emptying trash
- Search scope (this Mac, current folder, previous)
- New window target (home, desktop, documents)
- Avoid .DS_Store on network/USB
- Show ~/Library folder
- Sidebar items (Applications, ~, workspace, tmp, Desktop, Downloads)

### Keyboard (15 settings)
- Full keyboard access (Tab focus)
- F-keys as standard (not media)
- Autocorrect/spell checking (all 6 variants disabled)
- Character repeat vs accent picker
- Key repeat rate (2–120)
- Initial key repeat delay (15–120ms)
- Keyboard backlight dimming
- Custom keyboard layout (en_hu with Hungarian accents + shrug emoticon)

### Menu Bar (5 settings)
- Show battery percentage
- Bluetooth icon visibility
- Sound icon visibility
- Text input menu
- AirPlay mirroring options

### Mission Control (3 settings)
- Auto-rearrange spaces
- Switch to space with open windows on app activate
- Displays have separate spaces

### Notifications (1 setting)
- Banner display duration (seconds)

### Safari (1 setting)
- Show full URL in address bar

### Screenshot (2 settings)
- Show thumbnail after capture
- File format (PNG by default)

### Security & Privacy (5 settings)
- Require password on wake/sleep
- Password delay (immediate)
- Disable "Are you sure?" dialog for apps
- Firewall enabled
- Allow signed apps through firewall

### Siri (4 settings)
- Enable/disable Siri
- Voice feedback
- Keyboard shortcut
- Show in menu bar

### Trackpad (4 settings)
- Tracking speed (0–5, default 4.5)
- Haptic feedback strength (first/second click)
- Two-finger swipe for back/forward

## Dock configuration

### Dock appearance (10 settings)
- Icon size (default 32px)
- Magnified icon size (default 48px)
- Magnification enabled
- Lock icon size (disable resize arrows)
- Minimize animation (scale)
- Show recent apps
- Scroll up to show app windows
- Position (bottom, left, right)
- Show pinned apps only
- Auto-hide

### Dock items (customizable)
- Personal: Chrome, ChatGPT, YT Music, Messenger, Messages, WhatsApp, Slack, Calendar, Reminders, Notes, Passwords, Screenshot, Terminal, Fork, VS Code, Android Studio, Downloads folder
- Work: Chrome, ChatGPT, YT Music, Calendar, Reminders, Notes, Passwords, Screenshot, Cisco Secure Client, Figma, Outlook, Teams, Terminal, Fork, VS Code, Android Studio, Downloads folder

## VS Code setup

### Extensions
- Bash IDE (autocompletion & linting)
- ShellCheck (script errors & best practices)
- Kotlin language support
- Python (linting, IntelliSense, Jupyter)
- One Dark Pro theme

## Shell configuration

- Set fish as default shell
- Ensure fish is in /etc/shells (both Intel and Apple Silicon paths)
- Works with existing fish configuration

## Dotfiles management (chezmoi)

- Initialize from dotfiles repo
- Support for templates (Jinja2-like syntax)
- Conditional files (`{{ if .personal }}`)
- Secret management integration
- Automatic symlink creation with full directory structure preservation

## What's NOT included

- ❌ Linux/Ubuntu setup (use old `system/unix-apt` if needed)
- ❌ Steam Deck setup (future expansion possible)
- ❌ Browser extensions installation
- ❌ Application-specific configuration files (handled by chezmoi instead)
- ❌ Network/WiFi configuration
- ❌ iCloud Keychain setup

## Extensibility

Each role is designed to be extended:

### Add a new preference
Edit `roles/macos/tasks/*.yml` and add a new task using `community.general.osx_defaults`

### Add packages
Add to `roles/homebrew/defaults/main.yml` or `playbooks/*.yml` vars

### Add dock apps
Update `dock_apps` list in `playbooks/*.yml`

### Add directories
Update `roles/directories/defaults/main.yml`

### Add VS Code extensions
Update `roles/vscode/defaults/main.yml`

### Add shell customization
Update `roles/shell/tasks/main.yml` or create new role

### Add custom tasks
Create new role in `roles/` and include in playbook

## Performance

- **Homebrew installation**: 5–15 minutes (depends on internet speed)
- **System preferences**: <1 minute
- **Idempotent re-run**: <30 seconds (only applies changes)
- **Dock setup**: <10 seconds
- **Total first-time setup**: ~20–30 minutes (including downloads)

## Debugging & logs

Ansible provides detailed output by default:
- ✅ shown in green when task succeeds
- 🔵 skipped when task is already applied (idempotent)
- ❌ shown in red if task fails

To see more details:
```bash
ansible-playbook playbooks/personal.yml -vvv
```

To see what would change without applying:
```bash
ansible-playbook playbooks/personal.yml --diff
```

## Future improvements

Planned additions:
- Steam Deck setup (requires different role structure)
- macOS Sonoma/Sequoia-specific preferences
- Nix/Home Manager alternative path
- Docker dev environment setup
- Kubernetes cluster kubeconfig setup
- AWS credential setup automation
