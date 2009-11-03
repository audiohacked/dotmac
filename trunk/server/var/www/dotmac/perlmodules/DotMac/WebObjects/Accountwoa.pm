#------------------------------------
package DotMac::WebObjects::Accountwoa;

use strict;
use warnings;

use CGI::Carp; # for neat logging to the error log
use Apache2::Access ();
use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();#Perl API for Apache subrequests
use Apache2::Const -compile => qw(OK);
use DotMac::CommonCode;

use Data::Dumper; # just for testing

use XML::LibXML;

use HTTPD::UserAdmin(); # move this to common with auth subs

$DotMac::WebObjects::Accountwoa::VERSION = '0.1';


sub handler {
	my $r = shift;
	my $answer = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
        "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
	<title>Accountinfo</title>
</head>
<body>
Hi, this is the Accountinfo page<BR>Someone should set up something here to change passwords, set up ones own domain etc.
</body>
</html>';


	$r->send_http_header('text/html');
	$r->print( $answer );
	
	return Apache2::Const::OK;
}


1;
