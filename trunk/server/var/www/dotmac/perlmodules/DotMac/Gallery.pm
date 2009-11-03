#file:DotMac/Gallery.pm;
#-----------------------------

## Copyright (C) 2008 Walinsky
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

package DotMac::Gallery;

use strict;
use warnings;

use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Log ();
use Apache2::Filter;
use Apache2::Const -compile => qw(OK);
use JSON;
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);
use DotMac::CommonCode;
use Compress::Zlib;
use URI::Split qw(uri_split);
use XML::LibXML;
use APR::Const;
use APR::UUID;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
# $DotMac::Gallery::VERSION = '0.1';

sub handler {
	my $r = shift;
	my $dotMacCachePath = $r->dir_config('dotMacCachePath');
	$r->content_type("text/html");
	$r->header_out("Server" => "AppleIDiskServer-666");
	$r->header_out("x-responding-server" => "hpng666");
	$r->header_out("X-dmUser" => "walinsky");
	$r->header_out("Connection" => "keep-alive");
	$r->header_out("Vary" => "Accept-Encoding");
	$r->sendfile("$dotMacCachePath/gallery.html");
	return Apache2::Const::OK;
	}

sub ziplistHandler {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my @dotMacUsers = $r->dir_config->get('dotMacUsers');
	my ($buf, $content, $XdmUser);
	my $content_length = $r->header_in('Content-Length');
	my $xZipToken = APR::UUID->new->format;
	if ($content_length > 0) {
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
	$logging =~ m/Gallery/&&$r->log->info("Content from POST: $content");
	}

	#set up a new xml response doc
	my $DAVns = 'D';
	my $DAVnsURI = 'DAV:';
	my $responseDoc = XML::LibXML::Document->createDocument('1.0', 'UTF-8');
	my $multistatus = $responseDoc->createElement('multistatus');
	$multistatus->setNamespace( $DAVnsURI , undef );
	$responseDoc->setDocumentElement($multistatus);
	
	#parse the data we got
	my $parser = XML::LibXML->new();
	my $data = $parser->parse_string($content);
	my $xc = XML::LibXML::XPathContext->new($data);
	$xc-> registerNs( weAllLoveNamespaces  => 'http://user.mac.com/properties/' );
	my $zip = Archive::Zip->new();
	foreach my $entrynode ($xc->findnodes("//weAllLoveNamespaces:ziplist/weAllLoveNamespaces:entry")) {
		my $response = $multistatus->appendChild($responseDoc->createElement("response"));
		$response->setNamespace( $DAVnsURI , undef );
		my $responsehref = $response->appendChild($responseDoc->createElement("href"));
		my $responsestatus = $response->appendChild($responseDoc->createElement("status"));
		my $responsedesc = $response->appendChild($responseDoc->createElement("responsedescription"));
		my $name = $xc->findvalue("./weAllLoveNamespaces:name", $entrynode);
		my $href = $xc->findvalue("./weAllLoveNamespaces:href", $entrynode);
		my ($scheme, $auth, $path, $query, $frag) = uri_split($href);
		foreach my $username (@dotMacUsers) {
			if($path =~m{^/$username/(.*)})  {
				$XdmUser = $username;
				$path = "/$username/Web/Sites/_gallery/$1";
			}
		}
		my $filepath = $r->document_root.$path;
		my $hreftextnode = $responseDoc->createTextNode($href);
		$responsehref->appendChild($hreftextnode);
		
		$logging =~ m/Gallery/&&$r->log->info("name: $name - href: $href - path: $path");
		if (!DotMac::CommonCode::check_for_dir_backref($path)) {
			# I think we should be ok
			if (-f $filepath) {
				# do some fancy zip methods - adding the file to a zip file
				my $file_member = $zip->addFile( $filepath, $name );
				my $statustextnode = $responseDoc->createTextNode('HTTP/1.1 200 OK');
				$responsestatus->appendChild($statustextnode);
				my $desctextnode = $responseDoc->createTextNode('Zipped Successfully');
				$responsedesc->appendChild($desctextnode);
			}
			else {
				# ppl are trying to do things we don't like; set a 404 in the xml
				my $statustextnode = $responseDoc->createTextNode('HTTP/1.1 404 Not Found');
				$responsestatus->appendChild($statustextnode);
				my $desctextnode = $responseDoc->createTextNode('Expected file did not exist');
				$responsedesc->appendChild($desctextnode);
			}
		}
		else {
			# ppl are trying to do things we don't like; set a 404 in the xml
			my $statustextnode = $responseDoc->createTextNode('HTTP/1.1 404 Not Found');
			$responsestatus->appendChild($statustextnode);
			my $desctextnode = $responseDoc->createTextNode('Expected file did not exist');
			$responsedesc->appendChild($desctextnode);
		}
	}
	if (! -d $r->dir_config( 'dotMacCachePath') . "/tmp") {
		DotMac::CommonCode::recursiveMKdir($r->dir_config( 'dotMacCachePath'), "tmp");
	}
	# Save the Zip file
   unless ( $zip->writeToFileNamed($r->dir_config( 'dotMacCachePath') . "/tmp/" . $xZipToken . ".zip" ) == AZ_OK ) {
       # we should actually send a different responseXMLstring now
       $logging =~ m/Gallery/&&$r->log->info("failed to create zip file");
   }
	my $responseXMLstring = $responseDoc->toString();
	$logging =~ m/Gallery/&&$r->log->info($responseXMLstring);
	
##HTTP/1.1 207 Multi-Status
##Content-Type	text/xml;charset=utf-8
##Server	AppleIDiskServer-1E4131
##x-responding-server	truthng001
##X-dmUser	walinsky
##Content-Location	/walinsky/100083/
##X-Zip-Token	1g3s18hn-4ujp-13sjyju3eo-2cn617ze5k0
##Content-Length	32067
##Date	Sat, 03 Oct 2009 12:14:16 GMT
##Connection	keep-alive
##X-UA-Compatible	IE=Edge
	$r->content_type("text/xml;charset=utf-8");
	$r->header_out("Server" => "AppleIDiskServer-666");
	$r->header_out("x-responding-server" => "truthng666");
	$r->header_out("X-dmUser" => $XdmUser);
	$r->header_out("X-Zip-Token" => $xZipToken);
	$r->header_out('Content-Length', length( $responseXMLstring ));
	$r->header_out("Connection" => "keep-alive");
	$r->header_out("X-UA-Compatible" => "IE=Edge");
	$r->print($responseXMLstring);
	$r->status(207);
	return Apache2::Const::OK;##HTTP/1.1 207 Multi-Status!!!
	}

