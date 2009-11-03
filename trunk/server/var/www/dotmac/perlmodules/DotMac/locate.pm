#file:DotMac/locate.pm
#----------------------

## Copyright (C) 2007 walinsky
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.

package DotMac::locate;

use strict;
use warnings;
use CGI;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => qw(OK HTTP_PAYMENT_REQUIRED);

$DotMac::locate::VERSION = '0.1';

#use XML::DOM;
use CGI::Carp; # for neat logging to the error log

sub handler {
	my $r = shift;
	my $content = "Account Error: Account IDisk Inactive";
	carp "locate got hit"; # the post data
	$r->args =~ /^([A-Za-z0-9]*)&type=([A-Za-z0-9]*)/;
	my $username = $1;
	my $certpath=$r->dir_config('dotMacCertsPath');
	my $filetoopen="$certpath/$2/$username.crt";
	$r->log->info("Trying to open $filetoopen");
	my $ret="\r\n\r\n$1\r\n===========================\r\n";
	if (open(FILE,"<$filetoopen")) {
	carp "in loop";
	my $line;
		while ($line=<FILE>){
			$ret=$ret.$line;
		}
	$ret=$ret."===========================\r\n";
	} 
	
	$r->content_type('text/plain');
#	$r->content_length(length($content));
	$r->send_http_header;
	$r->print($ret);
	
#	$r->custom_response(Apache2::Const::HTTP_PAYMENT_REQUIRED,
    #          $content);
	
	# none existent users:
#	print ('Account Error: Nonexistent');
	# return Apache2::Const::HTTP_PAYMENT_REQUIRED; # does this give me the spinning pizza of death ?

	return Apache2::Const::OK;
}



1;
