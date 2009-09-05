#file:DotMac/DMXWebdavMethods.pm
#--------------------------------
package DotMac::DMXWebdavMethods;

## Copyright (C) 2007 Walinsky, Robert See
## This file is part of dotMac. 

## dotMac is free software: you can redistribute it and/or modify
## it under the terms of the Affero GNU General Public License as published by
## the Free Software Foundation, either version 3 of the License, or
## (at your option) any later version.

## dotMac is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## Affero GNU General Public License for more details.

## You should have received a copy of the Affero GNU General Public License
## along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

use strict;
use warnings;

use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::SubRequest ();
use Data::Dumper;
use Apache2::Const -compile => qw(OK HTTP_CREATED HTTP_NO_CONTENT HTTP_BAD_REQUEST DONE :log);
use CGI::Carp;
use DotMac::CommonCode;
use XML::LibXML;
use XML::LibXML::XPathContext;
use Compress::Zlib;

sub handler
	{
	carp "DMMKPATH_handler active!";
	my $r = shift;
	my $rmethod = $r->method;
	my $user = $r->user;
	my $XWebdavMethod = $r->header_in('X-Webdav-Method');
	if ($XWebdavMethod eq 'DMMKPATH')
		{
		carp "DMMKPATH_handler DMMKPATH!";
		my $dotMaciDiskPath = $r->dir_config('dotMaciDiskPath');
		DotMac::CommonCode::recursiveMKdir($dotMaciDiskPath, $r->uri);
		$r->content_type('text/plain');
		$r->print("");
		
		return Apache2::Const::OK;
		}
	}
	
sub dmmkpath {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: dmmkpath");
	my $content;
	my $buf;
	my $content_length = $r->header_in('Content-Length');
	if ($content_length > 0) {
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
		$logging =~ m/Sections/&&$rlog->info("Content from POST: $content");
	}
	$r->print(DotMac::CommonCode::dmmkpath_response(DotMac::CommonCode::recursiveMKCOL( $r)));
	$r->content_type('text/xml');
	$r->status(207);
	return Apache2::Const::OK;
}

sub dmpatchpaths {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: dmpatchpaths");
	my $content;
	my $buf;
	my $content_length = $r->header_in('Content-Length');
	if ($content_length > 0) {
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
		$logging =~ m/Sections/&&$rlog->info("Content from POST: $content");
	}
	$r->print(DotMac::CommonCode::dmpatchpaths_response($r,DotMac::CommonCode::dmpatchpaths_request( $r, $content)));
	$r->content_type('text/xml');
	$r->status(207);
	return Apache2::Const::OK;
}			

sub options {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: options");
	$r->headers_out->add('Allow' => "GET, HEAD, OPTIONS, PUT, POST, COPY, PROPFIND, DELETE, LOCK, MKCOL, MOVE, PROPPATCH, UNLOCK, ACL");
	$r->headers_out->add('DAV' => "1,2, access-control");
	$r->headers_out->add('MS-Author-Via' => "DAV");
	$r->print("");
	$r->content_type('text/xml');
	$r->status(200);
	return Apache2::Const::OK;
}

sub ssmove {
### We get to use assbackwards here... $r->status_line should have allowed me to return Apple's 
### non-standard 257 Header, but it doesn't If I set it with $r->status, it turns into a 500
### If I set it with $r->status_line, it does nothing. I'm guessing its a bug as of
### libapache2-mod-perl2 2.0.4-5ubu

### At some point, I'm sure the Overwrite header is going to burn me, but I'll worry about when I have
### proof that I need to

	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: ssmove");
	my $xml=DotMac::CommonCode::subrequest($r, 'MOVE', $r->uri,"",$r->headers_in);
	my $destination = $r->headers_in->{'Destination'};
	$destination =~ /^http[s]?:\/\/[^\/]*(\/.*)/;
	my $newdestination=$1;
	$logging =~ /Sections/&&$rlog->info("Extracted new destination $newdestination");
	$r->status_line("HTTP/1.1 257 Response Status Set");

	if ($xml->[0]=='201') {
			$r->assbackwards(1);
	my $returnxml = <<HERE;
HTTP/1.1 257 Response Status Set

<INS:response-status-set xmlns:INS="http://idisk.mac.com/_namespace/set/"> 
		<multistatus xmlns="DAV:"> 
			<response xmlns="DAV:"> 
				<href>$newdestination</href> 
				<status>HTTP/1.1 204 No Content</status> 
			</response> 
		</multistatus> 
	</INS:response-status-set>
HERE
	$r->print($returnxml);
	} else {
		$r->status(400);
	}

	return Apache2::Const::OK;
}

