#file:DotMac/CommonCode.pm
#----------------------

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

package DotMac::CommonCode;
$DotMac::CommonCode::VERSION = '0.1';
use strict;
use warnings;

use CGI::Carp;
use DB_File;
use Encode;
use File::Copy;
use File::Spec;
use File::Basename;
use XML::DOM;
use XML::LibXML;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Log;
use Apache2::SubRequest ();
use DotMac::NullOutputFilter;
# use DotMac::CaptureOutputFilter;
use DotMac::PostingInputFilter;
use Data::Dumper;
use Digest::MD5;
use DBI;

use DotMac::DMUserAgent;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Response;


sub returnDeltaRecords{
	my $dmdb = DotMac::DotMacDB->new();
	my ($r,$queryts) = @_;
	return $dmdb->return_delta_records($r->user,$queryts);
}

sub writeDeltaRecord{
	my ($r) = @_;
	my ($dbh);
	my $opcode="";
	my $source="";
	my $target="";
	my $user = $r->user();
	my $dbargs = {	AutoCommit => 1, 
					PrintError => 1};

	
	if ($r->method() eq "MOVE") { 
		$opcode="MOV";
		$source=$r->uri;
		$target=$r->headers_in->{'Destination'};
		$target =~ m|http[s]{0,1}://([a-zA-Z0-9\.]*)/(.*)|;
		$target = $2;		
	} elsif ($r->method() eq "PUT") {
		$opcode="PUT";
		$source=$r->uri;
	} elsif ($r->method() eq "DELETE") {
		$opcode="DEL";
		$source=$r->uri;
	} elsif ($r->method() eq "MKCOL") {
		$opcode="MKD";
		$source=$r->uri;
	} else {
		$r->log->info("writeDeltaRecord: unhandled opcode");
		return;
	}
	my $dmdb = DotMac::DotMacDB->new();
	$dmdb->write_delta_record($user, $opcode, $source, $target);
	return 1;
	
}

sub readUserDB
	{ my ($dbpath, %attributes) = @_;
	my  %database;
	my ($key, $value);
	tie %database, 'DB_File', $dbpath
		or warn "Can't initialize database: $dbpath; $!\n";# don't die; just warn
	
	while (($key, $value) = each %database ) {
		$value = Encode::decode("utf-8" , $value);
		$attributes{$key} = $value;
		}
	### Close the Berkeley DB
	untie %database;
	return %attributes
	}

sub writeUserDB
	{ my ($dbpath, %attributes) = @_;
	my  %database;
	my ($key, $value);
	tie %database, 'DB_File', $dbpath
		or warn "Can't initialize database: $dbpath; $!\n";# don't die; just warn
	
	while (($key, $value) = each %attributes ) {
		$value = Encode::encode("utf-8" , $value);# encode them utf first; then print
		$database{$key} = $value;
		}
	### Close the Berkeley DB
	untie %database;
	}

sub recursiveMKdir
	{ my ($rootpath, $addpath) = @_;
	# TODO: move to File::Path;
	# mkpath(['/foo/bar/baz', 'blurfl/quux'], 1, 0711);
	my $slash = '/';
	my $adddir;
	# taking off trailing slash
	if (rindex($addpath, $slash) == ((length $addpath)-1)){
		$addpath = substr $addpath, 0, ((length $addpath)-1);
		}
	# setup a loop checking for / and recursively test creating subdirs	
	until (length $addpath == 0) {
		# taking off leading slash
		if (index($addpath, $slash) == 0) {
			$addpath = substr $addpath, 1, length $addpath;
			}
		my $slashpos = index($addpath, $slash);
		if ($slashpos != -1) {
			$adddir = substr $addpath, 0, $slashpos;
			my $leftoverpath = substr $addpath, $slashpos + 1, length $addpath;
			}
		else
			{
			$adddir = $addpath;
			}
		if (!(-d $rootpath.$slash.$adddir))  {
			mkdir ($rootpath.$slash.$adddir, 0777) || die "sorry system is unable to create output directory (check permissions/directory owned by apache user) for".$rootpath.$slash.$addpath;
			}
		$addpath = substr $addpath, length $adddir, length $addpath;
		$rootpath = $rootpath.$slash.$adddir;
		}
	}
sub checkparent {
	my ($r, $directory) = @_;
	my @arr = File::Spec->splitdir($directory);
	pop(@arr);
	my $parentdir=File::Spec->catdir(@arr);
	return -d $parentdir;
	}

