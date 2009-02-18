#file:DotMac/domainHosting.pm
#------------------------------------
package DotMac::domainHosting;

use strict;
use warnings;

use Apache2::Access ();
use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK);
use DotMac::CommonCode;
use DotMac::DotMacDB;
use DateTime::Format::HTTP;
use Data::Dumper; # just for testing


$DotMac::domainHosting::VERSION = '0.1';

sub handler {
	my $r = shift;
	my $answer;
	my $content;
	my $buf;
	my $logging = $r->dir_config('LoggingTypes');
	while ($r->read($buf, $r->header_in('Content-Length'))) {
		$content .= $buf;
	}
	$logging=~m/Gallery/&&$r->log->info("domainHosting: $content");

	if ($r->uri eq "/_domainHosting") {
		# Setup parser and find what method is being called
		my $parser = XML::LibXML->new();
		my $dom = $parser->parse_string($content);
		my $rootnode = $dom->documentElement;
		my $method = $rootnode->findvalue('/methodCall/methodName');
		
		#
		# XMLRPC Methods
		#

		# lookupDomainsForOwner
		# Parameters: username, password, array(?): album(s?)
		# Returns: PINs associated with album url(s?)
		#
		if( $method eq 'lookupDomainsForOwner' ){
			my $username = $rootnode->findvalue('/methodCall/params/param/value/struct/member/value/string');
			my $name = $rootnode->findvalue('/methodCall/params/param/value/struct/member/name');
			#raw answer if no sites are published
			$answer = '<?xml version="1.0" encoding="ISO-8859-1"?><methodResponse><params><param><value><struct><member><name>kDMResult</name><value><array><data></data></array></value></member><member><name>kDMErrorCode</name><value>0</value></member></struct></value></param></params></methodResponse>';
			
		}
		### elsifs - other methods
		
		else { # unknown method
			# answer not verified yet
			$logging=~m/Gallery/&&$r->log->info("domainHosting: unknown method - $method");
			$answer = '<?xml version="1.0"?><methodResponse><fault><value><struct><member><name>faultString</name><value>org.apache.xmlrpc.ParseFailed</value></member><member><name>faultCode</name><value><int>0</int></value></member></struct></value></fault></methodResponse>';
		}
	} else {
		$logging=~m/Gallery/&&$r->log->info("Hi; I'm domainHosting.pm, and I got called with a uri I don't know: ". $r->uri);
	}
	# headers not verified yet
	$r->content_type("text/xml; charset=utf-8");
	$r->header_out("Expires" => "Mon, 26 Jul 1997 05:00:00 GMT");
	$r->header_out("Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0");
	$r->headers_out->add('Cache-Control' => "post-check=0, pre-check=0");
	$r->header_out("Connection" => "keep-alive");
	$r->header_out("Pragma" => "no-cache");
	$r->header_out("content-encoding" => "gzip");
	my $datetimeclass = 'DateTime::Format::HTTP';
	$r->header_out("Date" => $datetimeclass->format_datetime());
	# gzip compression not verified yet
	$r->content_encoding("gzip");
	$r->print(Compress::Zlib::memGzip($answer));
	return Apache2::Const::OK;
	}

###subs


1;
