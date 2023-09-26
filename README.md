# Void-OS

This is my bootstrapping script for void linux.

## Requirements

- A newly installed void linux system.
- An internet connection.
- Make sure you run this script as `root`.

```
git clone https://github.com/x1nigo/void-os.git
cd void-os
chmod +x void-os.sh && ./void-os.sh
```
## What does it install?
Aside from the programs listed in `progs.csv`, void-os installs my configuration files and my other suckless software repositories:
- [dotfiles](https://github.com/x1nigo/dotfiles) &ndash; My dotfiles
- [dwm](https://github.com/x1nigo/dwm) &ndash; The window manager
- [st](https://github.com/x1nigo/st) &ndash; The terminal emulator
- [dmenu](https://github.com/x1nigo/dmenu) &ndash; The dynamic menu launcher
- [dwmblocks](https://github.com/x1nigo/dwmblocks) &ndash; The status bar
