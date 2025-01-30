# Final steps

Most of the installs and preferences can be set by scripts, but there are some final steps you have to done by hand.

## Additional application settings

### Auto start applications

Somehow Spotify and Messenger auto starts and I can't turn it off with a script because they are not listed under:
```
/Library/StartupItems/
/Library/LaunchDaemons/
/Library/LaunchAgents/
/System/Library/StartupItems/
/System/Library/LaunchDaemons/
/System/Library/LaunchAgents/
~/Library/LaunchAgents/
```
To turn them off manually follow these steps:

#### Spotify

* Open the Spotify app
* Open the settings with `⌘,`
* Scroll down to the `Startup and window behaviour` section
* Set `Open Spotify automatically after you log into the computer` to `No`

#### Facebook Messenger

* Open the Messenger app
* Open the settings with `⌘,`
* Stay at the `General` tab
* Set `Open the Messenger desktop app when you start your computer` to `off`


```bash

# This script will open chrome apps to install

info () {
  printf "\r  [ \033[00;34m..\033[0m ] $1\n"
}

info "Opening Chrome Apps"

chrome_open() {
  /usr/bin/open -a "/Applications/Google Chrome.app" $1
}

echo ""
echo "› Chrome Apps:"
echo "  › 1Password chrome plugin"
chrome_open "https://chrome.google.com/webstore/detail/1password-%E2%80%93-password-mana/aeblfdkhhhdcdjpifhhbdiojplfjncoa"

echo "  › Google Meet progressive web app"
chrome_open "https://support.google.com/meet/answer/10708569?hl=en"

echo "  › FileZilla application"
chrome_open "https://filezilla-project.org/download.php?platform=osx"

echo "  › 8BitDo Firmware Updater"
chrome_open "https://support.8bitdo.com/firmware-updater.html"


```
