#!/usr/bin/perl


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


my $conf=readConf();
my $root=$conf->{'DOTMOBILEROOT'};
my $server=$conf->{'LOCALIDISKNAME'};

my $certsdir=$root."/certs";


print "You will need to run the following commands in terminal on each client before you login to dotMac:\n";

print "curl -O http://$server/dotMacCA.pem\n";
print "sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain\n"
