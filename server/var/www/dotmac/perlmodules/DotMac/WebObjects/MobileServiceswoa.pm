#file:DotMac/WebObjects/MobileServiceswoa.pm
#------------------------------------
package DotMac::WebObjects::MobileServiceswoa;

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

use XML::DOM;

use HTTPD::UserAdmin(); # move this to common with auth subs

$DotMac::WebObjects::MobileServiceswoa::VERSION = '0.1';

sub handler {
	my $r = shift;
	my $answer;
	my $content;
	my $buf;
	my $logging = $r->dir_config('LoggingTypes');
	while ($r->read($buf, $r->header_in('Content-Length'))) {
		$content .= $buf;
	}
	$logging=~m/Gallery/&&$r->log->info("MobileServiceswoa: $content");

	if ($r->uri eq "/WebObjects/MobileServices.woa/xmlrpc") {
		$logging=~m/Gallery/&&$r->log->info("MobileServiceswoa: xmlrpc");
		# Setup parser and find what method is being called
		my $parser = XML::LibXML->new();
		my $dom = $parser->parse_string($content);
		my $rootnode = $dom->documentElement;
		my $method = $rootnode->findvalue('/methodCall/methodName');
		
		# if the POSTed xml sucks:
		# <?xml version="1.0"?><methodResponse><fault><value><struct><member><name>faultString</name><value>org.apache.xmlrpc.ParseFailed</value></member><member><name>faultCode</name><value><int>0</int></value></member></struct></value></fault></methodResponse>
		# if wrong username/pw combo:
		# <?xml version="1.0"?><methodResponse><fault><value><struct><member><name>faultString</name><value>org.apache.xmlrpc.XmlRpcException: Username or password invalid</value></member><member><name>faultCode</name><value><int>100</int></value></member></struct></value></fault></methodResponse>
		
		#
		# XMLRPC Methods
		#

		# moblogging.activatePIN
		# moblogging.createNewPIN
		# moblogging.lookupExistingPINs

		# moblogging.lookupExistingPINs
		# Parameters: username, password, array(?): album(s?)
		# Returns: PINs associated with album url(s?)
		#
		# Authenticates user and sets up a session which is then tracked by cookie
		if( $method eq 'moblogging.lookupExistingPINs' ){
			my $username = $rootnode->findvalue('/methodCall/params/param[1]/value/string');
			my $password = $rootnode->findvalue('/methodCall/params/param[2]/value/string');
	
			my $dmdb = DotMac::DotMacDB->new();
			if( $dmdb->authen_user($username, $password) ){
				### user is ok - handle the response
				$logging=~m/Gallery/&&$r->log->info("MobileServiceswoa: $username successfully logged in - looking up album");
			# I have never seen an array (don't know how to loop) so here goes straight on...
			my $uri = $rootnode->findvalue('/methodCall/params/param[3]/value/array/data/value/string');
			
			# <?xml version="1.0"?><methodResponse><params><param><value><struct><member><name>/eugenievk/Web/Sites/_gallery/100032</name><value><struct></struct></value></member></struct></value></param></params></methodResponse>
			$answer = XML::LibXML::Document->new();

			my $rootElem = $answer->createElement('methodResponse');
			$answer->setDocumentElement($rootElem);
		
			my $params = $rootElem->appendChild( $answer->createElement('params') );
			my $param = $params->appendChild( $answer->createElement('param') );
			my $value = $param->appendChild( $answer->createElement('value') );
			my $struct = $value->appendChild( $answer->createElement('struct') );
			my $member = $struct->appendChild( $answer->createElement('member') );
			my $name = $member->appendChild( $answer->createElement('name') );
			$name->appendChild( XML::LibXML::Text->new($uri) );
			my $membervalue = $member->appendChild( $answer->createElement('value') );
			my $memberstruct = $membervalue->appendChild( $answer->createElement('struct') );
			# we prolly do some magic here; validating the $uri against our magic database; and insert our value here
			my $pin;
			$memberstruct->appendChild( XML::LibXML::Text->new($pin) );
			$answer = $answer->toString();
			} else {
				### user is NOT ok - handle the response
				$logging=~m/Gallery/&&$r->log->info("MobileServiceswoa: $username Invalid credentials supplied; sending faultstring");
				$answer = '<?xml version="1.0"?><methodResponse><fault><value><struct><member><name>faultString</name><value>org.apache.xmlrpc.XmlRpcException: Username or password invalid</value></member><member><name>faultCode</name><value><int>100</int></value></member></struct></value></fault></methodResponse>';
			}
		}
		### elsifs - other methods
		
		else { # unknown method
			$logging=~m/Gallery/&&$r->log->info("MobileServiceswoa: unknown method - $method");
			$answer = '<?xml version="1.0"?><methodResponse><fault><value><struct><member><name>faultString</name><value>org.apache.xmlrpc.ParseFailed</value></member><member><name>faultCode</name><value><int>0</int></value></member></struct></value></fault></methodResponse>';
		}
	} else {
		$logging=~m/Gallery/&&$r->log->info("Hi; I'm MobileServiceswoa.pm, and I got called with a uri I don't know: ". $r->uri);
	}
	
	$r->content_type("text/xml; charset=utf-8");
	$r->header_out("Expires" => "Mon, 26 Jul 1997 05:00:00 GMT");
	$r->header_out("Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0");
	$r->headers_out->add('Cache-Control' => "post-check=0, pre-check=0");
	$r->header_out("Connection" => "keep-alive");
	$r->header_out("Pragma" => "no-cache");
	$r->header_out("content-encoding" => "gzip");
	my $datetimeclass = 'DateTime::Format::HTTP';
	$r->header_out("Date" => $datetimeclass->format_datetime());

	#my $gzAnswer = Compress::Zlib::memGzip($answer); 
	#$r->header_out('Content-Length', length( $gzAnswer ));
	#$r->print( $gzAnswer );

	$r->content_encoding("gzip");
	$r->print(Compress::Zlib::memGzip($answer));
	return Apache2::Const::OK;
	}

###subs


1;
