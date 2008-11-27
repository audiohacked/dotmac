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
#	You can provide your own mechanism to authenticate users, instead of the standard one. If you want to make Apache think that the user was authenticated by the standard mechanism, set the username with:
#  $r->connection->user('username');
#subrequest; my ($r, $method, $href, $xml, $headers) = @_;

##	ok here's the deal
## 	first do a propfind/depth 1 on _gallery for fetching:
##	'updated' 'title' and 'userorder' nodes for (json) 'data'
##	build a list of subdirs (albums) from _gallery - and loop over them propfind'ing (depth 1 ) for our 'records'

	my %resultdata = ( status => 1 ); # Warning: magic constant, no idea what it means...
	my $username;
	my $albumGuid;
	my %galleryData =();
#let's assume we call _gallery
	my $propfindResponse = DotMac::CommonCode::subrequest($r, 'PROPFIND', $r->uri, '<D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>', {'Depth'=> '1'});
	$logging =~ m/Sections/&&$r->log->info("truthgetHandler got response ". $propfindResponse->[0]); # 207 (multistatus)
	
	my $parser = XML::LibXML->new();
	my $data = $parser->parse_string($propfindResponse->[1]);
	my $xc = XML::LibXML::XPathContext->new($data);

	
	
	#my @responsenodes = $data->findnodes("//D:response");
	my @responsenodes = $data->findnodes("//*[contains(name(),'D:response')]");
	my $resultdatarecordnum = 0;
	
	foreach my $responsenode (@responsenodes) {
		my $href = $responsenode->findnodes('./D:href');
		$logging =~ m/SubreqDebug/&&$r->log->info("href: ########### $href ##########");
		my ($props) = $responsenode->findnodes('./D:propstat/D:prop');
		
		if ($href =~ m/Web\/Sites\/_gallery\/$/) {
			$logging =~ m/SubreqDebug/&&$r->log->info("wooH00 $href matches _gallery/");
			## fetch updated, title, and userOrder
			$resultdata{data}{updated} = $props->findvalue('./ns2:updated');
			$resultdata{data}{title} = $props->findvalue('./ns2:title');
			$resultdata{data}{userOrder} = $props->findvalue('./ns2:userorder');
		}
		elsif ($href =~ m/([a-zA-Z_0-9]+)\/Web\/Sites\/_gallery\/[0-9]+\/$/) { # !!! need to verify this match - it should match -only- the 1st level subdirs
			$username = $1;
			&truthgetAlbum ($r, $username, $href, \%resultdata);			
		}
	}
	
	
	$logging =~ m/SubreqDebug/&&$r->log->info("json: ".to_json(\%resultdata, {pretty => 1})."\n");
	
	
	
	#my $data = '{"records" : [{}],"data" : {},"status" : 1}';
	my $jsonData = to_json(\%resultdata, {pretty => 1});
	$logging =~ m/Sections/&&$r->log->info("truthgetHandler sent data $jsonData");
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
	
	my $albumRecordNum;
	my $numPhotos = 0;
	
	my $resultdatarecordnum;
	my $hostname = $r->hostname();
	my $propfindAlbumResponse = DotMac::CommonCode::subrequest($r, 'PROPFIND', $href, '<D:propfind xmlns:D="DAV:"><D:allprop/></D:propfind>', {'Depth'=> '1'});
	my $parser = XML::LibXML->new();
	my $albumData = $parser->parse_string($propfindAlbumResponse->[1]);
	my $albumXc = XML::LibXML::XPathContext->new($albumData);
	my @albumResponsenodes = $albumData->findnodes("//*[contains(name(),'D:response')]");
	foreach my $albumResponsenode (@albumResponsenodes) {
		my $albumHref = $albumResponsenode->findvalue('./D:href');
		my ($albumProps) = $albumResponsenode->findnodes('./D:propstat/D:prop');
		
		if ($albumHref =~ m/Web\/Sites\/_gallery\/([0-9]+)\/$/) { # !!! need to verify this match - this should be an album (and the same match as above)
			my $albumUrl = $1;
			$resultdatarecordnum = defined($resultdata->{records}) ? scalar( @{ $resultdata->{records} } ) : 0;
			$logging =~ m/SubreqDebug/&&$r->log->info("album: $albumUrl record# $resultdatarecordnum");
			$albumRecordNum = $resultdatarecordnum;
			$$resultdata{records}[$resultdatarecordnum]{type} = 'Album';
			$$resultdata{records}[$resultdatarecordnum]{sortOrder} = int($albumProps->findvalue('./ns1:sortOrder'));
			$$resultdata{records}[$resultdatarecordnum]{allowMobile} = $albumProps->findvalue('./ns3:allowMobile')? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{showMobile} = $albumProps->findvalue('./ns3:showMobile')? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{title} = $albumProps->findvalue('./ns3:title');
			$$resultdata{records}[$resultdatarecordnum]{keyImagePath} = "http://$hostname/$username/$albumUrl/" . $albumProps->findvalue('./ns3:keyImagePath');
			$$resultdata{records}[$resultdatarecordnum]{updated} = $albumProps->findvalue('./ns3:updated');
			$$resultdata{records}[$resultdatarecordnum]{download} = $albumProps->findvalue('./ns3:download')? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteFrameCount} = $albumProps->findvalue('./ns3:scrubSpriteFrameCount');

			my $userOrder = $albumProps->findvalue('./ns3:userorder');
			my @userOrderList = split(/,/, $userOrder);
			#$$resultdata{records}[$resultdatarecordnum]{numPhotos} = scalar(@userOrderList);

#TODO - change hardcoded url to $r->uri thingies					
			$$resultdata{records}[$resultdatarecordnum]{url} = "http://$hostname/$username/$albumUrl";
			$$resultdata{records}[$resultdatarecordnum]{addPhoto} = $albumProps->findvalue('./ns3:addPhoto')? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteFrameWidth} = int($albumProps->findvalue('./ns3:scrubSpriteFrameWidth'));
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteFrameHeight} = int($albumProps->findvalue('./ns3:scrubSpriteFrameHeight'));