sub dmoverlay {
	my ($r,$statusarr, $source, $target, $sourceuri, $targeturi ) = @_;
	my @holding;
	my $logging = $r->dir_config('LoggingTypes');
	$r->log->info("Checking Source: $sourceuri Target: $targeturi"); #.File::Spec->catdir($target,"test123"));
	$r->log->info("First check if the source is a file or a directory");
	my ($dirhandle,$ret);
	
	if ((-d $source) && (-d $target)) {
		@holding=([$sourceuri, $targeturi,0,"WALK"]);
		push(@$statusarr,@holding);		
	}
	if (!(-e $source)) {
		$r->log->info("hit source doesn't exist");
		return 0;
	} elsif (-d $source) {
		$r->log->info("Directory: Source: $source ");
		if (!(-e $target) && checkparent($r,$target)) { 
			$r->log->info("Target does not exist, and the target's parent is a dir");
			$ret = subrequest($r,"MOVE",$sourceuri,"",{'Destination'=>formCurrentServer($r).$targeturi});
			@holding=([$sourceuri, $targeturi,$$ret[0],"MOVE"]);
			push(@$statusarr,@holding);
			$r->log->info("#### Call a MOVE subrequest");
		} elsif ((-e $target) && !(-d $target)) {
			$r->log->info("	#### Delete the target and MOVE the source to the destination");
			subrequest($r,"DELETE",$targeturi);
			$ret = subrequest($r,"MOVE",$sourceuri,"",{'Destination'=>formCurrentServer($r).$targeturi});
			@holding=([$sourceuri, $targeturi,$$ret[0],"OVERLAY"]);
			push(@$statusarr,@holding);

		} elsif ((-e $target) && (-d $target)) {
			opendir($dirhandle, $source);
			my $entry;
			while ($entry=readdir($dirhandle)) {
				$r->log->info("Entry: $entry");
				next if (($entry =~ m/^\.$/) || ($entry =~ m/^\.\.$/) || ($entry =~ m/^\.DAV$/));
		#		if (-e File::Spec->catdir($target,$entry)) {
					dmoverlay($r,$statusarr,File::Spec->catdir($source,$entry),File::Spec->catdir($target,$entry),$sourceuri."/".$entry,$targeturi."/".$entry);
		#		} else  {
		#			dmoverlay($r,$statusarr,File::Spec->catdir($source,$entry),$target,$sourceuri."/".$entry,$targeturi);
		#		}
			}
			closedir($dirhandle);
			#$r->print(Dumper(@arr));
### don't forget to fetch props from sourcedir - and proppatch them onto target dir
			##make sure we have a trailing slash
			if ( $sourceuri !~ m/\/$/ ) {
				$sourceuri = $sourceuri.'/';
			}
			copyDavProps ( $r,$sourceuri, $targeturi );
### patched target dir with source props ?!? should be done here
		}
	} elsif (!(-d $source)) {
		if (!(-e $target) && checkparent($r,$target)) {
			$r->log->info("	#### MOVE the file from source to the new target and rename");
			$ret = subrequest($r,"MOVE",$sourceuri,"",{'Destination'=>formCurrentServer($r).$targeturi});
			@holding=([$sourceuri, $targeturi,$$ret[0],"MOVE"]);
			push(@$statusarr,@holding);			
		} elsif ((-d $target) && (-e File::Spec->catdir($target,basename($source)))) {
			$r->log->info("	#### Delete the file and Move the file into the new directory");
			subrequest($r,"DELETE",$targeturi);
			$ret = subrequest($r,"MOVE",$sourceuri,"",{'Destination'=>formCurrentServer($r).$targeturi});
			@holding=([$sourceuri, $targeturi,$$ret[0],"OVERLAY"]);
			push(@$statusarr,@holding);
		} elsif ((-d $target) && !(-e File::Spec->catdir($target,basename($source)))) {
			$r->log->info("	#### Move the File into the directory");
			$ret = subrequest($r,"MOVE",$sourceuri,"",{'Destination'=>formCurrentServer($r).$targeturi});	
			@holding=([$sourceuri, $targeturi,$$ret[0],"MOVE"]);
			push(@$statusarr,@holding);
		} elsif ((-e $target) && !(-d $target)) {
			$r->log->info("#### Delete the target file and move the file there ");
			subrequest($r,"DELETE",$targeturi);
			$ret = subrequest($r,"MOVE",$sourceuri,"",{'Destination'=>formCurrentServer($r).$targeturi});		
			@holding=([$sourceuri, $targeturi,$$ret[0],"OVERLAY"]);
			push(@$statusarr,@holding);
		}
	
	}
	return Apache2::Const::OK;
}

