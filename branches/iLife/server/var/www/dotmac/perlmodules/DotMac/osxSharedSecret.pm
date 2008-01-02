#file:DotMac/osxSharedSecret.pm
#----------------------

## Copyright (C) 2007 walinsky
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.

package DotMac::osxSharedSecret;

use strict;
use warnings;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => qw(OK);

$DotMac::osxSharedSecret::VERSION = '0.1';

#use XML::DOM;
use CGI::Carp; # for neat logging to the error log
# req: <?xml version="1.0" encoding="UTF-8"?><methodCall><methodName>getSharedSecret</methodName></methodCall>
# answer: <?xml version="1.0" encoding="ISO-8859-1"?><methodResponse><params><param><value><struct><member><name>data</name><value>oGXLhcAcWPCCPHRFUd5pVzwQaY8=</value></member><member><name>name</name><value>sjorsdeberekorst.members.mac.com.</value></member></struct></value></param></params></methodResponse>
sub handler {
	my $r = shift;
	
	my $TimeStamp = time();

	my $my_data = "";
	# we should check if it's a post message
	if ($ENV{'REQUEST_METHOD'} eq 'POST') {
		read(STDIN, $my_data, $ENV{'CONTENT_LENGTH'});
		}

##	debug level logging
	carp $TimeStamp;
	carp $r->as_string(); # the http request
	carp $my_data; # the post data
	$r->content_type('text/xml');
#	$r->server('AppleDotMacServer');
	my $response_data = '<?xml version="1.0" encoding="ISO-8859-1"?><methodResponse><params><param><value><struct><member><name>data</name><value>/mRnb5L+QPwFS6C1jhMvefo/ki4=</value></member><member><name>name</name><value>walinsky.members.mac.com.</value></member></struct></value></param></params></methodResponse>';
	$r->set_content_length(length($response_data));
	$r->err_headers_out->set('Server' => 'AppleDotMacServer');
	$r->err_headers_out->unset('Connection');
	print $response_data;
	return Apache2::Const::OK;
}



1;