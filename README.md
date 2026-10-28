# Ignition 🔥

**Ignite your Mac.** A native macOS app that turns any Mac into *your* Mac – and keeps it that way.

You configure everything with a GUI that looks like System Settings (Liquid Glass, macOS 26+), save it
to a private GitHub repo, and on any other Mac you connect the repo, press **Apply** and you are done.

## What it manages

| Area | What you get |
| --- | --- |
| **Settings** | Per-category panes (Desktop & Dock, Finder, Keyboard, Trackpad, Date & Time, …) – only the options Ignition really sets. Every row can be reset to the macOS default of the running OS version. |
| **Dock layout** | Visual editor: apps, spacers, folders, drag to reorder, import the current Dock, apply with `dockutil`. |
| **Login apps** | The list of apps that start after login. |
| **Finder sidebar** | Favorites list. |
| **Folders** | The directory structure you want (`~/workspace/work`, …). |
| **Dotfiles** | Files are moved into the repo and symlinked back. Suggestions for files found on the Mac, backups of anything replaced. |
| **Homebrew** | A store: search all formulae and casks, detail page, install / uninstall, installed list, Brewfile view that shows what is missing from your profile. |
| **App Store** | `mas` search, install and list. |
| **GitHub sync** | Fine-grained token + `owner/repo`; optional config folder and branch. Green / orange / red status, one smart button (save, pull or sync), diff viewer and a conflict resolver. Commits are tagged with the device (`[Mac mini] Update base (settings)`). |

## Profiles: base + personal / work

The configuration is layered. Pick the active profiles per Mac in the toolbar menu:

```
base ──► personal      (private MacBook)
base ──► work          (work MacBook)
```

Anything saved into **Base** reaches every Mac on the next pull. The toolbar shows which profile receives
your changes (“Saving to Work”).

## Config repo layout

Everything lives in an `ignition/` folder at the root of your private repo:

```
ignition/
  profiles/
    base/
      profile.json        settings, folders, packages, login apps, sidebar, dock
      dotfiles/           mirrors $HOME (.zshrc, .config/fish/…)
    personal/…
    work/…
```

`seed/ignition` in this repository is the author’s own configuration. Use **Overview → Load starter
configuration** to start from it, then push it to your private repo.

## Install

On a fresh Mac:

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/marosige/ignition/main/scripts/install.sh)"
```

Then: **GitHub Sync** → repository + token + device name → **Connect** → pick profiles → **Apply to this Mac**.

### Build from source

Requires macOS 26, Xcode 26 (Swift 6.2).

```sh
./scripts/build-app.sh && open build/Ignition.app
swift test
```

Tagging `v*` builds and publishes `Ignition.zip` through GitHub Actions.

## How “Reset to default” works

Reset deletes the key from the preference domain, so macOS falls back to its own default for the
installed OS version. Rows without a saved value always show what is currently active on the Mac.

## Notes

* The home-server part moved out of this repository.
* Settings that need administrator rights are written through one password prompt.
* Don’t put secrets into tracked dotfiles.