sub copyDavProps {
	my ( $r,$sourceuri, $targeturi ) = @_;
	my $logging = $r->dir_config('LoggingTypes');
	my $propfindResponse = subrequest($r, 'PROPFIND', $sourceuri, '<D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>', {'Depth'=> '0'});
	$logging =~ m/Sections/&&$r->log->info("fetching props for existing dir $sourceuri ". $propfindResponse->[0]. " - " . $propfindResponse->[1]);
	
	my $DAVns = 'NSDAV';
	my $DAVnsURI = 'DAV:';
	my $iphotons = 'iphoto';
	my $iphotonsURI = 'urn:iphoto:property';
	my $idiskns = 'idisk';
	my $idisknsURI = 'http://idisk.mac.com/_namespace/set/';
	my $dotmacns = 'dotmac';
	my $dotmacnsURI = 'urn:dotmac:property';
	
	
	#setup a new proppatch xml doc
	my $proppatch = XML::LibXML::Document->createDocument('1.0', 'UTF-8');
	my $propertyupdate = $proppatch->createElement('propertyupdate');
	$propertyupdate->setNamespace( $DAVnsURI , $DAVns );
	$proppatch->setDocumentElement($propertyupdate);
	
	my $parser = XML::LibXML->new();
	my $data = $parser->parse_string($propfindResponse->[1]);
	my $xc = XML::LibXML::XPathContext->new($data);
	$xc->registerNs( $DAVns => $DAVnsURI );
	$xc->registerNs( $iphotons => $iphotonsURI );
	$xc->registerNs( $idiskns => $idisknsURI );
	$xc->registerNs( $dotmacns => $dotmacnsURI );
	
	foreach my $ccc ($xc->findnodes('//NSDAV:multistatus//NSDAV:response//NSDAV:propstat//NSDAV:prop')) {
		print "Found a NSDAV\n";
		foreach my $iphoto ( $xc->findnodes('./iphoto:*', $ccc) ) {
			my $set = $propertyupdate->appendChild($proppatch->createElement("$DAVns:set"));
			my $prop = $set->appendChild($proppatch->createElement("$DAVns:prop"));
			my $newn = $iphoto->cloneNode(1);
			$prop->appendChild($newn);
		}
		 foreach my $idisk ( $xc->findnodes('./idisk:*', $ccc) ) {
			my $set = $propertyupdate->appendChild($proppatch->createElement("$DAVns:set"));
			my $prop = $set->appendChild($proppatch->createElement("$DAVns:prop"));
			my $newn = $idisk->cloneNode(1);
			$prop->appendChild($newn);
		}
		 foreach my $dotmac ( $xc->findnodes('./dotmac:*', $ccc) ) {
			my $set = $propertyupdate->appendChild($proppatch->createElement("$DAVns:set"));
			my $prop = $set->appendChild($proppatch->createElement("$DAVns:prop"));
			my $newn = $dotmac->cloneNode(1);
			$prop->appendChild($newn);
		}
	}
	$logging =~ m/Sections/&&$r->log->info("#### PROPPATCH : ". $proppatch->toString() );
	my $proppatchResponse = subrequest($r, 'PROPPATCH', $targeturi,  $proppatch->toString());
	#$propfindAlbumResponse->[1]
	$logging =~ m/Sections/&&$r->log->info("#### PROPPATCH returned : ". $proppatchResponse->[0] .' - '. $proppatchResponse->[1] );
}

sub dmoverlay_response{
	my ($r,$responsearray) = @_;
	my $content="<?xml version=\"1.0\" encoding=\"utf-8\" ?><multistatus xmlns=\"DAV:\">";
	my $holding;
	while ($holding = pop(@$responsearray)) {
		$content=$content."
<response xmlns=\"DAV:\">
 <href href-type=\"source\">".$$holding[0]."</href>
 <href href-type=\"target\">".$$holding[1]."</href>
 <status>HTTP/1.1 200 OK</status>
 <responsedescription>Action ".$$holding[3]."</responsedescription>
</response>\n";
	}
	$content=$content."</multistatus>\n";
	return $content;
}

sub formCurrentServer{
	my ($r) = @_;
	my $httpType="http://";
	$httpType="https://" if $r->get_server_port() == 443;
	return $httpType.$r->headers_in->{'Host'};
}
sub recursiveMKCOL
	{
	my ($r,$uri) = @_;
	$uri=$r->uri if $uri eq "";
	my $logging = $r->dir_config('LoggingTypes');
	my $lcv1; ### The outer loop which will be the path element we are currently working with
	my $lcv2; ### The inner loop which will be all of the elements up until the current one
	my @arr=split("/",$uri); 
	shift @arr if $arr[0] eq ""; ### Drop the initial element off, which should normally be ""
	my $resulturi; ### The temp URI we are working with 
	my @outarr; ### the array of arrays we return back (contains result code and path
	my ($subreq,$rc);
	for($lcv1=0; $lcv1 < scalar @arr; $lcv1++){
		my @tmparr=();
		for ($lcv2=0; $lcv2 <= $lcv1; $lcv2++) {
			push(@tmparr,$arr[$lcv2]);
			}
			$resulturi="/".join("/",@tmparr);
			$subreq = $r->lookup_method_uri("MKCOL", $resulturi);
			$subreq->headers_out->{'X-Webdav-Method'}="";
			$subreq->add_output_filter(\&DotMac::NullOutputFilter::handler);
			$logging=~m/SubreqDebug/&&$r->log->info("recursiveMKCOL request: ". Dumper($subreq));
			$rc=$subreq->run;
			$logging=~m/SubreqDebug/&&$r->log->info("Subreq call with $resulturi returned $rc");
			$rc = 200 if ($rc == 405); ### Convert the return code to HTTP OK if the create fails for a directory
			$rc = 201 if ($rc == 0); ### Convert the return code to HTTP CREATED if the create suceeds.
			push(@outarr,([$rc,$resulturi]));
		}
		$logging=~m/SubreqDebug/&&$r->log->info(Dumper(\@outarr));
		
	return @outarr;
	}

