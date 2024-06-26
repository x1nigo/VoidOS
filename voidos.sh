#!/usr/bin/env bash

# Chris Iñigo's Bootstrapping Script for Void Linux
# by Chris Iñigo <https://github.com/x1nigo/voidos.git>

# Things to note:
# 	- Run this script as ROOT!
#	- Do not run this script via `sh`, we do not want to use `dash` but `bash`.

dotfilesrepo="https://github.com/x1nigo/dotfiles.git"

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

getupdate() {
	echo "
Updating repositories and installing dependencies...
"
	xbps-install -Syu # Sync and upgrade all packages before starting the main script.
	xbps-install -y rsync make || error "Failed to update repositories and install dependencies."
}

openingmsg() { cat << EOF

Welcome!

This script will install a fully-functioning linux desktop, which I hope may prove useful to you as it did for me.

EOF

printf "%s" "Press \`enter\` to continue"
read -r enter
}

getuserandpass(){
	# Prompts user for new username an password.
	printf "%s" "Enter your username: "
	read -r name
	printf "%s" "Enter your password: "
	read -r password
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo -e "$password\n$password" | passwd "$name" >/dev/null 2>&1
	unset password
}

permission() {
	echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/00-wheels-can-sudo
}

finalize () { cat << EOF

Done!

Congratulations, you now have a working system. Please restart the system and log in with your username and password.

EOF
}

### Main Installation ###

installpkgs() {
	sed -i '/^#/d' progs.csv
	while IFS=, read -r tag program description
	do
		case $tag in
			G) sudo -u $name git -C "$repodir" clone "$program" >/dev/null 2>&1 ;;
			*) xbps-install -y "$program" >/dev/null 2>&1 ;;
		esac
	done < progs.csv
}

getdotfiles() {
	sudo -u "$name" git -C "$repodir" clone "$dotfilesrepo" >/dev/null 2>&1
	cd "$repodir"/dotfiles
	shopt -s dotglob && sudo -u "$name" rsync -r * /home/$name/
 	# Link the .shrc file
	ln -sf /home/$name/.config/shell/shrc /home/$name/.shrc
 	cp /home/$name/.shrc /home/$name/.bashrc
  	# Create a .vimrc file from the neovim configuration
   	ln -s /home/$name/.config/nvim/init.vim /home/$name/.vimrc
}

updateudev() {
	mkdir -p /etc/X11/xorg.conf.d
	echo "Section \"InputClass\"
Identifier \"touchpad\"
Driver \"libinput\"
MatchIsTouchpad \"on\"
	Option \"Tapping\" \"on\"
	Option \"NaturalScrolling\" \"on\"
EndSection" > /etc/X11/xorg.conf.d/30-touchpad.conf || error "Failed to update the udev files."
}

compiless() {
	for dir in $(echo "dwm st dmenu"); do
		cd "$repodir"/"$dir" && sudo make clean install >/dev/null 2>&1
	done
}

removebeep() {
	rmmod pcspkr 2>/dev/null
	echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf || error "Failed to remove the beep sound. That's annoying."
}

cleanup() {
	cd # Return to root
 	rm -r ~/voidos
	rm -r "$repodir"/dotfiles
	rm -r /home/$name/.git
	rm -r /home/$name/README.md
 	sudo -u $name mkdir -p /home/$name/.config/gnupg/
	# Give gnupg folder the correct permissions.
  	find /home/$name/.config/gnupg -type f -exec chmod 600 {} \;
	find /home/$name/.config/gnupg -type d -exec chmod 700 {} \;
 	sudo -u $name mkdir -p /home/$name/.config/mpd/playlists/
 	sudo -u $name chmod -R +x /home/$name/.local/bin || error "Failed to remove unnecessary files and other cleaning."
}

changeshell() {
	chsh -s /bin/bash >/dev/null 2>&1
	chsh -s /bin/bash $name >/dev/null 2>&1
 	echo "
# Source the .profile file.
[ -f /home/$name/.profile ] && . /home/$name/.profile " >> /home/$name/.bash_profile || error "Could not change shell for the user."
}

depower() {
	echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00-wheels-can-sudo
	rm /etc/sudoers.d/wheel >/dev/null 2>&1 # Remove the spare wheel config file
	echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/poweroff,/usr/bin/reboot,/usr/bin/su,/usr/bin/make clean install,/usr/bin/make install,/usr/bin/xbps-install -Su,/usr/bin/xbps-install -S,/usr/bin/xbps-install -u,/usr/bin/mount,/usr/bin/umount,/usr/bin/cryptsetup,/usr/bin/simple-mtpfs,/usr/bin/fusermount" > /etc/sudoers.d/01-no-password-commands
}

### Main Function ###

# Installs dialog program to run alongside this script.
getupdate

# The opening message.
openingmsg

# Gets the username and password.
getuserandpass || error "Failed to get username and password."

# Add the username and password given earlier.
adduserandpass || error "Failed to add user and password."

# Grants unlimited permission to the root user (temporarily).
permission || error "Failed to change permissions for user."

# The main installation loop.
installpkgs || error "Failed to install the necessary packages."

# Install the dotfiles in the user's home directory.
getdotfiles || error "Failed to install the user's dotfiles."

# Updates udev rules to allow tapping and natural scrolling, etc.
updateudev

# Compiling suckless software.
compiless || error "Failed to compile all suckless software."

# Remove the beeping sound of your computer.
removebeep

# Cleans the files and directories.
cleanup

# Change shell of the user to `zsh`.
changeshell || error "Could not change shell for the user."

# De-power the user from infinite greatness.
depower || error "Could not bring back user from his God-like throne of sudo privilege."

# The closing message.
finalize