sub zipgetHandler {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my @dotMacUsers = $r->dir_config->get('dotMacUsers');
	my $XdmUser;
	##	GET /walinsky/100083/somefile.zip?webdav-method=ZIPGET&token=1g3s18hn-4ujp-13sjyju3eo-2cn617ze5k0&disposition=download
	
	foreach my $username (@dotMacUsers) {
		if($r->uri =~m{^/$username/(.*)})  {
			$XdmUser = $username;
		}
	}
	
	my $dotMacCachePath = $r->dir_config('dotMacCachePath');
	my $webdavmethod =  $r->notes->get('webdavmethod');
	my $token =  $r->notes->get('token');
	my $disposition =  $r->notes->get('disposition');
	my $tmpZipFile = "$dotMacCachePath/tmp/" . $token . ".zip";
#HTTP/1.1 200 OK
#Content-Length: 2298104
#Content-Type: application/zip
#Server: AppleIDiskServer-1E4131
#x-responding-server: truthng002
#X-dmUser: emily_parker
#Last-Modified: Sun, 04 Oct 2009 17:19:47 GMT
#Content-disposition: attachment;
#Date: Sun, 04 Oct 2009 17:20:18 GMT
#Connection: keep-alive
#X-UA-Compatible: IE=Edge
	if ( ($token =~ m/([a-zA-Z\-_0-9]+)/) && ( -f $tmpZipFile ) ) {
		#	$r->header_out("Content-Length" => "2298104"); should be handled by sendfile
		$r->header_out("Content-Type" => "application/zip");
		$r->header_out("Server" => "DotMobileUsServer-666");
		$r->header_out("x-responding-server" => "truthng666");
		$r->header_out("X-dmUser" => $XdmUser);
		$r->header_out("Content-disposition" => "attachment");
		$r->header_out("Connection" => "keep-alive");
		$r->header_out("X-UA-Compatible" => "IE=Edge");
		my $status = $r->sendfile($tmpZipFile);
		die "sendfile has failed" unless $status == APR::Const::SUCCESS;
		$r->pool->cleanup_register(\&cleanupTmpZipFile, $r);
	} else {
		$r->status(404);
	}
	# do some cleanup routine here maybe - or set a post handler for cleanup tasks
	# cleaning up files older than a certain amount of time
	return Apache2::Const::OK;
}
	