sub dmpatchpaths_response {
	my ($r, @resparr) = @_;
	my $innerarr;
	my $content="<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n<INS:response-status-set xmlns:INS=\"http://idisk.mac.com/_namespace/set/\">\n";
	foreach $innerarr (@resparr) {
		my $xmlout=$innerarr->[1];
		$xmlout=~s/\<\?xml version="1.0" encoding="utf-8"\?\>//g;
		$content=$content.$xmlout;
		}
	$content=$content."</INS:response-status-set>\n";
	return $content;
	}
sub dmpatchpaths_request {
	my ($r, $inXML) = @_;
	my $logging = $r->dir_config('LoggingTypes');
	my $DAVns = 'NSDAV';
	my $DAVnsURI = 'DAV:';
	my $iphotons = 'iphoto';
	my $iphotonsURI = 'urn:iphoto:property';
	my $idiskns = 'idisk';
	my $idisknsURI = 'http://idisk.mac.com/_namespace/set/';
	my $dotmacns = 'dotmac';
	my $dotmacnsURI = 'urn:dotmac:property';
	my @retarr;
	my $parser = XML::LibXML->new();
	my $doc    = $parser->parse_string($inXML);
	my $xc     = XML::LibXML::XPathContext->new( $doc->documentElement() );
	$xc->registerNs( $DAVns => $DAVnsURI );
	$xc->registerNs( $iphotons => $iphotonsURI );
	$xc->registerNs( $idiskns => $idisknsURI );
	$xc->registerNs( $dotmacns => $dotmacnsURI );
	
	foreach my $ccc ($xc->findnodes('//idisk:request-instructions-set//idisk:request-instructions')) {
		my $action = $xc->findnodes('./idisk:action', $ccc)->[0]->textContent();
		print "Found idisk:request-instruction: $action\n";
		if ($action eq 'PROPPATCH') {
			my $href = $xc->findnodes('./idisk:href', $ccc)->[0]->textContent();
			print "href: $href\n";
			my $proppatchrequest = $xc->findnodes('./NSDAV:propertyupdate', $ccc)->[0];
			#setup a new proppatch xml doc
			my $proppatchxml = XML::LibXML::Document->createDocument('1.0', 'UTF-8');
			my $newn = $proppatchrequest->cloneNode(1);
			$proppatchxml->setDocumentElement($newn);
			my $xc     = XML::LibXML::XPathContext->new( $proppatchxml->documentElement() );
			$xc->registerNs( $DAVns => $DAVnsURI );
			$xc->registerNs( $iphotons => $iphotonsURI );
			$xc->registerNs( $idiskns => $idisknsURI );
			$xc->registerNs( $dotmacns => $dotmacnsURI );
			$logging =~ m/Sections/&&$r->log->info("#### PROPPATCH: ".$proppatchxml->toString());
			my $proppatchResponse = subrequest($r, 'PROPPATCH', $href,  $proppatchxml->toString());
			#my $proppatchResult = DotMac::DMUserAgent::handler($r, "PROPPATCH", $href, $proppatchxml->toString() );
			$logging =~ m/Sections/&&$r->log->info("#### PROPPATCH result: ".$proppatchResponse->[1]);
			push(@retarr,$proppatchResponse);
		}
	}
	return @retarr;
}

sub subrequest {
	my ($r, $method, $href, $xml, $headers) = @_;
	my $subreq;
	#my $rc;
	my $logging = $r->dir_config('LoggingTypes');
	my ($key,$value);
	$r->log->info("source: ".$href." Destination: ".$$headers{'Destination'});
	#$subreq->add_output_filter(\&DotMac::CaptureOutputFilter);			
	#$subreq->add_input_filter(\&DotMac::PostingInputFilter::handler);
	#$subreq->headers_in->{'X-Webdav-Method'}="";
    my $returndata=DotMac::DMUserAgent::handler($r,$method, $href, $xml, $headers);
	$logging =~ m/SubreqDebug/&&$r->log->info("Captured Data dm: ".$returndata->[1]);
	return ($returndata);
}

