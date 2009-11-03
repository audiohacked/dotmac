#file:DotMac/marketeer.pm
#----------------------

## Copyright (C) 2009 walinsky
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.

##DotMac::marketeer provides services for m3.mac.com
package DotMac::marketeer;

use strict;
use warnings;

use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK);

$DotMac::marketeer::VERSION = '0.1';


sub handler {
	my $r = shift;
	my $answer = '<?xml version="1.0" encoding="ISO-8859-1"?><methodResponse><params><param><value><boolean>1</boolean></value></param></params></methodResponse>';

	# I don't have anything more to say - but then again I'm no marketeer

	my $contentLength = length($answer);
	$r->content_type("text/xml");
	$r->header_out('content-length', $contentLength);
	$r->print ($answer);
	return Apache2::Const::OK;
	}



1;