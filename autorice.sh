#!/bin/bash
# {{{ Header
# Author: Jordan Schupbach
# Filename: autorice.sh
# Date Initialized: August 2, 2018
# Date Modified: August 2, 2018
# Description:
#   A bash script that configures my system
# }}} Header

# {{{ Options and Variables

while getopts ":a:r:p:h" o; do case "${o}" in
	h) echo -e "Optional arguments for custom use:\n  -r: Dotfiles repository (local file or url)\n  -p: Dependencies and programs csv (local file or url)\n  -a: AUR helper (must have pacman-like syntax)\n  -h: Show this message" && exit ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote $dotfilesrepo || exit ;;
	p) progsfile=${OPTARG} ;;
	a) aurhelper=${OPTARG} ;;
	*) echo "-$OPTARG is not a valid option." && exit ;;
esac done

# DEFAULTS:
[ -z ${dotfilesrepo+x} ] && dotfilesrepo="https://github.com/jordans1882/dotfiles.git"
[ -z ${progsfile+x} ] && progsfile="https://raw.githubusercontent.com/jordans1882/autorice_script/master/progs.csv"
[ -z ${aurhelper+x} ] && aurhelper="trizen-git"

# }}} Options and Variables

# {{{ Functions

initialcheck() { pacman -S --noconfirm --needed dialog || { echo "Are you sure you're running this as the root user? Are you sure you're using an Arch-based distro? ;-) Are you sure you have an internet connection?"; exit; } ;}

preinstallmsg() { \
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\n\nIt will take some time, but when done, you can relax even more with your complete system.\n\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit; }
	}

welcomemsg() { \
	dialog --title "Welcome!" --msgbox "Welcome to Jordan's autorice script!\n\nThis script will automatically install a fully-featured Arch Linux desktop, which I use as my main machine.\n\n-Jordan" 10 60
	}

refreshkeys() { \
	dialog --infobox "Refreshing Arch Keyring..." 4 40
	pacman --noconfirm -Sy archlinux-keyring &>/dev/null
	}

getuserandpass() { \
	# Prompts user for new username an password.
	# Checks if username is valid and confirms passwd.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit
	namere="^[a-z_][a-z0-9_-]*$"
	while ! [[ "${name}" =~ ${namere} ]]; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [[ ${pass1} == ${pass2} ]]; do
		unset pass2
		pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\n\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

usercheck() { \
	! (id -u $name &>/dev/null) ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. This install script can install for a user already existing, but it will \Zboverwrite\Zn any conflicting settings/dotfiles on the user account.\n\nIt will \Zbnot\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\n\nNote also that the script will change $name's password to the one you just gave." 14 70
	}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -g wheel -s /bin/bash $name &>/dev/null ||
	usermod -a -G wheel $name && mkdir -p /home/$name && chown $name:wheel /home/$name
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

fontinstall() {
	# Install UbuntuMono Nerd font
	mkdir -p ~/.local/share/fonts
	cd ~/.local/share/fonts && curl -fLo "Droid Sans Mono for Powerline Nerd Font Complete.otf" https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/DroidSansMono/complete/Droid%20Sans%20Mono%20Nerd%20Font%20Complete.otf
	}

gitmakeinstall() {
	dir=$(mktemp -d)
	dialog --title "Autorice Installation" --infobox "Installing \`$(basename $1)\` ($n of $total) via \`git\` and \`make\`. $(basename $1) $2." 5 70
	git clone --depth 1 "$1" $dir &>/dev/null
	cd $dir
	make &>/dev/null
	make install &>/dev/null
	cd /tmp ;}

maininstall() { # Installs all needed programs from main repo.
	dialog --title "Autorice Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2." 5 70
	pacman --noconfirm --needed -S "$1" &>/dev/null
	}

aurinstall() { \
	dialog --title "Autorice Installation" --infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2." 5 70
	grep "^$1$" <<< "$aurinstalled" && return
	sudo -u $name $aurhelper -S --noconfirm "$1" &>/dev/null
	}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	aurinstalled=$(pacman -Qm | awk '{print $1}')
	while IFS=, read -r tag program comment; do
	n=$((n+1))
	case "$tag" in
	"") maininstall "$program" "$comment" ;;
	"A") aurinstall "$program" "$comment" ;;
	"G") gitmakeinstall "$program" "$comment" ;;
	esac
	done < /tmp/progs.csv ;}

serviceinit() { for service in $@; do
	dialog --infobox "Enabling \"$service\"..." 4 40
	systemctl enable "$service"
	systemctl start "$service"
	done ;}

newperms() { # Set special sudoers settings for install (or after).
	sed -i "/#LARBS/d" /etc/sudoers
	echo -e "$@ #LARBS" >> /etc/sudoers ;}