sub dmmkpath_request { 
	my ($r, $inXML) = @_;
	my $xp = new XML::DOM::Parser(ErrorContext => 2);
	my $requestxml = $xp->parse($inXML);
	my $requestrootnode = $requestxml->getElementsByTagName('x0:request-instructions-set')->[0];
	my $requestxml_root = $requestxml->getDocumentElement;
	my $requestInstructions = $requestrootnode->getElementsByTagName('x0:request-instructions'); # gather all 'transaction' child nodes
	my $requestInstructionsCount = $requestInstructions->getLength();
	#carp ("I have $requestInstructionsCount instructions \n");
	my @outarr;

	# our node looks like:
	# <x0:request-instructions>
	# <x0:action>DMMKPATH</x0:action>
	# <x0:href>/sjorsdeberekorst1/Web/.Temporary%20Web%20Resources/5657C625-B34F-4173-8717-9B11DEE57A81/Site/sjorsdeberekorst1_dot_com/sjorsdeberekorst1_dot_com_files</x0:href>
	# <x0:success-codes>207</x0:success-codes>
	# </x0:request-instructions>
	for (my $j = 0; $j < $requestInstructionsCount; $j++)
			{
				my $action = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:action')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				my $href = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:href')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				my $successcodes = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:success-codes')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				#print ("action: $action, href: $href, success-codes: $successcodes\n");
				
				if ($action eq 'DMMKPATH')
					{
						push(@outarr,recursiveMKCOL($r,$href));

					}
		
			}
		return (@outarr);
	}

sub returnHTTPCodesText {
	my ($val) = @_;
	if ($val == 201) {
		return "HTTP/1.1 201 Created";
	} elsif ($val == 200) {
		return "HTTP/1.1 200 Ok";
	} elsif ($val == 405) {
		return "HTTP/1.1 405 Method Not Allowed";
	} else {
		return "HTTP/1.1 $val UNKNOWN";
	}
}
sub truthget_generate {
	my ($r,$content,$user) = @_;
	my @datearray=gmtime(time());
	my $lastupdate=sprintf('%s-%#.2d-%#.2dT%#.2d:%#.2d:%#.2dZ',$datearray[5]+1900,$datearray[4]+1,$datearray[3],$datearray[2],$datearray[1],$datearray[0]);


my ($parser,$doc,$dom);

$content =~ s/D:prop/prop/g;
$content =~ s/\n//g;
$r->log->info("truthget:".$content);
$parser = XML::LibXML->new();
$parser->clean_namespaces(1);
my $truthget = XML::LibXML::Document->createDocument("1.0","UTF-8");
my $feed=$truthget->createElement("feed");
$truthget->setDocumentElement($feed);
### Set Namespace Stuff Here
$feed->setNamespace("urn:iweb:","iweb",0);
$feed->setNamespace("urn:iphoto:property","iphoto",0);
$feed->setNamespace("http://www.itunes.com/dtds/podcast-1.0.dtd","itunes",0);
$feed->setNamespace("http://www.w3.org/2005/Atom","",0);
$feed->setNamespace("urn:dotmac:property","dotmac",0);
$feed->setNamespace("DAV:","D",0);
my $newworkingnode = $truthget->createElement("Generator");
$newworkingnode->appendText("dotMac Truth Maker");
$feed->appendChild($newworkingnode);

$newworkingnode = $truthget->createElement("title");
$newworkingnode->appendText("Apple .Mac user iDisk");
$feed->appendChild($newworkingnode);

$newworkingnode = $truthget->createElement("updated");
$newworkingnode->appendText($lastupdate);
$feed->appendChild($newworkingnode);

$newworkingnode = $truthget->createElement("author");
$newworkingnode->appendChild($truthget->createElement("name"));
$feed->appendChild($newworkingnode);

$newworkingnode = $truthget->createElement("id");
$newworkingnode->appendText("http://web.mac.com/".$user);
$feed->appendChild($newworkingnode);

$dom = $parser->parse_string($content);
my $rootnode = $dom->documentElement;
my $rootsubnodescount = scalar @{$rootnode->childNodes};
#$r->log->info("Here ABC".Dumper(@{$rootnode->childNodes}[$lcv]->toString()));
#	$r->log->info("Here ABC".Dumper($rootnode->childNodes));

#print Dumper(@{$rootnode->childNodes}->[0]->getNamespaces);
my $currentnode;
for (my $lcv=0; $lcv < $rootsubnodescount; $lcv++) {
	$currentnode=@{$rootnode->childNodes}[$lcv];
	
	my $ns;
	foreach $ns ($currentnode->getNamespaces){
#		print $ns->getLocalName.":".$ns->getData."\n";
		if ($ns->getData eq "urn:dotmac:property") {
			$currentnode->setNamespaceDeclPrefix($ns->getLocalName,"dotmac");
		} elsif ($ns->getData eq "urn:iphoto:property") {
			$currentnode->setNamespaceDeclPrefix($ns->getLocalName,"iphoto");
		}


	}

	my $href=@{$currentnode->getElementsByLocalName("href")}[0]->textContent;
		
	my $propstatnode=@{$currentnode->getElementsByLocalName("propstat")}[0];
	$currentnode=@{$propstatnode->getElementsByLocalName("prop")}[0];
	$currentnode->setNodeName("entry");
	$currentnode->setOwnerDocument($truthget);
	$feed->addChild($currentnode);
	my $hrefnode=$truthget->createElement("link");
	$hrefnode->setAttribute("rel","alternate");
	$hrefnode->setAttribute("href","http://publish.mac.com".$href);
	$currentnode->addChild($hrefnode);
	for (my $lcv1=0; $lcv1 < scalar @{$currentnode->childNodes}; $lcv1++ ) {
		my $currentnode1=@{$currentnode->childNodes}[$lcv1];
					
#		print $currentnode1->lookupNamespaceURI($currentnode1->prefix)."\n";
#		print $currentnode1->prefix."\n";
		if ($currentnode1->prefix eq "D"){
#			print $currentnode1->getName."\n";
			$currentnode1->parentNode->removeChild($currentnode1);
			$lcv1--;
		}
		
		
	}
	 

}
$newworkingnode = $truthget->createElement("recCount");
$newworkingnode->appendText(scalar @{$truthget->getElementsByTagName("entry")});
$newworkingnode->setNamespace("urn:dotmac:property","dotmac",1);
$feed->insertBefore($newworkingnode,@{$feed->childNodes}[4]);



my $str= $truthget->toString(1);
#$str=~ s/>/>\n/g;
return $str;
}

