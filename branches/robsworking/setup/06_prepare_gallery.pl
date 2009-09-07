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
	}  else {
		print "No config file found, exiting";
		exit(1);
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


my $conf=readConf();
my $cachedir=$conf->{'DOTMOBILEROOT'}."/cache/";
my $localwwwmacname=$conf->{'LOCALWWWMACNAME'};
my $localidiskname=$conf->{'LOCALIDISKNAME'};
my $localpublishname=$conf->{'LOCALPUBLISHNAME'};
my $localgalleryname=$conf->{'LOCALGALLERYNAME'};
my $filetouse="gallery.html";
my $fullpath=$cachedir."/".$filetouse;
my	$uri="http://gallery.mac.com/emily_parker";
	print "Downloading index page from $uri \n";
	`curl $uri > $fullpath`;

print "Splitting $localgalleryname into parts\n";
my $hostname;
my $domain;
if ($localgalleryname =~ /^([^.]*)\.(.*)/) {
	$hostname=$1;
	$domain=$2;	
}

print "Rewriting Domain\n";
`perl -p -i -e "s/^var currentDomain.*\;/var currentDomain = \'$domain\'\;/" $fullpath`;

print "Rewriting Hostname\n";
`perl -p -i -e "s/^var hostName.*\;/var hostName = \'$localgalleryname\'\;/" $fullpath`;

$uri="http://gallery.mac.com/g/javascripts/gallery.js?1249509518";
$filetouse="gallery.js";
$fullpath=$cachedir."/g/javascripts/".$filetouse;

print $fullpath."\n";
print "Downloading gallery page from $uri \n";
	`curl $uri > $fullpath`;

print "Rewriting Domain\n";
`perl -p -i -e "s/var DOMAIN=.*?\;/var DOMAIN = \'$domain\'\;/" $fullpath`;

print "Rewriting Hostname\n";
`perl -p -i -e "s/var HOST=.*?\;/var HOST= \'$localgalleryname\'\;/" $fullpath`;

print "Removing Annoying .com reference\n";
`perl -p -i -e 's|\\\\.com||g' $fullpath`;

print "Rewrite gallery.me.com to $localgalleryname\n";
`perl -p -i -e 's|gallery.mac.com|$localgalleryname|g' $fullpath`;
