#file:DotMac/GalleryTransHandler.pm;
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

package DotMac::GalleryTransHandler;

use strict;
use warnings;

use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(:methods DECLINED);

use DotMac::Gallery;
use DotMac::GalleryImager;
use DotMac::CachingProxy;
use DotMac::DMXWebdavMethods;
use DotMac::NullStorageHandler;
use DotMac::WebObjects::Comments::wa;

$DotMac::GalleryTransHandler::VERSION = '0.1';

sub handler {
    my $r = shift;
	my $rlog = $r->log;   
 	my $logging = $r->dir_config('LoggingTypes');
	my $method = $r->method;
    if (($r->method eq 'GET') || ($r->method eq 'POST')) {
    	
    	##first let's see if we're hitting a cached dir
		foreach my $dotMacCachedDir ($r->dir_config->get('dotMacCachedDirs')) {
			if($r->uri =~m{^/$dotMacCachedDir/})  {
				##it IS a cached dir
				$r->document_root($r->dir_config->get('dotMacCachePath'));
				if (-f $r->document_root.$r->uri) {
					$logging =~ m/Gallery/&&$rlog->info($r->document_root . $r->uri . ": matched cache dir $dotMacCachedDir");
					$r->filename($r->document_root.$r->uri); # we have no further trans handlers - we need to set $r->filename ourselves
					return Apache2::Const::OK; # signal that the *Uri Translation Phase* is done and no further handlers are called in this phase.
				#} elsif ($r->dir_config('dotMacDownloadAppleResources') eq "YES") {
				} else {
					$r->set_handlers(PerlMapToStorageHandler => \&DotMac::NullStorageHandler::handler);    	
					$r->hostname('gallery.mac.com'); ### if we don't do this - we'll keep calling ourselves - and lock up our server!!!
					$r->filename($r->document_root.$r->uri);
					$r->handler('perl-script');
					$r->set_handlers(PerlResponseHandler => \&DotMac::CachingProxy::handler);
					return Apache2::Const::OK; # signal that the *Uri Translation Phase* is done and no further handlers are called in this phase.
				}
			}
		}
		##it's not a cached dir
		##let's see if we're hitting /WebObjects/
		if($r->uri =~m{^/WebObjects/Comments.woa/wa/}) {
			$logging =~ m/Gallery/&&$rlog->info($r->document_root . $r->uri . ": matched WebObjects");
			##WebObjects should be handled correctly from our apache conf; bail out
			$r->set_handlers(PerlMapToStorageHandler => \&DotMac::NullStorageHandler::handler);  
			$r->filename($r->document_root.$r->uri); # we have no further trans handlers - we need to set $r->filename ourselves
			$r->set_handlers(PerlResponseHandler => \&DotMac::WebObjects::Comments::wa::handler);
			return Apache2::Const::OK;
		}
		
		##not /WebObjects either
		##initiate our transhandler
		return TransHandler($r);
	}
	else {
		return Apache2::Const::DECLINED;
	}
}

