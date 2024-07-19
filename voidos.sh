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

openingmsg() {
	echo -e "
\e[1;32mWELCOME!\e[m
"

	echo "
This script will install a fully-functioning linux environment, which I hope may prove useful to you as it did for me.
"

printf "%s" "Press <ENTER> to continue"
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
	useradd -m -g wheel "$name"
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo -e "$password\n$password" | passwd "$name"
	unset password
}

godmode() {
	# Configures the system for both `sudo` and `doas.`
	echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/00-no-security
	echo "permit persist keepenv :wheel
permit nopass :wheel" > /etc/doas.conf
}

finalize () {
    echo -e "\e[1;32m
 ____                     _
|  _ \  ___  _ __   ___  | |
| | | |/ _ \| '_ \ / _ \ | |
| |_| | (_) | | | |  __/ |_|
|____/ \___/|_| |_|\___| (_)
\e[m"

    echo "
CONGRATULATIONS, you now have a working system on your computer!
Type \"r\" to reboot the system.
"

keys() {
    case "$input" in
        r) reboot ;;
        *) ;; # Do nothing
    esac
}
# Allow only a single input to be read
for ((;;)); {
    read -srn 1 input && keys
}

}

### Main Installation ###

installpkgs() {
	sed -i '/^#/d' progs.csv
	while IFS=, read -r tag program description
	do
		case $tag in
			G) sudo -u $name git -C "$repodir" clone "$program" ;;
			*) xbps-install -y "$program" ;;
		esac
	done < progs.csv
}

getdotfiles() {
	sudo -u "$name" git -C "$repodir" clone "$dotfilesrepo"
	cd "$repodir"/dotfiles
	shopt -s dotglob && sudo -u "$name" rsync -r * /home/$name/
 	# Link the .shrc file
	ln -sf /home/$name/.config/shell/shrc /home/$name/.shrc
 	cp /home/$name/.shrc /home/$name/.bashrc
  	# Create a .vimrc file from the neovim configuration
   	ln -sf /home/$name/.config/nvim/init.vim /home/$name/.vimrc
	sudo -u "$name" mkdir /home/$name/.vim
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

compile() {
	for dir in $(echo "dwm st dmenu"); do
		cd "$repodir"/"$dir" && sudo make clean install
	done
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

sourceprofile() {
 	echo "
# Source the .profile file.
[ -f /home/$name/.profile ] && . /home/$name/.profile " >> /home/$name/.bash_profile || error "Could not change shell for the user."
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

# Grants God-like privileges to the user.
godmode || error "Failed to change permissions for user."

# The main installation loop.
installpkgs || error "Failed to install the necessary packages."

# Install the dotfiles in the user's home directory.
getdotfiles || error "Failed to install the user's dotfiles."

# Updates udev rules to allow tapping and natural scrolling, etc.
updateudev

# Compiling suckless software.
compile || error "Failed to compile all suckless software."

# Cleans the files and directories.
cleanup

# Change shell of the user to `zsh`.
sourceprofile || error "Could not change shell for the user."

# The closing message.
finalize
