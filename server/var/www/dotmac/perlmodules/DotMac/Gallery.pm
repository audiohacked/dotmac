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
		my $href = $xc->findnodes("./$DAVns:href", $responsenode)->[0]->textContent();
		$logging =~ m/Gallery/&&$r->log->info("href: ########### $href ##########");
		my $prop = $xc->findnodes("./$DAVns:propstat/$DAVns:prop", $responsenode)->[0];
		
		if ($href =~ m/Web\/Sites\/_gallery\/$/) {
			$logging =~ m/Gallery/&&$r->log->info("wooH00 $href matches _gallery/");
			## fetch updated, title, and userOrder
			$resultdata{data}{updated} = $xc->findnodes("./$dotmacns:updated", $prop)->[0]->textContent();
			$resultdata{data}{title} = $xc->findnodes("./$dotmacns:title", $prop)->[0]->textContent();
			$resultdata{data}{userOrder} = $xc->findnodes("./$dotmacns:userorder", $prop)->[0]->textContent();
		}
		elsif ($href =~ m/([a-zA-Z_0-9]+)\/Web\/Sites\/_gallery\/[0-9]+\/$/) { # !!! need to verify this match - it should match -only- the 1st level subdirs
			$username = $1;
			&truthgetAlbum ($r, $username, $href, \%resultdata);			
		}
	}
	
	
	$logging =~ m/Gallery/&&$r->log->info("json: ".to_json(\%resultdata, {pretty => 1, utf8 => 1})."\n");
	
	
	
	#my $data = '{"records" : [{}],"data" : {},"status" : 1}';
	my $jsonData = to_json(\%resultdata, {pretty => 1, utf8 => 1});
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
	
	$r->content_encoding("gzip");
	my $gzjsonData = Compress::Zlib::memGzip($jsonData); 
	$r->header_out('Content-Length', length( $gzjsonData ));
	$r->print( $gzjsonData );
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
		my $albumHref = $albumXc->findnodes("./$DAVns:href", $albumResponsenode)->[0]->textContent();
		$logging =~ m/Gallery/&&$r->log->info("href: ########### $href ##########");
		my $albumProps = $albumXc->findnodes("./$DAVns:propstat/$DAVns:prop", $albumResponsenode)->[0];
		if ($albumHref =~ m/Web\/Sites\/_gallery\/([0-9]+)\/$/) { # !!! need to verify this match - this should be an album (and the same match as above)
			my $albumUrl = $1;
			$resultdatarecordnum = defined($resultdata->{records}) ? scalar( @{ $resultdata->{records} } ) : 0;
			$logging =~ m/Gallery/&&$r->log->info("album: $albumUrl record# $resultdatarecordnum");
			$albumRecordNum = $resultdatarecordnum;
			$$resultdata{records}[$resultdatarecordnum]{type} = 'Album';
			$$resultdata{records}[$resultdatarecordnum]{sortOrder} = int($albumXc->findnodes("./$iphotons:sortOrder", $albumProps)->[0]->textContent());
			$$resultdata{records}[$resultdatarecordnum]{allowMobile} = $albumXc->findnodes("./$dotmacns:allowMobile", $albumProps)->[0]->textContent()? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{showMobile} = $albumXc->findnodes("./$dotmacns:showMobile", $albumProps)->[0]->textContent()? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{title} = $albumXc->findnodes("./$dotmacns:title", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{keyImagePath} = "http://$hostname/$username/$albumUrl/" . $albumXc->findnodes("./$dotmacns:keyImagePath", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{updated} = $albumXc->findnodes("./$dotmacns:updated", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{download} = $albumXc->findnodes("./$dotmacns:download", $albumProps)->[0]->textContent()? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteFrameCount} = $albumXc->findnodes("./$dotmacns:scrubSpriteFrameCount", $albumProps)->[0]->textContent();

			my $userOrder = $albumXc->findnodes("./$dotmacns:userorder", $albumProps)->[0]->textContent();
			my @userOrderList = split(/,/, $userOrder);
			#$$resultdata{records}[$resultdatarecordnum]{numPhotos} = scalar(@userOrderList);

#TODO - change hardcoded url to $r->uri thingies					
			$$resultdata{records}[$resultdatarecordnum]{url} = "http://$hostname/$username/$albumUrl";
			$$resultdata{records}[$resultdatarecordnum]{addPhoto} = $albumXc->findnodes("./$dotmacns:addPhoto", $albumProps)->[0]->textContent()? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteFrameWidth} = int($albumXc->findnodes("./$dotmacns:scrubSpriteFrameWidth", $albumProps)->[0]->textContent());
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteFrameHeight} = int($albumXc->findnodes("./$dotmacns:scrubSpriteFrameHeight", $albumProps)->[0]->textContent());

#TODO - find out where on earth we can find the real guid
# guid should be reproducable - it is _not_ specified in properties
			$$resultdata{records}[$resultdatarecordnum]{guid} = $albumXc->findnodes("./$dotmacns:useritemguid", $albumProps)->[0]->textContent(); # GAH!!!!
#Could it get worse??? Yes it can!!! XML is not linearized - anyway:
$albumGuid = $albumXc->findnodes("./$dotmacns:useritemguid", $albumProps)->[0]->textContent(); # GAH!!!!

			#$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = $albumProps->findnodes('./ns3:viewIdentifier');
			$$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = 2; # is it ???
			$$resultdata{records}[$resultdatarecordnum]{path} = "http://$hostname/$username/$albumUrl"; # is it ???
			
			$$resultdata{records}[$resultdatarecordnum]{keyImageFileExtension} = 'jpg'; # is it ???
			#$resultdata{records}[$resultdatarecordnum]{scrubSpriteKeyFrameIndex} = $albumProps->findnodes('./ns3:scrubSpriteKeyFrameIndex');
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteKeyFrameIndex} = 0; # is it ???
			#userOrder is a list of userItemGuids from subfolders (Photos)
			$$resultdata{records}[$resultdatarecordnum]{userOrder} = $userOrder;
			$$resultdata{records}[$resultdatarecordnum]{keyImageGuid} = uc($userOrderList[0]);

			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteKeyFrameIndex} = $albumXc->findnodes("./$iphotons:keyImageGuid", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{albumWidget} = $albumXc->findnodes("./$dotmacns:albumWidget", $albumProps)->[0]->textContent()? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{showCaptions} = int($albumXc->findnodes("./$dotmacns:showCaptions", $albumProps)->[0]->textContent());
			$$resultdata{records}[$resultdatarecordnum]{scrubSpritePath} = $albumXc->findnodes("./$dotmacns:scrubSpritePath", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{content} = 8;# WTF ???
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{props} = 3; # WTF ???
			$$resultdata{records}[$resultdatarecordnum]{numMovies} = 0; # WTF ???
			$$resultdata{records}[$resultdatarecordnum]{spriteGuids} = $albumXc->findnodes("./$dotmacns:spriteGuids", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{userItemGuid} = $albumXc->findnodes("./$dotmacns:useritemguid", $albumProps)->[0]->textContent();
#TODO - we should prolly set a counter on (both) albums and album images.
			$$resultdata{records}[$resultdatarecordnum]{userOrderIndex} = 0;
			
			$$resultdata{records}[$resultdatarecordnum]{userHidden} = $albumXc->findnodes("./$dotmacns:userHidden", $albumProps)->[0]->textContent()? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{accessLogin} = $albumXc->findnodes("./$dotmacns:accessLogin", $albumProps)->[0]->textContent();

			#gah! http://gallery.mac.com/$username/$albumUrl/
			$$resultdata{records}[$resultdatarecordnum]{title} = $albumXc->findnodes("./$dotmacns:title", $albumProps)->[0]->textContent();
			
			
			$$resultdata{records}[$resultdatarecordnum]{scrubSpritePath} = $albumXc->findnodes("./$dotmacns:scrubSpritePath", $albumProps)->[0]->textContent();
			$logging =~ m/Gallery/&&$r->log->info("album: done");
		}
		elsif ($albumHref =~ m/Web\/Sites\/_gallery\/([0-9]+)\/([a-zA-Z\-_0-9]+)\/$/) { # !!! need to verify this match - this should be an Photo (and the same match as above)
			my $albumUrl = $1;
			my $imageName = $2;
			$resultdatarecordnum = defined($resultdata->{records}) ? scalar( @{ $resultdata->{records} } ) : 0;
			$logging =~ m/Gallery/&&$r->log->info("album: $albumUrl image $imageName record# $resultdatarecordnum");
			$numPhotos++;
			$$resultdata{records}[$resultdatarecordnum]{userHidden} = $albumXc->findnodes("./$dotmacns:userHidden", $albumProps)->[0]->textContent()? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{userItemGuid} = $albumXc->findnodes("./$dotmacns:useritemguid", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{webImagePath} = $albumXc->findnodes("./$dotmacns:webImagePath", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{sortOrder} = $resultdatarecordnum; # WTF ???
			$$resultdata{records}[$resultdatarecordnum]{fileExtension} = $albumXc->findnodes("./$dotmacns:fileExtension", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{webImageWidth} = $albumXc->findnodes("./$dotmacns:webImageWidth", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = 3; # WTF ???
#TODO - find out where on earth we can find the real guid
# guid should be reproducable - it is _not_ specified in properties
			$$resultdata{records}[$resultdatarecordnum]{guid} = $albumXc->findnodes("./$dotmacns:useritemguid", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{type} = 'Photo';
#TODO - change hardcoded url to $r->uri thingies					
			$$resultdata{records}[$resultdatarecordnum]{url} = "http://$hostname/$username/$albumUrl/$imageName";
			$$resultdata{records}[$resultdatarecordnum]{title} = $albumXc->findnodes("./$dotmacns:title", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{userOrderIndex} = $resultdatarecordnum; # "sortOrder" : 136,"userOrderIndex" : 136
			$$resultdata{records}[$resultdatarecordnum]{sortOrder} = $resultdatarecordnum; # "sortOrder" : 136,"userOrderIndex" : 136
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{content} = $albumXc->findnodes("./$iphotons:ContentVersion", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{props} = $albumXc->findnodes("./$iphotons:PropertiesVersion", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{content} = $albumXc->findnodes("./$dotmacns:content", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{modDate} = $albumXc->findnodes("./$dotmacns:modDate", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{updated} = $albumXc->findnodes("./$dotmacns:updated", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{webImageHeight} = $albumXc->findnodes("./$dotmacns:webImageHeight", $albumProps)->[0]->textContent();
			my $largeImagePath = $albumXc->findnodes("./$dotmacns:largeImagePath", $albumProps)->[0];
			if (defined($largeImagePath)) {
				$$resultdata{records}[$resultdatarecordnum]{largeImagePath} = $largeImagePath->textContent();
			}
			$$resultdata{records}[$resultdatarecordnum]{photoDate} = $albumXc->findnodes("./$iphotons:photoDate", $albumProps)->[0]->textContent();
			$$resultdata{records}[$resultdatarecordnum]{album} = $albumGuid;
			$$resultdata{records}[$resultdatarecordnum]{archiveDate} = $albumXc->findnodes("./$dotmacns:archiveDate", $albumProps)->[0]->textContent();

			
			#$resultdatarecordnum++;
		}
		else {
			$logging =~ m/Gallery/&&$r->log->info("$albumHref is neither an album nor an image");
		}
	#return $resultdata;
	}
	$$resultdata{records}[$albumRecordNum]{numPhotos} = $numPhotos;
}

1;
