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
my $certsdir=$root."/certs";

my $openssl='openssl';
my $CATOP="$certsdir/dotmacCA";
my $SSLEAY_CONFIG="$certsdir/dotmacssl.cnf";
my $CA="$openssl ca -config $SSLEAY_CONFIG";
my $REQ="$openssl req -config $SSLEAY_CONFIG";

`$REQ -new -nodes -keyout $root/private/server.key -out $root/private/server.csr -subj "/C=DM/ST=SomeState/O=dotMobile.us/CN=dot.mac.com"`;

`$CA -days 365 -in $root/private/server.csr -extfile $root/private/extensions -out $root/private/server.crt`;

