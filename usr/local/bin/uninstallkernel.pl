#!/usr/bin/perl
use strict;
use warnings;

#####################################################################
# sub to uninstall packages.
# parameter: a package wild card to uninstall
# return: nothing
# dies on any errors
# called by liveinstall.sh in the chroot environment
#####################################################################
sub uninstall {

	# get the parameter
	my $pattern = shift @_;
		
	# get package list with status
	# each line: package_name install ok installed
	# or         package_name unknown ok not-installed
	# or         package_name install ok not-installed

	my @list = `dpkg-query -W -f \'\${Package} \${status}\n\' $pattern`;
	chomp @list;

	# get the default kernel verson from kernelversion.txt
	open FH, "<", "/isoimage/defaultkernel.txt" or die "Could not open defaultkernel.txt: $!\n";
	my $defaultkernel = <FH>;
	close FH;
	chomp $defaultkernel;

	# for each element in list uninstall the kernel, headers, modules if it is not the default
	# and it is installed.
	foreach my $line (@list) {
		# get package name 
		$line =~ /^([a-zA-Z-\.\+\d+]+?)\s+/;
		my $package = $1;
		# get status
		$line =~ /\s+([a-zA-Z-]+?)$/;
		my $status = $1;

		print "package = $package; status = $status\n\n";

		#
		
	}
}

print "Enter the package pattern to uninstall\n";
my $pattern = <STDIN>;
chomp $pattern;
uninstall ($pattern);
