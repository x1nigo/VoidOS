#!/bin/bash

# Chris Iñigo's Bootstrapping Script for Void Linux
# by Chris Iñigo <chris@x1nigo.xyz>

# Things to note:
# 	- Run this script as ROOT!

progsfile="https://raw.githubusercontent.com/x1nigo/voidscript/main/progs.csv"
dotfilesrepo="https://github.com/x1nigo/dotfiles.git"

error() {
	# Log to stderr and exit with failure.
	printf "%s\n" "$1" >&2
	exit 1
}

getdialog() {
	echo "
Updating repositories and installing dependencies...
"
	xbps-install -Syu dialog curl rsync || "Failed to update repositories and install dependencies."
}

openingmsg() {
	dialog --title "Introduction" \
		--msgbox "Welcome to Chris Iñigo's Bootstrapping Script for Void Linux! This will install a fully-functioning linux desktop, which I hope may prove useful to you as it did for me.\\n\\n-Chris" 12 60 || error "Failed to show opening message."
}

getuserandpass(){
	# Prompts user for new username an password.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(dialog --nocancel --inputbox "Username not valid. Give a name beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --nocancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --nocancel --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --nocancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
}

preinstallmsg() {
	dialog --title "Resolution" \
		--yes-button "Let's go!" \
		--no-button "I...I can barely stand." \
		--yesno "The installation script will be fully automated from this point onwards.\\n\\nAre you ready to begin?" 12 60 || {
		clear
		exit 1
	}
}

adduserandpass() {
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 7 50
	useradd -m -g wheel -s /bin/zsh "$name" >/dev/null 2>&1 ||
		usermod -a -G wheel,lp,audio,video,network "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo -e "$pass1\n$pass1" | passwd "$name"
	unset pass1 pass2
}

permission() {
	echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/00-wheels-can-sudo
}

finalize () {
	dialog --title "Done!" --msgbox "Installation complete! If you see this message, then there's a pretty good chance that there were no (hidden) errors. You may log out and log back in with your new name.\\n\\n-Chris" 12 60
}

### Main Installation ###

installpkgs() {
	curl -Ls "$progsfile" > /tmp/progs.csv
	total=$(( $(wc -l < /tmp/progs.csv) -1 ))
	n=0
	while IFS="," read -r tag program description
	do
		dialog --infobox "Installing \`$program\` ($n of $total). $description." 8 70
		case $tag in
			G) n=$(( n + 1 )) && sudo -u $name git -C "$repodir" clone "$program" >/dev/null 2>&1 ;;
			*) n=$(( n + 1 )) && xbps-install -y "$program" >/dev/null 2>&1 ;;
		esac
	done < /tmp/progs.csv
}

getdotfiles() {
	dialog --infobox "Downloading and installing config files..." 7 60
	sudo -u "$name" git -C "$repodir" clone "$dotfilesrepo" >/dev/null 2>&1
	cd "$repodir"/dotfiles
	shopt -s dotglob && sudo -u "$name" rsync -r * /home/$name/
	# Install the file manager.
	cd /home/$name/.config/lf && chmod +x lfrun scope cleaner && sudo -u "$name" mv lfrun /usr/bin
	# Install gruvbox gtk theme for the system.
	cd "$repodir"/Gruvbox-GTK-Theme && sudo -u "$name" mv themes /home/$name/.local/share && sudo -u "$name" mv icons /home/$name/.local/share
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

compilesuckless() {
	dialog --infobox "Compiling suckless software..." 7 40
	for dir in $(echo "dwm st dmenu dwmblocks"); do
		cd "$repodir"/"$dir" && sudo make clean install >/dev/null 2>&1
	done
}

removebeep() {
	rmmod pcspkr 2>/dev/null
	echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf || error "Failed to remove the beep sound. That's annoying."
}

cleanup() {
	cd # Return to root
 	rm -r ~/voidscript ; rm /tmp/progs.csv
	rm -r "$repodir"/dotfiles "$repodir"/Gruvbox-GTK-Theme
	rm -r /home/$name/.git
	rm -r /home/$name/README.md
 	sudo -u $name mkdir -p /home/$name/.config/gnupg/
 	sudo -u $name mkdir -p /home/$name/.config/mpd/playlists/
 	sudo -u $name chmod +x /home/$name/.local/bin/* /home/$name/.local/bin/statusbar/* || error "Failed to remove unnecessary files and other cleaning."
}

changeshell() {
	chsh -s /bin/zsh $name >/dev/null 2>&1
	echo "# .bashrc

alias ls='ls --color=auto'
PS1='\[\e[1;31m[\u@\h \W]\e[0m\]\$ '" > ~/.bashrc || error "Could not change shell for the user."
}

depower() {
	echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00-wheels-can-sudo
	rm /etc/sudoers.d/wheel >/dev/null 2>&1 # Remove the spare wheel config file
	echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/poweroff,/usr/bin/reboot,/usr/bin/su,/usr/bin/make clean install,/usr/bin/xbps-install -Su,/usr/bin/xbps-install -S,/usr/bin/xbps-install -u,/usr/bin/mount,/usr/bin/umount,/usr/bin/cryptsetup,/usr/bin/simple-mtpfs,/usr/bin/fusermount" > /etc/sudoers.d/01-no-password-commands
} || error "Could not bring back user from his God-like throne of sudo privilege."


### Main Function ###

# Installs dialog program to run alongside this script.
getdialog

# The opening message.
openingmsg

# Gets the username and password.
getuserandpass || error "Failed to get username and password."

# The pre-install message. Last chance to get out of this.
preinstallmsg|| error "Failed to prompt the user properly."

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
compilesuckless || error "Failed to compile all suckless software."

# Remove the beeping sound of your computer.
removebeep

# Cleans the files and directories.
cleanup

# Change shell of the user to `zsh`.
changeshell

# De-power the user from infinite greatness.
depower
# The closing message.
finalize