sub dmmkpath_response
	{
	my (@arr)  = @_;
	my $innerarr;
	my $responsexml = XML::DOM::Document->new();
	my $decl=new XML::DOM::XMLDecl;
	$decl->setVersion("1.0");
	$decl->setEncoding("UTF-8");
	$responsexml->setXMLDecl($decl);
	my $responserootnode = $responsexml->createElement('INS:response-status-set'); # this is the root node
	$responserootnode->setAttribute('xmlns:INS', 'http://idisk.mac.com/_namespace/set/');

	foreach $innerarr (@arr) {
		my $responsemultistatus = $responsexml->createElement('multistatus');
		$responsemultistatus->setAttribute('xmlns', 'DAV:');
		my $responsemultistatusresponse = $responsexml->createElement('response');
		$responsemultistatusresponse->setAttribute('xmlns', 'DAV:');
		my $hrefelement = $responsexml->createElement('href');
		my $hreftextnode = $responsexml->createTextNode($innerarr->[1]);
		$hrefelement->appendChild($hreftextnode);
		$responsemultistatusresponse->appendChild($hrefelement);

		my $statuselement = $responsexml->createElement('status');

		my $statustextnode;
		my $msg=returnHTTPCodesText($innerarr->[0]);
		$statustextnode = $responsexml->createTextNode($msg);
		$statuselement->appendChild($statustextnode);
		$responsemultistatusresponse->appendChild($statuselement);
		$responsemultistatus->appendChild($responsemultistatusresponse); # append the 'multistatus' childnode;
		$responserootnode->appendChild($responsemultistatus);
		}
		$responsexml->appendChild($responserootnode);
	return ($responsexml->toString());
	}

sub URLDecode {
    my $theURL = $_[0];
    $theURL =~ tr/+/ /;
    $theURL =~ s/%([a-fA-F0-9]{2,2})/chr(hex($1))/eg;
    $theURL =~ s/<!--(.|\n)*-->//g;
    return File::Spec->canonpath($theURL);
}

sub movefile 
	{ 
	my ($rootpath, $source, $dest) = @_;
	my $sourcepath="$rootpath/$source";
	my $destpath="$rootpath/$dest";
	move($sourcepath, $destpath) || die "Sorry system is unable to move flie $sourcepath to $destpath";
	}
	
sub check_for_dir_backref {
	my ($line) = @_;
	if ($line =~ m/\/\.\./) {
		return 1;
	} else { 
		return 0;
	}
}