systembeepoff() { dialog --infobox "Getting rid of annoying sytem beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

putgitrepo() { # Downlods a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --infobox "Downloading and installing config files..." 4 60
	dir=$(mktemp -d)
	chown -R $name:wheel $dir
	sudo -u $name git clone --depth 1 $1 $dir/gitrepo &>/dev/null &&
	sudo -u $name mkdir -p "$2" &&
	sudo -u $name cp -rT $dir/gitrepo $2
	}

resetpulse() { dialog --infobox "Reseting Pulseaudio..." 4 50
	killall pulseaudio &&
	sudo -n $name pulseaudio --start ;}

manualinstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[[ -f /usr/bin/$1 ]] || (
	dialog --infobox "Installing \"$1\", an AUR helper..." 10 60
	cd /tmp
	rm -rf /tmp/$1*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz &&
	sudo -u $name tar -xvf $1.tar.gz &>/dev/null &&
	cd $1 &&
	sudo -u $name makepkg --noconfirm -si &>/dev/null
	cd /tmp) ;}

finalize(){ \
	dialog --infobox "Preparing welcome message..." 4 50
	echo "exec_always --no-startup-id notify-send -i ~/.scripts/larbs.png '<b>Welcome to the Autorice script:</b> Press Super+F1 for the manual.' -t 10000"  >> /home/$name/.config/i3/config
	dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\n\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"startx\" to start the graphical environment.\n\n-Jordan" 12 80
	}


# }}} Functions

# {{{ Install Script

# Check if user is root on Arch distro. Install dialog.
initialcheck

# Welcome user.
welcomemsg || { clear; exit; }

# Get and verify username and password.
getuserandpass

# Give warning if user already exists.
usercheck || { clear; exit; }

# Last chance for user to back out before install.
preinstallmsg || { clear; exit; }

### The rest of the script requires no user input.

adduserandpass

# Refresh Arch keyrings.
refreshkeys

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
newperms "%wheel ALL=(ALL) NOPASSWD: ALL"

# Install Trizen
manualinstall $aurhelper

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop

# Install the dotfiles in the user's home directory
putgitrepo "$dotfilesrepo" "/home/$name"

# Install the LARBS Firefox profile in ~/.mozilla/firefox/
# TODO: look into Luke's Firefox profile
# putgitrepo "https://github.com/LukeSmithxyz/mozillarbs.git" "/home/$name/.mozilla/firefox"

# TODO: Check to see if I want pulse Audio or if ALSA works well enough
# Pulseaudio, if/when initially installed, often needs a restart to work immediately.
[[ -f /usr/bin/pulseaudio ]] && resetpulse

# Enable services here.
serviceinit NetworkManager cronie

# Most important command! Get rid of the beep!
systembeepoff

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
# TODO: change packer to trizen?
newperms "%wheel ALL=(ALL) ALL\n%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/reboot,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syyu,/usr/bin/packer -Syu,/usr/bin/packer -Syyu,/usr/bin/systemctl restart NetworkManager,/usr/bin/rc-service NetworkManager restart, /usr/bin/pacman -Syyu --noconfirm"

# Last message! Install complete!
finalize
clear

# }}} Install Script

# {{{ Old stuffs
# # {{{ Linux
# # {{{ Check if on linux
# if [[ "$OSTYPE" == "linux-gnu" ]]; then
#   HASLINUX=TRUE
# # }}} Check if on linux
#   # {{{ Check for permisions
#   if [ $EUID != 0 ]; then
#     sudo "$0" "$@"
#     exit $?
#   fi
#   # }}} Check for permisions
#   # {{{ Obtain Linux Distrobution
#   OSNAMESTRING="$(cat /etc/os-release | grep -m 1 'NAME')"
#   echo $OSNAMESTRING
#   ARCH="Arch"
#   UBUNTU="Ubuntu"
#   # }}} Obtain Linux Distrobution
#
#   # Distrobution specific setup:
#   # {{{ Ubuntu
#     if [ -z "${OSNAMESTRING##*$UBUNTU*}" ] ;then
#       echo "I'm sorry, but you are working on an inferior linux distrobution."
#     fi
#   # }}} Ubuntu
#   # {{{ Arch Linux
#     if [ -z "${OSNAMESTRING##*$ARCH*}" ] ;then
#       echo "You have Arch Linux! Lucky you and smart choice!"
#       sudo pacman -S dialog
#     fi
#   # }}} Arch Linux
# fi
# # }}} Linux
# # {{{ Other Systems
# # TODO: Windows, Mac, ...
# # elif [[ "$OSTYPE" == "darwin"* ]]; then
# #         # Mac OSX
# # elif [[ "$OSTYPE" == "cygwin" ]]; then
# #         # POSIX compatibility layer and Linux environment emulation for Windows
# # elif [[ "$OSTYPE" == "msys" ]]; then
# #         # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
# # elif [[ "$OSTYPE" == "win32" ]]; then
# #         # I'm not sure this can happen.
# # elif [[ "$OSTYPE" == "freebsd"* ]]; then
# #         # ...
# # else
# #         # Unknown.
# # }}} Other Systems
# }}} Old stuffs

# {{{ Vim modelines
# vim: set foldmethod=marker:
# }}} Vim modelines
