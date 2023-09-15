#! /bin/sh

# Chris Iñigo's Void Script
# by Chris Iñigo <chris@x1nigo.xyz>

# This script assumes that you have already created
# a new username upon base installation.
# TODO: Run this script as ROOT!

username="$(ls /home/)"

error() {
	echo "$1" && exit
}

openingmsg() { cat << EOF
Introduction:

Welcome to the installation script for Chris Iñigo's Void Linux system!
This will install a fully-functioning linux desktop, which I hope may
prove useful to you as it did for me.

-Chris
EOF
}

areyouready() { cat << EOF
Are you ready to begin the installation? [Y/n]
EOF

read -r answer
[ "$answer" = "n" ] && exit
}

closingmsg() { cat << EOF
Installation complete! Assuming that there were no hidden errors from the
voidscript, then you're good to go!

You may log out of the current session and log back in with your username.
EOF
}

permission() {
	echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/00-wheels-can-sudo
}

create_dirs() {
	mkdir -p /media /mount
	cd /home/$username/
	sudo -u $username mkdir .config
	configdir="/home/$username/.config"
}

updatedirs() {
	sudo -u $username xdg-user-dirs-update
}

### Main Installation ###

installpkgs() {
	cd $configdir
	total=$(( $(wc -l < ~/voidscript/progs.csv) -1 ))
	n=0
	while IFS="," read -r type program description
	do
		echo "Installing \`$program\` ($n of $total). $description."
		case $type in
			G) sudo -u $username git clone https://github.com/x1nigo/$program.git >/dev/null 2>&1 ;;
			*) sudo -u $username xbps-install -S "$program" >/dev/null 2>&1 ;;
		esac
	done < ~/voidscript/progs.csv
}

movefiles() {
	cd $configdir/dotfiles &&
	shopt -s dotglob &&
	sudo -u $username mv .config/* $configdir/
	sudo -u $username mv * /home/$username/

	sucklessdir="/home/$username/.local/src"
	sudo -u $username mkdir -p $sucklessdir
}

updateudev() {
	echo "Section \"InputClass\"
Identifier \"touchpad\"
Driver \"libinput\"
MatchIsTouchpad \"on\"
	Option \"Tapping\" \"on\"
	Option \"NaturalScrolling\" \"on\"
EndSection" > /etc/X11/xorg.conf.d/30-touchpad.conf
}

compilesuckless() {
	echo "Compiling suckless software..."
	cd $configdir/dwm && sudo -u $username sudo make clean install >/dev/null 2>&1
	cd $configdir/st && sudo -u $username sudo make clean install >/dev/null 2>&1
	cd $configdir/dmenu && sudo -u $username sudo make clean install >/dev/null 2>&1
	cd $configdir/dwmblocks && sudo -u $username sudo make clean install >/dev/null 2>&1
	# Relocate to the ~/.local/src directory.
	sudo -u $username mv $configdir/dwm $sucklessdir >/dev/null 2>&1
	sudo -u $username mv $configdir/st $sucklessdir >/dev/null 2>&1
	sudo -u $username mv $configdir/dmenu $sucklessdir >/dev/null 2>&1
	sudo -u $username mv $configdir/dwmblocks $sucklessdir >/dev/null 2>&1
}

filemanager() {
	cd $configdir/lf
	sudo -u $username sudo mv lfrun /usr/bin/lfrun && sudo -u $username sudo chmod +x /usr/bin/lfrun &&
	sudo -u $username chmod +x /home/$username/.config/lf/cleaner /home/$username/.config/lf/scope
}

removebeep() {
	rmmod pcspkr 2>/dev/null
	echo "blacklist pcspkr" >/etc/modprobe.d/nobeep.conf
}

cleanthis() {
	rm -r ~/voidscript $configdir/dotfiles /home/$username/README.md
	sudo -u $username mkdir /home/$username/.config/gnupg/ &&
	sudo -u $username mkdir -p /home/$username/.config/mpd/playlists/ &&
	sudo -u $username chmod +x /home/$username/.local/bin/* /home/$username/.local/bin/statusbar/* || error "Failed to remove unnecessary files and other cleaning."
}

changeshell() {
	chsh -s /bin/zsh $username >/dev/null 2>&1
}

depower() {
	echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/00-wheels-can-sudo
	rm /etc/sudoers.d/wheel # Remove the spare wheel config file
	echo "%wheel ALL=(ALL:ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/poweroff,/usr/bin/reboot,/usr/bin/su,/usr/bin/make clean install,/usr/bin/xbps-install -Su,/usr/bin/xbps-install -S,/usr/bin/xbps-install -u,/usr/bin/mount,/usr/bin/umount,/usr/bin/cryptsetup,/usr/bin/simple-mtpfs,/usr/bin/fusermount" > /etc/sudoers.d/01-no-password-commands
}

### Main Function ###

openingmsg || error "Failed to show opening message."
areyouready || error "Failed to prompt the user properly."
permission || error "Failed to change permissions for user."
create_dirs || error "Failed to create directories properly."
installpkgs || error "Failed to install the necessary packages."
update_dirs || error "Could not update home directories."
movefiles || error "Failed to move all filed accordingly."
updateudev || error "Failed to update the udev files."
compilesuckless || error "Failed to compile all suckless software."
filemanager || error "Failed to install LF (file manager)."
removebeep || error "Failed to remove the beep sound."
cleanthis || error "Failed to clean up files and directories."
changeshell || error "Could not change shell."
depower || error "Could not bring back user from his God-like throne of sudo privilege."
closingmsg || error "Could not accomplish the closing message."

### Installation Done! ###
exit