sub TransHandler {
    my $r = shift;
    
    my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
    
    # warn $r->hostname;

    my $uri = $r->uri;
    my @dotMacUsers = $r->dir_config->get('dotMacUsers');
    my $found = 0;

	my $webdavMethod;
	my $derivative;
	my %params;
	$logging =~ m/Gallery/&&$rlog->info("GTH: my URI = $uri");
	#Allow robots to be used
	if ($r->args()) {
		my @args = split '&', $r->args();
		foreach my $a (@args) {
			(my $att,my $val) = split '=', $a;
			$params{$att} = $val ;
		}
		if ($params{'webdav-method'}) {
			$webdavMethod = $params{'webdav-method'};
			my $XGalleryView  = $r->headers_in->{'X-Gallery-View'} || '';
			my $XRequestedWith  = $r->headers_in->{'X-Requested-With'} || '';
			my $XPrototypeVersion = $r->headers_in->{'X-Prototype-Version'} || '';
		}
		if ($params{'derivative'}) {
			#derivative=square derivative=medium
			$derivative = $params{'derivative'};
		}
	}
				
	foreach my $username (@dotMacUsers) {
		$logging =~ m/Gallery/&&$rlog->info("matching $username against $uri");
		my $initialUri = $r->uri;
		if($uri =~m{^/$username(.*)})  {
			#fix uris that start with $username
			if ($1 !~m{^/Web/Sites/_gallery}) {
				$uri = "/$username/Web/Sites/_gallery$1";
				$r->uri($uri);
				$logging =~ m/Gallery/&&$rlog->info("Modified URI $uri");
			}
			if (-d $r->document_root.$r->uri) { # we set our perlhandler on directories - files will be served by Apache
				# add a trailing slash if its not on there
				if (!($r->uri=~ m,/$,)) {
					$r->uri($r->uri . "/");
					$r->header_out('Content-Location',"$initialUri/");
				}
				if ($webdavMethod) {    
					if (uc($webdavMethod) eq 'TRUTHGET') {
						$logging =~ m/Gallery/&&$rlog->info("setting handler DotMac::Gallery::truthgetHandler");
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::Gallery::truthgetHandler);
					}
					elsif (uc($webdavMethod) eq 'ZIPLIST') {
						$logging =~ m/Gallery/&&$rlog->info("setting handler DotMac::Gallery::ziplistHandler");
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::Gallery::ziplistHandler);
					}
					else {
						$logging =~ m/Gallery/&&$rlog->info("no handler defined for webdavmethod: $webdavMethod");
					}
				}
				else {
					$logging =~ m/Gallery/&&$rlog->info($r->uri . ": setting handler DotMac::Gallery::handler");
					$r->handler('perl-script');
					$r->set_handlers(PerlResponseHandler => \&DotMac::Gallery::handler);
				}
				$r->filename($r->uri); # we have no further trans handlers - we need to set $r->filename ourselves
				return Apache2::Const::OK; # signal that the *Uri Translation Phase* is done and no further handlers are called in this phase.
			}
			elsif (-f $r->document_root.$r->uri) { # we set our perlhandler on directories - files will be served by Apache
				return Apache2::Const::DECLINED; # signal that the *Uri Translation Phase* is done and let Apache handle things
			}
			elsif ($webdavMethod) { # it's not a directory nor a file but webdavmethod is called
				if (uc($webdavMethod) eq 'ZIPGET') {
					$logging =~ m/Gallery/&&$rlog->info("setting handler DotMac::Gallery::zipgetHandler");
					$r->notes->set(webdavmethod => $params{'webdav-method'} || '');
					$r->notes->set(token => $params{'token'} || '');
					$r->notes->set(disposition => $params{'disposition'} || '');
					$r->handler('perl-script');
					$r->set_handlers(PerlResponseHandler => \&DotMac::Gallery::zipgetHandler);
					$r->filename($r->uri); # we have no further trans handlers - we need to set $r->filename ourselves
					return Apache2::Const::OK; # signal that the *Uri Translation Phase* is done and no further handlers are called in this phase.
				}
			}
			elsif ($derivative) {
			#http://gallery.walinsky.com/xhr/emily_parker/100002/IMG_2561.json?derivative=exif&source=web.jpg&type=exif
			#http://gallery.walinsky.com/walinsky/100018/IMG_0900.jpg?derivative=square&source=web.jpg&type=square&ver=12105948110001
			#http://gallery.walinsky.com/walinsky/100010/IMG_2682.jpg?derivative=medium&source=web.jpg&type=medium&ver=12096002830001
				#$uri =~ s/.jpg/\/$params{'type'}.jpg/s;
				if ($derivative eq 'exif') {
					$uri =~ s/.json//s;
					$r->filename($r->document_root."$uri/$derivative.json");
				}
				elsif (($derivative eq 'square') || ($derivative eq 'medium')) {
					$uri =~ s/.jpg//s;
					$r->filename($r->document_root."$uri/$derivative.jpg");
				}
				elsif ($derivative eq 'large') {
					$uri =~ s/.jpg//s;
					$r->filename($r->document_root."$uri/$derivative.jpg");
				}
				if (-f $r->filename) {
					$logging =~ m/Gallery/&&$rlog->info($r->filename . "exists - bailing out");
					$r->uri("$uri/$derivative.jpg");
					if ($derivative eq 'large') {
						$uri =~ s/.jpg//s;
						$r->filename($r->document_root."$uri/$derivative.jpg");
						$r->header_out("Content-disposition" => "attachment");
					}
					return Apache2::Const::OK; # signal that the *Uri Translation Phase* is done and let Apache handle things
				}
				else {
					$logging =~ m/Gallery/&&$rlog->info($uri . ": $derivative setting handler DotMac::GalleryImager::handler");
					$r->uri($uri);
					$r->notes->set(derivative => $params{'derivative'});
					$r->notes->set(source => $params{'source'});#source=web.jpg
					$r->notes->set(type => $params{'type'});#type=square type=medium
					$r->notes->set(ver => $params{'ver'});#ver=12096002850002
					$r->handler('perl-script');
					$r->set_handlers(PerlResponseHandler => \&DotMac::GalleryImager::handler);
					return Apache2::Const::OK; # signal that the *Uri Translation Phase* is done and no further handlers are called in this phase.
				}
			}
		}
		elsif ($uri =~m{^/xhr/$username(.*)})  {
			if ($1 !~m{^/Web/Sites/_gallery}) {
				$uri = "/$username/Web/Sites/_gallery$1";
				$r->uri($uri);
			}
			$r->filename($r->document_root.$r->uri); # we have no further trans handlers - we need to set $r->filename ourselves
			$logging =~ m/Gallery/&&$rlog->info("$uri: setting handler DotMac::Gallery::truthgetHandler for user $username");
			$r->handler('perl-script');
			$r->set_handlers(PerlResponseHandler => \&DotMac::Gallery::truthgetHandler);
			return Apache2::Const::OK; # signal that the *Uri Translation Phase* is done and no further handlers are called in this phase.
		}
	} 
	if ($r->uri()  eq "/") {
		$r->uri("/index.html");
	}
	

			$logging =~ m/Gallery/&&$rlog->info("gth $uri");
			my $fullpath=$r->document_root.$r->uri;
			$logging =~ m/Gallery/&&$rlog->info("gth $fullpath");
			if (-f $fullpath) {
				
				$logging =~ m/Gallery/&&$rlog->info("GTH: mapping default url to $fullpath");
				$r->filename($fullpath);
				return Apache2::Const::OK;
			}
	
# actually we should check if we're called by hostname 'gallery.mac.com'
# if not - we should prolly just throw a 404 (we don't want to be anyone's proxy)
    	# set up a proxy to apple servers
       $r->set_handlers(PerlMapToStorageHandler => \&DotMac::NullStorageHandler::handler);    	
    	$r->hostname('gallery.mac.com'); ### if we don't do this - we'll keep calling ourselves - and lock up our server!!!
# we should first set up pnotes
# we can have the CachingProxy really cache things, when we tell it what to
    if ($r->dir_config('dotMacGalleryProxy') eq "TRUE") {
		$r->handler('perl-script');
		$r->set_handlers(PerlResponseHandler => \&DotMac::CachingProxy::handler);
	}

    return Apache2::Const::OK; # signal that the *Uri Translation Phase* is done and no further handlers are called in this phase.
}
1;