sub authen_user_file{
	my ($r, $username, $password) = @_;
	carp $r->dir_config('dotMacUserDB');
	my @htfile = (	DBType => 'Text',
				DB     => $r->dir_config('dotMacUserDB'),
				Server => 'apache',
				Encrypt => 'MD5');
	my $user = new HTTPD::UserAdmin @htfile;
	# grab realm:hashedpassword from digest database
	my $info = $user->password($username);
	my($realm, $checksum) = split(":", $info);
	# generate realm:hashedpassword from supplied password
	my $digestpassword =$user->encrypt("$username:$realm:$password");
	if ($info eq $digestpassword) {
		return 1;
		}
	else {
		return 0;
		}
	}

sub authen_user_sql{
	my ($dsn, $user, $sent_pw) = @_;
	carp "AuthenDOTMAC_SQL";
	my $u = $user;
	my $dbh = DBI->connect("DBI:mysql:database=dotmac;host=localhost", "dotmac", "dotmac");
	my $q = "SELECT passwd FROM auth WHERE username=\'$u\'";
	my $QueryPW = $dbh->prepare($q);
	$QueryPW->execute;
	my $passwd = $QueryPW->fetchrow_array;
	
	$QueryPW->finish;
	$dbh->disconnect;

	my $md5 = Digest::MD5->new();
	$md5->add("$u:idisk.mac.com:$sent_pw");
	my $gen_passwd = $md5->hexdigest; 

	if ($passwd eq $gen_passwd) {
		return 1;
	} else {
		return 0;
	}
    }


sub get_user_quota_sql{
	my ($dsn, $user) = @_;
	carp "QuotaDotMac_SQL";
	my $dbh = DBI->connect("DBI:mysql:database=dotmac;host=localhost", "dotmac", "dotmac");
	my $q = "SELECT idisk_quota_limit FROM auth WHERE username=\'$user\'"; 
	my $dbq = $dbh->prepare($q);
	$dbq->execute;
	my ($quota) = $dbq->fetchrow_array;
	$dbq->finish;
	$dbh->disconnect;
	return $quota;
	}

sub get_user_quota_file{
	my ($r, $user) = @_;
	my $dotMacUserDataPath = $r->dir_config('dotMacUserDataPath');
	my $dotMacUdataDBname = $r->dir_config('dotMacUdataDBname');
#	my %userData = DotMac::CommonCode::readUserDB("$dotMacUserDataPath/$user/$dotMacUdataDBname", my %attributes);
#	return $userData{'quota'};
	return do_get_user_quota("$dotMacUserDataPath/$user/$dotMacUdataDBname");
	}

sub do_get_user_quota{
	my ($db) = @_;
	my %userData = readUserDB($db, my %attributes);
	return $userData{'quota'};
	}

sub get_user_quota_used{
	my ($r, $user) = @_;
	my $home_dir = $r->dir_config('dotMaciDiskPath') . "/$user";
	my $quotaUsedBytes = `du -sk $home_dir`; chop($quotaUsedBytes);# query for usage in KiloBytes
	$quotaUsedBytes =~ s/^(\d+)(.*)/$1/;
	return $quotaUsedBytes;
	}

 sub list_users_file{
	my ($r) = @_;
	my $dbFile = $r->dir_config('dotMacUserDB');
	return do_list_users_file($dbFile);
	}

 sub do_list_users_file{
	my ($dbFile) = @_;
	my @htfile = (	DBType => 'Text',
				DB     => $dbFile,
				Server => 'apache',
				Encrypt => 'MD5');
	my $userAdmin = new HTTPD::UserAdmin @htfile;
	my @users = $userAdmin->list;
	return sort @users;
	}

sub list_users_sql{
	my ($dsn) = @_;
	carp "ListUsersDotMac_SQL";
	my $dbh = DBI->connect("DBI:mysql:database=dotmac;host=localhost", "dotmac", "dotmac");
	my $q = $dbh->prepare("SELECT username FROM auth");
	$q->execute;

	my @userlist = ();
	while (my ($user) = $q->fetchrow_array) {
		push @userlist, $user;
	}

	$q->finish;
	$dbh->disconnect;

	return sort @userlist;
	}

 sub dec2hex {
    # parameter passed to
    # the subfunction
    my $decnum = $_[0];
    # the final hex number
    
    #my $hexnum;
    #my $tempval;
    #initialize properly for not getting 'uninitialized value in concatenation (.) or string' error
    my $hexnum = '';
    my $tempval = '';
    
    while ($decnum != 0) {
		# get the remainder (modulus function)
		# by dividing by 16
		$tempval = $decnum % 16;
		# convert to the appropriate letter
		# if the value is greater than 9
		if ($tempval > 9) {
			$tempval = chr($tempval + 87); # 55 for uppercase
			}
		# 'concatenate' the number to 
		# what we have so far in what will
		# be the final variable
		$hexnum = $tempval . $hexnum ;
		# new actually divide by 16, and 
		# keep the integer value of the 
		# answer
		$decnum = int($decnum / 16); 
		# if we cant divide by 16, this is the
		# last step
		if ($decnum < 16) {
			# convert to letters again..
			if ($decnum > 9) {
				$decnum = chr($decnum + 87); # 55 for uppercase
				}
		
			# add this onto the final answer.. 
			# reset decnum variable to zero so loop
			# will exit
			$hexnum = $decnum . $hexnum; 
			$decnum = 0 
			}
		}
    return $hexnum;
    } # end sub

