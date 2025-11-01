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
# liveinstall.sh -u (upgrade) -p (packages) or none
# the script exits with 1 if there was an error
# otherwise it exits with 0.

# function to exit with status 1
# the directories /mnt/debhome and /mnt/svn
# which must exist, are bound to svn and debhome.
# they are deleted and replaced with links to svn and debhome
# when unbinding takes place after liveinstall exits.

###########################################################################
# the rc code is passed as first parameter, no exit on 0, exit on 1, 2, 3..
# second parameter is the error string
exitonerror() {
	# test rc code
	if test $1 -ne 0; then
		# display error string
		echo "$2"
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
	WantedBy=${TARGET}" > /etc/systemd/system/editfstab.service

	# set mode for init-rpi.service
	chmod 0644 /etc/systemd/system/editfstab.service

	# enable the service for the next boot
	systemctl enable editfstab
}
usage() {
echo "-u for upgrade"
echo "-g set graphical.target, default is multi-user.target"
echo "-n set multi-user.target"
echo "-p package list; p1 p2 .."
echo "-h this help message"
exit 0;
}

# main entry point
# set default target
TARGET="multi-user.target"
export LC_ALL=C
PACKAGES="";
UPGRADE="";

while getopts gnup:h opt
do
	case ${opt} in
		u) UPGRADE="upgrade";;
		g) TARGET="graphical.target";;
		n) TARGET="multi-user.target";;
		p) PACKAGES="${OPTARG}";;
		h) usage;;
		\?) usage;;
	esac
done

echo "++++++++++++++++++++++++++++++PACKAGE LIST++++++++++++++++++++++++++++++++++++"
echo "+++++++++++++++++++++++++++++++packages = :${PACKAGES}:+++"
echo "+++++++++++++++++++++++++++++++target = :${TARGET}:++++++"
echo "+++++++++++++++++++++++++++++++upgrade = :${UPGRADE}:+++++"
echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"

# make the directory /dochroot to indicate
# a do chroot was done.
#if the directory exists, delete filesystem.squashfs
# if it exists because the filesystem has changed.
if test -d /dochroot; then
	test -f /dochroot/filesystem.squashfs && rm -vf /dochroot/filesystem.squashfs
else
	mkdir /dochroot
fi

# set the target here so everytime liveinstall.sh is run
# it can be changed
echo "Setting default target to : ${TARGET}"
systemctl set-default "${TARGET}"

# execute init-linux which will make user robert.
# it must only be executed once, so if the file
# /chroot/dochroot/initialise-linux exists
# init-linux has already been run
# the -L switch is to indicate init-linux is being
# run from liveinstall
if ! test -f /dochroot/init-linux; then
	echo "======================================================================================"
	echo "running init-linux"
	echo "======================================================================================"
	# run init-linux for the live system in the chroot environment
	/usr/local/bin/init-linux -L

	# check return status
	RC=$?

	test ${RC} -eq 0 || exitonerror ${RC} "init-linux exited with error"
	echo "======================================================================================"
	echo "finished running init-linux"
	echo "======================================================================================"

else
	# /dochroot/init-linux exists
	# init-linux has already run
	echo "======================================================================================"
	echo "init-linux has already been run"
	echo "======================================================================================"
fi

# install the kernel and modules for the default kernel in the cdrom.
# the verssion is in the chroot environment /isoimagekernelversion.txt
# this is done so the dpkg status file accurately depicts the
# file installed.
# only install if it is not already installed.
# there could be multiple runs of this fiile

#VERSION=`cat /isoimage/kernelversion.txt`
#dpkg-query -W linux-image-${VERSION}
#if test $? != 0; then
#	apt install linux-image-${VERSION}-generic linux-modules-${VERSION}-generic linux-headers-${VERSION} linux-modules-extra-${VERSION}-generic -y

	# also hold these packages so they do
	# not get upgraded
#	apt-mark hold linux-image-${VERSION}-generic linux-modules-${VERSION}-generic linux-headers-${VERSION} linux-modules-extra-${VERSION}-generic
#fi

# make the directories for /mnt
editfstab -d
exitonerror $? "editfstab exited with error"

# the key and debhome.sources was added by makelive.pl
# check if full upgrade must be done
#echo "no of params: $#"


if test "${UPGRADE}" = "upgrade"; then

	# install linux-image generic so vmlinuz and initrd
	# can be copied to a temp directory oldboot
	# then makelive can copy to the casper directory
	# when the disk is mounted
	# apt -y install linux-image-generic
	# check for success
	# exitonerror $? "Could not install linux-image-generic"

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
# above is true for versions < 24.04
# if squashfsfilename.txt contains filesystem.squashfs
# implies version < 24.04 then copy vmlinuz and initrd to oldboot
if [[ -s /boot/vmlinuz && `cat /isoimage/squashfsfilename.txt` == "filesystem.squashfs" ]]; then
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
# rm -v -f /boot/vmlinuz-*-generic
# rm -v -f /boot/initrd.img-*-generic

######################################################################
# systemctl set-default is in init-linux which is run from makelive.pl
######################################################################

# setup console fonts
sed -i -e 's/^FONTFACE=.*/FONTFACE=\"Terminus\"/' /etc/default/console-setup
sed -i -e 's/^FONTSIZE=.*/FONTSIZE=\"16x32\"/' /etc/default/console-setup
setupcon --save >/dev/null 2>/dev/null


#############################################
# setup service to edit fstab after each boot in the live
editfstabservice

#############################################

# make all the /mnt directories

exit 0