#TODO - find out where on earth we can find the real guid
# guid should be reproducable - it is _not_ specified in properties
			$$resultdata{records}[$resultdatarecordnum]{guid} = $albumProps->findvalue('./ns3:useritemguid'); # GAH!!!!
#Could it get worse??? Yes it can!!! XML is not linearized - anyway:
$albumGuid = $albumProps->findvalue('./ns3:useritemguid'); # GAH!!!!

			#$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = $albumProps->findvalue('./ns3:viewIdentifier');
			$$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = 2; # is it ???
			$$resultdata{records}[$resultdatarecordnum]{path} = "http://$hostname/$username/$albumUrl"; # is it ???
			
			$$resultdata{records}[$resultdatarecordnum]{keyImageFileExtension} = 'jpg'; # is it ???
			#$resultdata{records}[$resultdatarecordnum]{scrubSpriteKeyFrameIndex} = $albumProps->findvalue('./ns3:scrubSpriteKeyFrameIndex');
			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteKeyFrameIndex} = 0; # is it ???
			#userOrder is a list of userItemGuids from subfolders (Photos)
			$$resultdata{records}[$resultdatarecordnum]{userOrder} = $userOrder;
			$$resultdata{records}[$resultdatarecordnum]{keyImageGuid} = uc($userOrderList[0]);

			$$resultdata{records}[$resultdatarecordnum]{scrubSpriteKeyFrameIndex} = $albumProps->findvalue('./ns1:keyImageGuid');
			$$resultdata{records}[$resultdatarecordnum]{albumWidget} = $albumProps->findvalue('./ns3:albumWidget')? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{showCaptions} = int($albumProps->findvalue('./ns3:showCaptions'));
			$$resultdata{records}[$resultdatarecordnum]{scrubSpritePath} = $albumProps->findvalue('./ns3:scrubSpritePath');
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{content} = 8;# WTF ???
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{props} = 3; # WTF ???
			$$resultdata{records}[$resultdatarecordnum]{numMovies} = 0; # WTF ???
			$$resultdata{records}[$resultdatarecordnum]{spriteGuids} = $albumProps->findvalue('./ns3:spriteGuids');
			$$resultdata{records}[$resultdatarecordnum]{userItemGuid} = $albumProps->findvalue('./ns3:useritemguid');
