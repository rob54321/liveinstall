#!/bin/bash
# this script runs in the chroot environment.
# but when ubuntu-mate is installed on the desktop
# the features installed from this script are
# also installed in the desktop.

# this script edits fstab
# upgrades packages if the option is given
# installs packages if the option is given
# and sets up the editfstab.service so the live
# system can edit it's fstab after each boot.
# this is necessary with ubuntu live since
# the fstab in the chroot environment is not copied
# to the to the live system.
# It also sets up multi-user.target
# and sets the fonts in /etc/default/console-setup

# debhome.sources and debhomepubkey.asc must be installed
# before this script is run.This script liveinstall is a debian
# package and installed my makelive.pl

# updgrade and extra packages are passed as a command live arguments
# to this script
# liveinstall.sh "param1" "param2" "param3" "param4"
# param1 is debhome device label
# param2 is the status of the mount of debhome dev, ro, rw or not mounted
# param3 can be "upgrade"|"" for no upgrade
# param4 can be "pkg1 pkg2 ..."|"" for no packages
# the script exits with 1 if there was an error
# otherwise it exits with 0.

# function to exit with status 1
# the debhomedev is unmounted first
# the rc code is passed as first parameter, no exit on 0, exit on 1, 2, 3..
# second parameter is the error string
exitonerror() {
	# test rc code
	if test $1 -ne 0; then
		# display error string
		echo "$2"
		umount "/mnt/$DEBHOMEDEV"
		if test $? -ne 0; then
			echo "Could not umount $DEBHOMEDEV from /mnt/$DEBHOMEDEV"
			exit 2;
		fi
		exit 1;
	fi
}
# function to setup editfstab service
# which will run after every boot
# to edit the fstab file in the live system.
editfstabservice() {
	echo "[Unit]
	Description=Edit fstab in the live system after each boot.

	[Service]
	Type=simple
	ExecStart=/usr/bin/perl /usr/local/bin/editfstab -e

	[Install]
	WantedBy=multi-user.target" > /etc/systemd/system/editfstab.service

	# set mode for init-rpi.service
	chmod 0644 /etc/systemd/system/editfstab.service

	# enable the service for the next boot
	systemctl enable editfstab
}
usage() {
echo "-d debhomedevice"
echo "-u for upgrade"
echo "-p package list; p1 p2 .."
exit 0;
}

# main entry point
export LC_ALL=C
PACKAGES="";
UPGRADE="";

while getopts d:s:up:h opt
do
	case ${opt} in
		d) DEBHOMEDEV="${OPTARG}";;
		u) UPGRADE="upgrade";;
		p) PACKAGES="${OPTARG}";;
		h) usage;;
		\?) usage;;
	esac
done

# make the directories for /mnt
editfstab -d
exitonerror $? "editfstab exited with error"

# make the directory /dochroot to indicate
# a do chroot was done.
#if the directory exists, delete filesystem.squashfs
# if it exists because the filesystem has changed.
if test -d /dochroot; then
	test -f /dochroot/filesystem.squashfs && rm -vf /dochroot/filesystem.squashfs
else
	mkdir /dochroot
fi

# the key and debhome.sources was added by makelive.pl
# check if full upgrade must be done
#echo "no of params: $#"


if test "${UPGRADE}" = "upgrade"; then

	# install linux-image generic so vmlinuz and initrd
	# can be copied to a temp directory oldboot
	# then makelive can copy to the casper directory
	# when the disk is mounted
	apt -y install linux-image-generic
	# check for success
	exitonerror $? "Could not install linux-image-generic"

	apt -y full-upgrade
	# check for success
	exitonerror $? "apt ended with error on full-upgrade"

	# mkdir directory upgrade to indicate and upgrade was done
	# if the directory does not already exist
	test -d /upgrade || mkdir /upgrade
fi

# check if there are packages to install
if [ "${PACKAGES}" != "" ]
then
	apt -y install ${PACKAGES}
	# check for success
	exitonerror $? "Could not install packages: $4"

	# make a directory packages in chroot
	# store list of packages in there
	test -d /packages || mkdir /packages

	#copy list of packages to file date.time.txt
	echo "${PACKAGES}" >> /packages/extrapackages.txt
fi

# remove any obsolete packages
apt -y autoremove

# if the linux image is the latest version, as in a recent iso image
# no image will be installed when the upgrade is done
# and the /boot will not have a vmlinuz or initrd.
# if /boot contains no vmlinuz and initrd.img then
# the latest vmlinuz , initrd.img is on cdrom/casper

if test -s /boot/vmlinuz; then
	test -d /oldboot || mkdir /oldboot
	cp -v -f -L /boot/vmlinuz /oldboot/vmlinuz
	cp -v -f -L /boot/initrd.img /oldboot/initrd

	# check existence of vmlinuz and initrd
	test -f /oldboot/vmlinuz || exitonerror $? "/oldboot/vmlinuz does not exist"
	test -f /oldboot/initrd || exitonerror $? "/oldboot/initrd does not exist"
fi

# rm vmlinuz-xxxx-generic and initrd.img-xxxx-generic from the boot directory
# they will take up space in filesystems.squashfs and not needed.
# vmlinuz and initrd are already in the casper directory
rm -v -f /boot/vmlinuz-*-generic
rm -v -f /boot/initrd.img-*-generic

# set boot to command line
systemctl set-default multi-user.target

# setup console fonts
sed -i -e 's/^FONTFACE=.*/FONTFACE=\"Terminus\"/' /etc/default/console-setup
sed -i -e 's/^FONTSIZE=.*/FONTSIZE=\"16x32\"/' /etc/default/console-setup
setupcon --save >/dev/null 2>/dev/null


#############################################
# setup service to edit fstab after each boot in the live
# editfstabservice

#############################################

# make all the /mnt directories

exit 0
