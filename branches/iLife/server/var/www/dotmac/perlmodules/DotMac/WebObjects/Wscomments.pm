#------------------------------------
package DotMac::WebObjects::Wscomments;

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

$DotMac::WebObjects::Infowoa::wa::VERSION = '0.1';


sub handler {
	my $r = shift;
	my $answer;
	my $content;
	#carp $r->as_string();
	#carp $r->location();
	#carp $r->document_root();
	# my $user = $r->user;
	#carp $r->method;
	#carp $r->uri;)
			my $buf;
	while ($r->read($buf, $r->header_in('Content-Length'))) {
			$content .= $buf;
			}
	$r->log->info("Wscomments:".$r->as_string()."Content: ".$content);
	$r->headers_out->{'Content-Type'}="text/xml; charset=utf-8";
	$r->print("<?xml version=\"1.0\"?><methodResponse><params><param><value><boolean>1</boolean></value></param></params></methodResponse>");
	
	return Apache2::Const::OK;
	}

1;