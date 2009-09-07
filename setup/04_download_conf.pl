#!/usr/bin/perl


use Cwd;
use File::Copy;
use Data::Dumper;
use strict;

sub readConf {
		my $filetoread;
		my $line;
	if (-f "/etc/dotmobile.us/conf" ) {
		$filetoread="/etc/dotmobile.us/conf";
		print "Reading Config file from $filetoread\n";
	} elsif (-f getcwd()."/conf.new" ) {
		$filetoread=getcwd()."/conf.new";
		print "Reading Config file from $filetoread\n";		
	} else {
		print "No config file found, starting from scratch";
		return;
	}
	open(CONF,"<$filetoread");
	my @tmparr;
	my $varhash={};
	while ($line=<CONF>){
		chomp($line);
		if ($line =~ /.*=.*/) {
			@tmparr=split(/=/,$line);
			$varhash->{@tmparr[0]}=@tmparr[1];
		}
	}
	return $varhash;
}

print "----------------------------------------------\n";
print "-Apple Config Setup Script                  -\n";
print "-dotMobile.us Project                        -\n";
print "-http://dotmac.googlecode.com                -\n";
print "----------------------------------------------\n";
print "\n";
print "\n";
print "This script will download and modify the configuration files from configuration.apple.com\n";
print "\n";
print "\n";

if (-e getcwd()."/.setupdir") {
	print "Good, you are running from the setup directory\n";
}else {
	print "Error: you are not in the correct directory. These must be run from the setup directory\n";
	exit(1);
}

my $conf=readConf();

print "\n";
print "\n";
print "\n";
print "Your dotMobile.us root path is ".$conf->{'DOTMOBILEROOT'}.".\n";
print "I'm going to download the config files to ".$conf->{'DOTMOBILEROOT'}."/configuration.\n\n\n";
open(LIST,"<".getcwd()."/.configtodownload");
my $line;
my $uri;
my $configurationdir=$conf->{'DOTMOBILEROOT'}."/configuration";
if (-d $configurationdir."/configurations") {
	print "You already have a configurations directory in place. Do you really want to run this ?\n";
	print "If yes, move $configurationdir somewhere else, and run this script again\n\n ";
	exit();
}
while ($line=<LIST>){
	
	chomp $line;
	$uri="http://configuration.apple.com/$line";
	print $uri."\n";
	`wget -P $configurationdir -nH -x $uri`
}