#TODO - we should prolly set a counter on (both) albums and album images.
			$$resultdata{records}[$resultdatarecordnum]{userOrderIndex} = 0;
			
			$$resultdata{records}[$resultdatarecordnum]{userHidden} = $albumProps->findvalue('./ns3:userHidden')? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{accessLogin} = $albumProps->findvalue('./ns3:accessLogin');

			#gah! http://gallery.mac.com/$username/$albumUrl/
			$$resultdata{records}[$resultdatarecordnum]{title} = $albumProps->findvalue('./ns3:title');
			
			
			$$resultdata{records}[$resultdatarecordnum]{scrubSpritePath} = $albumProps->findvalue('./ns3:scrubSpritePath');
			#$resultdatarecordnum++;
		}
		elsif ($albumHref =~ m/Web\/Sites\/_gallery\/([0-9]+)\/([a-zA-Z\-_0-9]+)\/$/) { # !!! need to verify this match - this should be an Photo (and the same match as above)
			my $albumUrl = $1;
			my $imageName = $2;
			$resultdatarecordnum = defined($resultdata->{records}) ? scalar( @{ $resultdata->{records} } ) : 0;
			$logging =~ m/SubreqDebug/&&$r->log->info("album: $albumUrl image $imageName record# $resultdatarecordnum");
			$numPhotos++;
			$$resultdata{records}[$resultdatarecordnum]{userHidden} = $albumProps->findvalue('./ns3:userHidden')? 'true' : 'false';
			$$resultdata{records}[$resultdatarecordnum]{userItemGuid} = $albumProps->findvalue('./ns3:useritemguid');
			$$resultdata{records}[$resultdatarecordnum]{webImagePath} = $albumProps->findvalue('./ns3:webImagePath');
			$$resultdata{records}[$resultdatarecordnum]{sortOrder} = $resultdatarecordnum; # WTF ???
			$$resultdata{records}[$resultdatarecordnum]{fileExtension} = $albumProps->findvalue('./ns3:fileExtension');
			$$resultdata{records}[$resultdatarecordnum]{webImageWidth} = $albumProps->findvalue('./ns3:webImageWidth');
			$$resultdata{records}[$resultdatarecordnum]{viewIdentifier} = 3; # WTF ???
#TODO - find out where on earth we can find the real guid
# guid should be reproducable - it is _not_ specified in properties
			$$resultdata{records}[$resultdatarecordnum]{guid} = $albumProps->findvalue('./ns3:useritemguid');
			$$resultdata{records}[$resultdatarecordnum]{type} = 'Photo';
#TODO - change hardcoded url to $r->uri thingies					
			$$resultdata{records}[$resultdatarecordnum]{url} = "http://$hostname/$username/$albumUrl/$imageName";
			$$resultdata{records}[$resultdatarecordnum]{title} = $albumProps->findvalue('./ns3:title');
			$$resultdata{records}[$resultdatarecordnum]{userOrderIndex} = $resultdatarecordnum; # "sortOrder" : 136,"userOrderIndex" : 136
			$$resultdata{records}[$resultdatarecordnum]{sortOrder} = $resultdatarecordnum; # "sortOrder" : 136,"userOrderIndex" : 136
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{content} = $albumProps->findvalue('./ns1:ContentVersion');
			$$resultdata{records}[$resultdatarecordnum]{versionInfo}{props} = $albumProps->findvalue('./ns1:PropertiesVersion');
			$$resultdata{records}[$resultdatarecordnum]{content} = $albumProps->findvalue('./ns3:content');
			$$resultdata{records}[$resultdatarecordnum]{modDate} = $albumProps->findvalue('./ns3:modDate');
			$$resultdata{records}[$resultdatarecordnum]{updated} = $albumProps->findvalue('./ns3:updated');
			$$resultdata{records}[$resultdatarecordnum]{webImageHeight} = $albumProps->findvalue('./ns3:webImageHeight');
			$$resultdata{records}[$resultdatarecordnum]{largeImagePath} = $albumProps->findvalue('./ns3:largeImagePath');
			$$resultdata{records}[$resultdatarecordnum]{photoDate} = $albumProps->findvalue('./ns1:photoDate');
			$$resultdata{records}[$resultdatarecordnum]{album} = $albumGuid;
			$$resultdata{records}[$resultdatarecordnum]{archiveDate} = $albumProps->findvalue('./ns3:archiveDate');

			
			#$resultdatarecordnum++;
		}
		else {
			$logging =~ m/SubreqDebug/&&$r->log->info("$albumHref is neither an album nor an image");
		}
	#return $resultdata;
	}
	$$resultdata{records}[$albumRecordNum]{numPhotos} = $numPhotos;
}

1;