sub cleanupTmpZipFile {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $token =  $r->notes->get('token');
	my $tmpdir = $r->dir_config( 'dotMacCachePath') . "/tmp/";
	my $tmpZipFile = $tmpdir . $token . ".zip";
	##delete the file
	$logging =~ m/Gallery/&&$r->log->info("deleting $tmpZipFile");
	unlink $tmpZipFile or die "failed to unlink $tmpZipFile" if -e $tmpZipFile;;
	## if users haven't successfully downloaded their zip files successfully previously
	## there'll be leftovers in the tmp dir_config
	## we can safely assume we can delete these files after 1 day
	## this value is hardcoded now - we might decide making this a configurable option
	foreach my $tmpFile(glob("$tmpdir*")){
		my $age=-M $tmpFile;
		if($age>1){
			if (-f $tmpFile) {
				$logging =~ m/Gallery/&&$r->log->info("also deleting $tmpFile");
				unlink $tmpFile or die "Error removing $tmpFile\n$!, stopped";
			}
		}
	}
	return Apache2::Const::OK;
}

sub truthgetHandler {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');

##	ok here's the deal
## 	first do a propfind/depth 1 on _gallery for fetching:
##	'updated' 'title' and 'userorder' nodes for (json) 'data'
##	build a list of subdirs (albums) from _gallery - and loop over them propfind'ing (depth 1 ) for our 'records'

	my %resultdata = ( status => 1 ); # Warning: magic constant, no idea what it means...
	my $username;
	my $albumGuid;
	my %galleryData =();
	
	my $DAVns = 'NSDAV';
	my $DAVnsURI = 'DAV:';
	my $iphotons = 'iphoto';
	my $iphotonsURI = 'urn:iphoto:property';
	my $idiskns = 'idisk';
	my $idisknsURI = 'http://idisk.mac.com/_namespace/set/';
	my $dotmacns = 'dotmac';
	my $dotmacnsURI = 'urn:dotmac:property';
	
#let's assume we call _gallery
	my $propfindResponse = DotMac::CommonCode::subrequest($r, 'PROPFIND', $r->uri, '<?xml version="1.0" encoding="utf-8" ?><D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>', {'Depth'=> '1'});
	$logging =~ m/Gallery/&&$r->log->info("truthgetHandler got response ". $propfindResponse->[1]); # 207 (multistatus)
	
	my $parser = XML::LibXML->new();
	my $data = $parser->parse_string($propfindResponse->[1]);
	my $xc = XML::LibXML::XPathContext->new($data);
	$xc->registerNs( $DAVns => $DAVnsURI );
	$xc->registerNs( $iphotons => $iphotonsURI );
	$xc->registerNs( $idiskns => $idisknsURI );
	$xc->registerNs( $dotmacns => $dotmacnsURI );

	my $resultdatarecordnum = 0;
	
	foreach my $responsenode ($xc->findnodes("//$DAVns:multistatus/$DAVns:response")) {
		my $href = $xc->findvalue("./$DAVns:href", $responsenode);
		$logging =~ m/Gallery/&&$r->log->info("href: ########### $href ##########");
		my $prop = $xc->findvalue("./$DAVns:propstat/$DAVns:prop", $responsenode);
		
		if ($href =~ m/Web\/Sites\/_gallery\/$/) {
			$logging =~ m/Gallery/&&$r->log->info("wooH00 $href matches _gallery/");
			## fetch updated, title, and userOrder
			$resultdata{data}{updated} = $xc->findvalue("./$dotmacns:updated", $prop);
			$resultdata{data}{title} = $xc->findvalue("./$dotmacns:title", $prop);
			$resultdata{data}{userOrder} = $xc->findvalue("./$dotmacns:userorder", $prop);
		}
		elsif ($href =~ m/([a-zA-Z_0-9]+)\/Web\/Sites\/_gallery\/[0-9]+\/$/) { # !!! need to verify this match - it should match -only- the 1st level subdirs
			$username = $1;
			&truthgetAlbum ($r, $username, $href, \%resultdata);			
		}
	}
	
	#my $data = '{"records" : [{}],"data" : {},"status" : 1}';
	#my $jsonData = to_json(\%resultdata, {pretty => 1, utf8 => 1});
	my $jsonData = to_json(\%resultdata, {utf8 => 1});
	$logging =~ m/Gallery/&&$r->log->info("truthgetHandler sent data $jsonData");
	#$r->content_type("application/json");
	
	my($sec, $usec) = gettimeofday;
	my $dt = join '-', POSIX::strftime('%Y%m%d-%H%M%S', localtime($sec)), sprintf('%06d', $usec);

	$r->header_out("Cache-Control" => "no-store, no-cache, must-revalidate, max-age=0");
	$r->header_out("Connection" => "keep-alive");
	$r->header_out("Etag" => "<$dt>");
	
	$r->content_type("application/json");
	$r->header_out("Pragma" => "no-cache");
	$r->header_out("Server" => "AppleIDiskServer-666");
	$r->header_out("Vary" => "Accept-Encoding");
	$r->header_out("X-Apple-Cache-Type" => "disk");
	$r->header_out("X-Dmuser" => $username);
	$r->header_out("X-Responding-Server" => "truthng666");
	#$r->header_out("Content-Length" => length($jsonData));
	#$r->print($jsonData);
	
	#$r->content_encoding("gzip");
	#my $gzjsonData = Compress::Zlib::memGzip($jsonData); 
	#$r->header_out('Content-Length', length( $gzjsonData ));
	#$r->print( $gzjsonData );
	
	$r->content_encoding("gzip");
	$r->print(Compress::Zlib::memGzip($jsonData));
	return Apache2::Const::OK;
	}