sub dmmkpaths {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: dmmkpaths");

	#DotMac::CommonCode::dmMKpaths($dotMaciDiskPath, $r->uri);
	# send multistatus header:
	# HTTP/1.1 207 Multi-Status
	my $buf;
	my $content;
	my $content_length = $r->header_in('Content-Length');
	if ($content_length > 0) {
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
		#carp $content;
	}
	$r->print(DotMac::CommonCode::dmmkpath_response(DotMac::CommonCode::dmmkpath_request( $r, $content)));
	$r->content_type('text/xml;charset=utf-8');
	$r->content_type('text/xml');
	$r->status(207);
	return Apache2::Const::OK;
}

sub dmoverlay {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: dmoverlay");
	my $buf;
	my $content;
	my $content_length = $r->headers_in->{'Content-Length'};
	if ($content_length > 0)
	{
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
		$logging =~ m/Sections/&&$rlog->info("Content from POST: $content");
	}
	#$logging =~ m/Sections/&&$rlog->info($r->as_string());
	my $subreq;
	my $statusarr=[""];
	my $source = $r->filename;
	my $targeturi = $r->headers_in->{'X-Target-Href'};
	$subreq = $r->lookup_method_uri("GET", $targeturi);
	$subreq->add_output_filter(\&DotMac::NullOutputFilter::handler);
	$subreq->run();
	my $target = $subreq->filename;
	DotMac::CommonCode::dmoverlay($r, $statusarr, $source, $target, $r->uri, $targeturi);
	$r->print(DotMac::CommonCode::dmoverlay_response($r,$statusarr));
	$r->method(207);
	#is this the same as DMPUTFROM ?
	# after this we also get a DMPATCHPATHS
	#$r->uri="/walinsky/Web/.Temporary%20Web%20Resources/2A169922-8D0A-4755-8D9F-524B7A428C91"
	#X-Target-Href: /walinsky/Web/Sites
	#$r->content_type('text/plain');
	#$r->print("aaa");
	return Apache2::Const::OK;
}

