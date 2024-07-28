#!/usr/bin/env bash

dotfilesrepo="https://github.com/x1nigo/dotfiles.git"
srcdir="/home/*/.local/src"
mkdir -p /home/*/.local/src

intro() {
	echo "
----------------------------
W E L C O M E !
----------------------------

This is a minimal post-install script for Void Linux. Presumably,
you already have a user account + password.

Note: This should be run in the /root directory.

Once ready, just hit <ENTER>. Otherwise, hit <CTRL-C> to quit.
"
read -r enter
}

set_privileges() {
	echo "permit nopass :wheel" >> /etc/doas.conf
}

install_pkgs() {
	sed '/^#/d;/^$/d' progs.txt > /tmp/progs.txt
	while IFS=$'\n' read -r prog; do
		xbps-install -Sy "$prog"
	done < /tmp/progs.txt
}

compile_pkgs() {
	for dir in $(echo "dwm st dmenu"); do
		git -C "$srcdir" clone https://github.com/x1nigo/$dir.git
		cd "$srcdir"/"$dir" && make clean install
	done
}

get_dotfiles() {
	git -C "$srcdir" clone "$dotfilesrepo"
	cd "$srcdir"/dotfiles
	shopt -s dotglob
	rsync -vr  * /home/*/

	ln -s /home/*/.config/shell/shrc /home/*/.bashrc
	ln -s /home/*/.config/nvim/init.vim /home/*/.vimrc

update_udev() {
	mkdir -p /etc/X11/xorg.conf.d
	echo "Section \"InputClass\"
	Identifier \"touchpad\"
	Driver \"libinput\"
	MatchIsTouchpad \"on\"
		Option \"Tapping\" \"on\"
		Option \"NaturalScrolling\" \"on\"
EndSection" > /etc/X11/xorg.conf.d/30-touchpad.conf
}

cleanup() {
	cd
	rm -r ~/aos
	rm -r "$srcdir"/dotfiles
	rm -r /home/*/.git
	rm -r /home/*/README.md
	mkdir -p /home/*/.local/run
	find /home/*/.local/bin -type f -exec chmod +x {} \;
}

outro() {
	echo "
----------------------------
D O N E !
----------------------------

Congratulations! You now have a working linux system on your device. Hit
<ENTER> to reboot. User <CTRL-C> to cancel.
"
read -r enter
reboot
}

main() {
	intro
	set_privileges
	install_pkgs
	compile_pkgs
	get_dotfiles
	update_udev
	cleanup
	outro
}

main