sub truthgetAlbum {
	my ($r, $username, $href, $resultdata) = @_;
	my $logging = $r->dir_config('LoggingTypes');
	my $albumGuid;
	my $DAVns = 'NSDAV';
	my $DAVnsURI = 'DAV:';
	my $iphotons = 'iphoto';
	my $iphotonsURI = 'urn:iphoto:property';
	my $idiskns = 'idisk';
	my $idisknsURI = 'http://idisk.mac.com/_namespace/set/';
	my $dotmacns = 'dotmac';
	my $dotmacnsURI = 'urn:dotmac:property';
	my $albumRecordNum;
	my $numPhotos = 0;
	my $numMovies = 0;
	my $resultdatarecordnum;
	my $hostname = $r->hostname();
	my $propfindAlbumResponse = DotMac::CommonCode::subrequest($r, 'PROPFIND', $href, '<?xml version="1.0" encoding="utf-8"?><D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>', {'Depth'=> '1'});
	$logging =~ m/Gallery/&&$r->log->info("propfindAlbumResponse: ".$propfindAlbumResponse->[1]);
	my $parser = XML::LibXML->new();
	my $albumData = $parser->parse_string($propfindAlbumResponse->[1]);
	my $albumXc = XML::LibXML::XPathContext->new($albumData);
	$albumXc->registerNs( $DAVns => $DAVnsURI );
	$albumXc->registerNs( $iphotons => $iphotonsURI );
	$albumXc->registerNs( $idiskns => $idisknsURI );
	$albumXc->registerNs( $dotmacns => $dotmacnsURI );
	$logging =~ m/Gallery/&&$r->log->info("parsed xml");

	foreach my $albumResponsenode ($albumXc->findnodes("//$DAVns:multistatus/$DAVns:response")) {
		my $albumHref = $albumXc->findvalue("./$DAVns:href", $albumResponsenode);
		$logging =~ m/Gallery/&&$r->log->info("href: ########### $href ##########");
		my $albumProps = $albumXc->findnodes("./$DAVns:propstat/$DAVns:prop", $albumResponsenode)->[0];
		if ($albumHref =~ m/Web\/Sites\/_gallery\/([0-9]+)\/$/) { # !!! need to verify this match - this should be an album (and the same match as above)
			my $albumUrl = $1;
			$resultdatarecordnum = defined($resultdata->{records}) ? scalar( @{ $resultdata->{records} } ) : 0;
			$logging =~ m/Gallery/&&$r->log->info("album: $albumUrl record# $resultdatarecordnum");
			$albumRecordNum = $resultdatarecordnum;
			$$resultdata{records}[$resultdatarecordnum]{type} = 'Album';
			$$resultdata{records}[$resultdatarecordnum]{sortOrder} = int($albumXc->findvalue("./$iphotons:sortOrder", $albumProps));
			$$resultdata{records}[$resultdatarecordnum]{allowMobile} = $albumXc->findvalue("./$dotmacns:allowMobile", $albumProps) ? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{showMobile} = $albumXc->findvalue("./$dotmacns:showMobile", $albumProps) ? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{title} = $albumXc->findvalue("./$dotmacns:title", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{keyImagePath} = "http://$hostname/$username/$albumUrl/" . $albumXc->findvalue("./$dotmacns:keyImagePath", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{updated} = $albumXc->findvalue("./$dotmacns:updated", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{download} = $albumXc->findvalue("./$dotmacns:download", $albumProps) ? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteFrameCount} = $albumXc->findvalue("./$dotmacns:scrubSpriteFrameCount", $albumProps);

			my $userOrder = $albumXc->findvalue("./$dotmacns:userorder", $albumProps);
			my @userOrderList = split(/,/, $userOrder);
			#$$resultdata{records}[$resultdatarecordnum]{numPhotos} = scalar(@userOrderList);

#TODO - change hardcoded url to $r->uri thingies					
			$$resultdata{records}[$resultdatarecordnum]{url} = "http://$hostname/$username/$albumUrl";
			$$resultdata{records}[$resultdatarecordnum]{addPhoto} = $albumXc->findvalue("./$dotmacns:addPhoto", $albumProps) ? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteFrameWidth} = int($albumXc->findvalue("./$dotmacns:scrubSpriteFrameWidth", $albumProps));
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteFrameHeight} = int($albumXc->findvalue("./$dotmacns:scrubSpriteFrameHeight", $albumProps));

#TODO - find out where on earth we can find the real guid
# guid should be reproducable - it is _not_ specified in properties
			$$resultdata{records}[$resultdatarecordnum]{guid} = $albumXc->findvalue("./$dotmacns:useritemguid", $albumProps); # GAH!!!!
#Could it get worse??? Yes it can!!! XML is not linearized - anyway:
$albumGuid = $albumXc->findvalue("./$dotmacns:useritemguid", $albumProps); # GAH!!!!

			#$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = $albumProps->findnodes('./ns3:viewIdentifier');
			
			#from com.apple.iPhoto.plist:
			# index			:	1
			# album			:	2
			# asset			:	3
			# iphoto.video	:	4
			# movie			:	5
			# aperture.album:	6
			$$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = 2; # is it ???
			$$resultdata{records}[$resultdatarecordnum]{path} = "http://$hostname/$username/$albumUrl"; # is it ???
			
			$$resultdata{records}[$resultdatarecordnum]{keyImageFileExtension} = 'jpg'; # is it ???
			#$resultdata{records}[$resultdatarecordnum]{scrubSpriteKeyFrameIndex} = $albumProps->findnodes('./ns3:scrubSpriteKeyFrameIndex');
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteKeyFrameIndex} = 0; # is it ???
			#userOrder is a list of userItemGuids from subfolders (Photos)
			$$resultdata{records}[$resultdatarecordnum]{userOrder} = $userOrder;
			$$resultdata{records}[$resultdatarecordnum]{keyImageGuid} = uc($userOrderList[0]);

			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteKeyFrameIndex} = $albumXc->findvalue("./$iphotons:keyImageGuid", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{albumWidget} = $albumXc->findvalue("./$dotmacns:albumWidget", $albumProps) ? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{showCaptions} = int($albumXc->findvalue("./$dotmacns:showCaptions", $albumProps));
			$$resultdata{records}[$resultdatarecordnum]{scrubSpritePath} = $albumXc->findvalue("./$dotmacns:scrubSpritePath", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{content} = 8;# WTF ???
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{props} = 3; # WTF ???
			$$resultdata{records}[$resultdatarecordnum]{numMovies} = 0; # WTF ???
			$$resultdata{records}[$resultdatarecordnum]{spriteGuids} = $albumXc->findvalue("./$dotmacns:spriteGuids", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{userItemGuid} = $albumXc->findvalue("./$dotmacns:useritemguid", $albumProps);
#TODO - we should prolly set a counter on (both) albums and album images.
			$$resultdata{records}[$resultdatarecordnum]{userOrderIndex} = 0;
			
			$$resultdata{records}[$resultdatarecordnum]{userHidden} = $albumXc->findvalue("./$dotmacns:userHidden", $albumProps) ? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{accessLogin} = $albumXc->findvalue("./$dotmacns:accessLogin", $albumProps);

			#gah! http://gallery.mac.com/$username/$albumUrl/
			$$resultdata{records}[$resultdatarecordnum]{title} = $albumXc->findvalue("./$dotmacns:title", $albumProps);
			
			
			$$resultdata{records}[$resultdatarecordnum]{scrubSpritePath} = $albumXc->findvalue("./$dotmacns:scrubSpritePath", $albumProps);
			$logging =~ m/Gallery/&&$r->log->info("album: done");
		}
		elsif ($albumHref =~ m/Web\/Sites\/_gallery\/([0-9]+)\/([a-zA-Z\-_0-9]+)\/$/) { # !!! need to verify this match - this should be a Photo or a Movie
			my $albumUrl = $1;
			my $imageName = $2;
			$resultdatarecordnum = defined($resultdata->{records}) ? scalar( @{ $resultdata->{records} } ) : 0;
			$logging =~ m/Gallery/&&$r->log->info("album: $albumUrl image $imageName record# $resultdatarecordnum");

			#$$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = 3; # according to our match; it is - isn't it ?!
			$$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = $albumXc->findvalue("./$dotmacns:viewIdentifier", $albumProps) || 3;
			if ($$resultdata{records}[$resultdatarecordnum]{viewIdentifier} eq 3) {
				$$resultdata{records}[$resultdatarecordnum]{type} = 'Photo';
				my $largeImagePath = $albumXc->findnodes("./$dotmacns:largeImagePath", $albumProps)->[0];
				if ($largeImagePath) {
					$$resultdata{records}[$resultdatarecordnum]{largeImagePath} = $largeImagePath->textContent();
				}
				$numPhotos++;
			}
			elsif ($$resultdata{records}[$resultdatarecordnum]{viewIdentifier} eq 4) {
				$$resultdata{records}[$resultdatarecordnum]{type} = 'Video';
				$$resultdata{records}[$resultdatarecordnum]{videoDuration} = $albumXc->findvalue("./$dotmacns:videoDuration", $albumProps);
				$$resultdata{records}[$resultdatarecordnum]{videoDuration} = $albumXc->findvalue("./$dotmacns:videoDuration", $albumProps);
				$$resultdata{records}[$resultdatarecordnum]{videoPath} = $albumXc->findvalue("./$dotmacns:moviePath", $albumProps);
				$$resultdata{records}[$resultdatarecordnum]{videoHeight} = $albumXc->findvalue("./$dotmacns:videoHeight", $albumProps);
				$$resultdata{records}[$resultdatarecordnum]{videoWidth} = $albumXc->findvalue("./$dotmacns:videoWidth", $albumProps);
				$$resultdata{records}[$resultdatarecordnum]{mimetype} = $albumXc->findvalue("./$dotmacns:mimetype", $albumProps);
				$numMovies++;
			}
			$$resultdata{records}[$resultdatarecordnum]{userHidden} = $albumXc->findvalue("./$dotmacns:userHidden", $albumProps) ? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{userItemGuid} = $albumXc->findvalue("./$dotmacns:useritemguid", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{webImagePath} = $albumXc->findvalue("./$dotmacns:webImagePath", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{sortOrder} = $resultdatarecordnum; # WTF ???
			$$resultdata{records}[$resultdatarecordnum]{fileExtension} = $albumXc->findvalue("./$dotmacns:fileExtension", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{webImageWidth} = $albumXc->findvalue("./$dotmacns:webImageWidth", $albumProps);
#TODO - find out where on earth we can find the real guid
# guid should be reproducable - it is _not_ specified in properties
			$$resultdata{records}[$resultdatarecordnum]{guid} = $albumXc->findvalue("./$dotmacns:useritemguid", $albumProps);
#TODO - change hardcoded url to $r->uri thingies					
			$$resultdata{records}[$resultdatarecordnum]{url} = "http://$hostname/$username/$albumUrl/$imageName";
			$$resultdata{records}[$resultdatarecordnum]{title} = $albumXc->findvalue("./$dotmacns:title", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{userOrderIndex} = $resultdatarecordnum; # "sortOrder" : 136,"userOrderIndex" : 136
			$$resultdata{records}[$resultdatarecordnum]{sortOrder} = $resultdatarecordnum; # "sortOrder" : 136,"userOrderIndex" : 136
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{content} = $albumXc->findvalue("./$iphotons:ContentVersion", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{props} = $albumXc->findvalue("./$iphotons:PropertiesVersion", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{content} = $albumXc->findvalue("./$dotmacns:content", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{modDate} = $albumXc->findvalue("./$dotmacns:modDate", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{updated} = $albumXc->findvalue("./$dotmacns:updated", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{webImageHeight} = $albumXc->findvalue("./$dotmacns:webImageHeight", $albumProps);
			
			$$resultdata{records}[$resultdatarecordnum]{photoDate} = $albumXc->findvalue("./$iphotons:photoDate", $albumProps);
			$$resultdata{records}[$resultdatarecordnum]{album} = $albumGuid;
			$$resultdata{records}[$resultdatarecordnum]{archiveDate} = $albumXc->findvalue("./$dotmacns:archiveDate", $albumProps);

			
			#$resultdatarecordnum++;
		}
		else {
			$logging =~ m/Gallery/&&$r->log->info("$albumHref is neither an album nor an image");
		}
	#return $resultdata;
	}
	$$resultdata{records}[$albumRecordNum]{numPhotos} = $numPhotos;
	$$resultdata{records}[$albumRecordNum]{numMovies} = $numMovies;
}

1;