sub setprocess {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: setprocess");
	my $buf;
	my $content;
	my $content_length = $r->headers_in->{'Content-Length'};
	if ($content_length > 0)
		{
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
			}
		my $xmldata = Compress::Zlib::memGunzip( \$content );
		$logging =~ m/Sections/&&$rlog->info("Content from POST: $xmldata");
		}		
	#my $putFile = '/tmp/setprocess.gz';
	#open(PUTFILE,">$putFile") || `cat /dev/null > $putFile;chmod 666 $putFile`;
	#binmode PUTFILE;
	#print PUTFILE $content;
	#close(PUTFILE);	
	#$logging =~ m/Sections/&&$rlog->info($r->as_string());
	
	# for now - give them an ordinary 'success'
	$r->content_type('text/xml');
	$r->print("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>
<methodResponse><params><param><value>success</value></param></params></methodResponse>");
	$r->status(207);
	return Apache2::Const::OK;
}
sub truthget {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: truthget");
	$r->content_type('text/xml');
	my @args = split '&', $r->args();
	my %params;

	#<updated>2007-12-29T20:05:20-08:00</updated>
	my @datearray=gmtime(time());
	my $lastupdate=sprintf('%s-%#.2d-%#.2dT%#.2d:%#.2d:%#.2d-00:00',$datearray[5]+1900,$datearray[4]+1,$datearray[3],$datearray[2],$datearray[1],$datearray[0]);
	foreach my $a (@args) {
		(my $att,my $val) = split '=', $a;
		$params{$att} = $val ;
	}
	my $depth = $params{'depth'}?$params{'depth'}:0;
	my $xml = DotMac::CommonCode::subrequest($r,"PROPFIND",$r->uri,"",{'Depth'=>$depth});
	$logging =~ /Sections/&&$rlog->info(Dumper($xml));
        if ($xml->[0] == 404) {
                $r->status(Apache2::Const::NOT_FOUND);
                return Apache2::Const::OK;
        }
	#$r->print($xml->[1]);
	#$r->content_type("application/atom+xml");
	#$r->print(DotMac::CommonCode::truthget_generate($r,$xml->[1],$r->user));
	
	$r->content_type("application/atom+xml");
	$r->header_out("Expires" => "Mon, 26 Jul 1997 05:00:00 GMT");
	$r->header_out("Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0");
	$r->headers_out->add('Cache-Control' => "post-check=0, pre-check=0");
	$r->header_out("Connection" => "keep-alive");
	$r->header_out("Pragma" => "no-cache");
	$r->header_out("content-encoding" => "gzip");

	my $gzAnswer = Compress::Zlib::memGzip(DotMac::CommonCode::truthget_generate($r,$xml->[1],$r->user)); 
	$r->header_out('Content-Length', length( $gzAnswer ));
	#Date: Wed, 11 Feb 2009 17:03:56 GMT
	$r->print( $gzAnswer );
	
	
	return Apache2::Const::OK;
}
sub acl {
	# now this is quite funny
	# apple seems to have some WEBDAV ACL implementation;
	# but doesn't call ACL - but POSTs acl commands
	
	# as we don't have acl at all - lets just proppatch it
	# as properties on the DAV resources
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	my $targeturi = $r->uri;
	$logging =~ /Sections/&&$rlog->info("Content Handler: acl");
	my $dotMaciDiskPath = $r->dir_config('dotMaciDiskPath');

	my $buf;
	my $content;
	my $content_length = $r->headers_in->{'Content-Length'};
	if ($content_length > 0)
	{
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
		$logging =~ m/Sections/&&$rlog->info("Acl: content from POST: $content");
	}
	
	my $DAVns = 'NSDAV';
	my $DAVnsURI = 'DAV:';
#	my $iphotons = 'iphoto';
#	my $iphotonsURI = 'urn:iphoto:property';
#	my $idiskns = 'idisk';
#	my $idisknsURI = 'http://idisk.mac.com/_namespace/set/';
#	my $dotmacns = 'dotmac';
#	my $dotmacnsURI = 'urn:dotmac:property';
	my $dotmacacl = 'dotmacacl';
	my $dotmacaclURI = 'http://mobile.us/_namespace/set/';
	
	
	
	my $parser = XML::LibXML->new();
	#$parser->keep_blanks(0);	# this would strip whitespacess of the xml
								# but textnodes would still have spaces and newline chars
	my $doc    = $parser->parse_string($content);
	my $xc     = XML::LibXML::XPathContext->new( $doc->documentElement() );
	$xc->registerNs( $DAVns => $DAVnsURI );
#	$xc->registerNs( $iphotons => $iphotonsURI );
#	$xc->registerNs( $idiskns => $idisknsURI );
#	$xc->registerNs( $dotmacns => $dotmacnsURI );
	$xc->registerNs( $dotmacacl => $dotmacaclURI );
	
	my $acl = $doc->documentElement;
	#replace the D: prefix by ours (found with the DAV: namespace URI)
	$acl->setNamespaceDeclPrefix($acl->lookupNamespacePrefix($DAVnsURI), $dotmacacl);
	#now replace the DAV namespace URI by ours
	$acl->setNamespaceDeclURI($dotmacacl, $dotmacaclURI);
#	print $doc->toString();
	
	#setup a new proppatch xml doc
	my $proppatch = XML::LibXML::Document->createDocument('1.0', 'UTF-8');
	my $propertyupdate = $proppatch->createElement('propertyupdate');
	$propertyupdate->setNamespace( $DAVnsURI , $DAVns );
	$proppatch->setDocumentElement($propertyupdate);
	#$propertyupdate->registerNs( $DAVns => $DAVnsURI );
	my $set = $propertyupdate->appendChild($proppatch->createElement("$DAVns:set"));
	my $prop = $set->appendChild($proppatch->createElement("$DAVns:prop"));
	my $newn = $acl->cloneNode(1);
	$prop->appendChild($newn);
#	print $proppatch->toString();
	#now (re) encode the URI
	$targeturi =~ s/([^\w\d\-_\.!~\*\'\(\)\/])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
	$logging =~ m/Sections/&&$r->log->info("#### ACL ### PROPPATCH : ". $proppatch->toString() );
	# my $returndata=DotMac::DMUserAgent::handler($r,$method, $href, $xml, $headers);
	$r->headers_in->{'Host'} = 'idisk.mac.com';
	my $proppatchResponse = DotMac::CommonCode::subrequest($r, 'PROPPATCH', $targeturi,  $proppatch->toString());
	#$propfindAlbumResponse->[1]
	$logging =~ m/Sections/&&$r->log->info("#### ACL ### PROPPATCH returned : ". $proppatchResponse->[0] .' - '. $proppatchResponse->[1] );	
	
	
	# the response apple sends:
	$r->content_type('text/plain');
	$r->print("");
	return Apache2::Const::OK;
}

1;