sub dmmkpaths
	{ my ( $r, $inXML) = @_;
	my $xp = new XML::DOM::Parser(ErrorContext => 2);
	my $requestxml = $xp->parse($inXML);
	my $requestrootnode = $requestxml->getElementsByTagName('x0:request-instructions-set')->[0];
	my $requestxml_root = $requestxml->getDocumentElement;
	my $requestInstructions = $requestrootnode->getElementsByTagName('x0:request-instructions'); # gather all 'transaction' child nodes
	my $requestInstructionsCount = $requestInstructions->getLength();
	carp ("I have $requestInstructionsCount instructions \n");
	
	my $ruser=$r->user;
 	my $idiskpath = $r->dir_config('dotMaciDiskPath'); #"/var/www/dotmac/iDisk";
	my $responsexml = XML::DOM::Document->new();
	my $decl=new XML::DOM::XMLDecl;
	$decl->setVersion("1.0");
	$decl->setEncoding("UTF-8");
	$responsexml->setXMLDecl($decl);
	my $responserootnode = $responsexml->createElement('INS:response-status-set'); # this is the root node
	$responserootnode->setAttribute('xmlns:INS', 'http://idisk.mac.com/_namespace/set/');
	# our node looks like:
	# <x0:request-instructions>
	# <x0:action>DMMKPATH</x0:action>
	# <x0:href>/sjorsdeberekorst1/Web/.Temporary%20Web%20Resources/5657C625-B34F-4173-8717-9B11DEE57A81/Site/sjorsdeberekorst1_dot_com/sjorsdeberekorst1_dot_com_files</x0:href>
	# <x0:success-codes>207</x0:success-codes>
	# </x0:request-instructions>
	for (my $j = 0; $j < $requestInstructionsCount; $j++)
			{
				
	#			<multistatus xmlns="DAV:">
	#			<response xmlns="DAV:">
	#			 <href>/sjorsdeberekorst1/</href>
	#			 <status>HTTP/1.1 200 OK</status>
	#			</response>
	#			</multistatus>
				my $action = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:action')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				my $href = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:href')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				
				my $fspath = URLDecode($href);
				
				my $successcodes = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:success-codes')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				#print ("action: $action, href: $href, success-codes: $successcodes\n");
				
				#setup a new xml node
				my $responsemultistatus = $responsexml->createElement('multistatus');
				$responsemultistatus->setAttribute('xmlns', 'DAV:');
				my $responsemultistatusresponse = $responsexml->createElement('response');
				$responsemultistatusresponse->setAttribute('xmlns', 'DAV:');
				if ($action eq 'DMMKPATH')
					{
					my $hrefelement = $responsexml->createElement('href');
					my $hreftextnode = $responsexml->createTextNode($href);
					$hrefelement->appendChild($hreftextnode);
					$responsemultistatusresponse->appendChild($hrefelement);
					my $statuselement = $responsexml->createElement('status');
					my $statustextnode;
					if ((check_for_dir_backref($fspath)) || ($fspath !~ m/^\/$ruser\//)) { #either there's backref(s) in our uri, or our uri doesn't start with $ruser
						$statustextnode = $responsexml->createTextNode('HTTP/1.1 403 Forbidden');
						}
					else {
						#we really should have/check a response status from recursiveMKdir
						recursiveMKdir($idiskpath, $fspath);
						$statustextnode = $responsexml->createTextNode('HTTP/1.1 201 Created');
						}
					$statuselement->appendChild($statustextnode);
					$responsemultistatusresponse->appendChild($statuselement);
					}
				$responsemultistatus->appendChild($responsemultistatusresponse); # append the 'multistatus' childnode;
				$responserootnode->appendChild($responsemultistatus); # append the 'multistatus' childnode;
			}
	$responsexml->appendChild($responserootnode);
	return ($responsexml->toString());
	}

sub XMLDOMgetFirstChildByName
  { my( $node, $tag)= @_;
    return $node->getElementsByTagName($tag)->[0];
  }

sub file_size
	{ 
	my $nr = shift;
	my $i = 0;
	my @units = qw/B KB MB GB TB/;
	while ( $nr > 1024 ) {
		$nr /= 1024 ;
		$i++ ;
	}
	$nr = sprintf("%.2f ", $nr);
	$nr .= $units[$i] ;
    return $nr;
	}
1;
