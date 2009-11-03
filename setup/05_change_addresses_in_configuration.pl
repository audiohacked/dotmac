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
my $configurationdir=$conf->{'DOTMOBILEROOT'}."/configuration/configurations";
my $localwwwmacname=$conf->{'LOCALWWWMACNAME'};
my $localidiskname=$conf->{'LOCALIDISKNAME'};
my $localpublishname=$conf->{'LOCALPUBLISHNAME'};
my $localgalleryname=$conf->{'LOCALGALLERYNAME'};
print "Replacing www.mac.com with local name\n";
`find $configurationdir -name '*.plist' -exec perl -p -i -e \"s/www.mac.com/$localwwwmacname/g\" {} \\;`;
print "Replacing gallery.mac.com with local name\n";
`find $configurationdir -name '*.plist' -exec perl -p -i -e \"s/gallery.mac.com/$localgalleryname/g\" {} \\;`;
print "Replacing gallery.me.com with local name\n";
`find $configurationdir -name '*.plist' -exec perl -p -i -e \"s/gallery.me.com/$localgalleryname/g\" {} \\;`;
print "Replacing idisk.mac.com with local name\n";
`find $configurationdir -name '*.plist' -exec perl -p -i -e \"s/idisk.mac.com/$localidiskname/g\" {} \\;`;
print "Replacing idisk.me.com with local name\n";
`find $configurationdir -name '*.plist' -exec perl -p -i -e \"s/idisk.me.com/$localidiskname/g\" {} \\;`;
print "Replacing fileservices.me.com with local name\n";
`find $configurationdir -name '*.plist' -exec perl -p -i -e \"s/fileservices.me.com/$localidiskname/g\" {} \\;`;
print "Replacing publish.mac.com with local name\n";
`find $configurationdir -name '*.plist' -exec perl -p -i -e \"s/publish.mac.com/$localpublishname/g\" {} \\;`;
print "Replacing publish.me.com with local name\n";
`find $configurationdir -name '*.plist' -exec perl -p -i -e \"s/publish.me.com/$localpublishname/g\" {} \\;`;
