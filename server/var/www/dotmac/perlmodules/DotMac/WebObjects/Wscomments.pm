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

	my $parser = XML::LibXML->new();
	my $dom = $parser->parse_string($content);
	my $rootnode = $dom->documentElement;

	my $method = $rootnode->findvalue('/methodCall/methodName');

	if( $method eq 'comment.authenticate' ){
		$answer = &successResponse();
	} elsif( $method eq 'comment.commentProperties' ){
		my $path = $rootnode->findvalue('/methodCall/params/param/value/string');
		$answer = &notEnabledResponse($path);
	} elsif( $method eq 'comment.terminateSession' ){
		$answer = &successResponse();
	} else {
		$answer = &successResponse();
	}

	$r->headers_out->{'Content-Type'}="text/xml; charset=utf-8";
	$r->print( $answer->toString() );
	
	return Apache2::Const::OK;
}

sub successResponse() {
	my $answer = XML::LibXML::Document->new();

	my $rootElem = $answer->createElement('methodResponse');
	$answer->setDocumentElement($rootElem);

	my $params = $rootElem->appendChild( $answer->createElement('params') );
	my $param = $params->appendChild( $answer->createElement('param') );
	my $value = $param->appendChild( $answer->createElement('value') );
	my $boolean = $value->appendChild( $answer->createElement('boolean') );
	$boolean->appendChild( XML::LibXML::Text->new('1') );

	return $answer;
}

sub notEnabledResponse( $ ) {
	my $path = shift;

	my $answer = XML::LibXML::Document->new();

	my $rootElem = $answer->createElement('methodResponse');
	$answer->setDocumentElement($rootElem);

	my $fault = $rootElem->appendChild( $answer->createElement('fault') );
	my $value = $fault->appendChild( $answer->createElement('value') );
	my $struct = $value->appendChild( $answer->createElement('struct') );

	my $stringMember = $struct->appendChild( $answer->createElement('member') );
	my $stringName = $stringMember->appendChild( $answer->createElement('name') );
	$stringName->appendChild( XML::LibXML::Text->new('faultString') );
	my $stringValue = $stringMember->appendChild( $answer->createElement('value') );
	$stringValue->appendChild( XML::LibXML::Text->new("org.apache.xmlrpc.XmlRpcException: Resource at path [$path] is not enabled for commenting.") );

	my $codeMember = $struct->appendChild( $answer->createElement('member') );
	my $codeName = $codeMember->appendChild( $answer->createElement('name') );
	$codeName->appendChild( XML::LibXML::Text->new('faultCode') );
	my $codeValue = $codeMember->appendChild( $answer->createElement('value') );
	my $codeValueInt = $codeValue->appendChild( $answer->createElement('int') );
	$codeValueInt->appendChild( XML::LibXML::Text->new('1408') );

	return $answer;
}

1;
