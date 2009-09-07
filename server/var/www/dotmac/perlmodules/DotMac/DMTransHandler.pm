package DotMac::DMTransHandler;

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
use Apache2::Log;
use Apache2::URI ();

use Apache2::Const -compile => qw(:methods DECLINED);
use APR::Const    -compile => qw(:error SUCCESS);
use CGI::Carp;
use DotMac::CommonCode;
use DotMac::DMXWebdavMethods;


sub handler
	{
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	
	if ($r->method() eq "OPTIONS") {
		### This was added for 10.6 because when you try to open your iDisk it makes an OPTIONS request for /$username.
		### Apache sends back a 302 redirect to /$username/
		### WebDAVLib doesn't update the authentication header. so the URI still says /$username. 
		### Apache barfs on ths with:
		### Digest: uri mismatch - </$username> does not match request-uri </$username/> and retuns a 400 Bad Request
		$logging =~ m/Sections/&&$rlog->info("Special OPTIONS handler");
		$r->handler('perl-script');
		$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::options);
		return Apache2::Const::OK;
	} elsif (($r->method() eq "POST") && ($r->headers_in->{'X-Webdav-Method'}) && ($r->headers_in->{'X-Webdav-Method'} eq "DMPUTFROM")){
			$logging =~ m/Sections/&&$rlog->info("In the DMPUTFROM to MOVE TransHandler");
			my $httpType="http://";
			$httpType="https://" if $r->get_server_port() == 443;
			$logging =~ m/Sections/&&$rlog->info($httpType.$r->headers_in->{'Host'}.$r->uri." ".$r->headers_in->{'X-Source-Href'});
			$r->headers_in->{'Destination'}=$r->construct_url($r->uri);
			$logging =~ m/TransHandler/&&$r->log->info("New Source: ".DotMac::CommonCode::URLDecode($r->headers_in->{'X-Source-Href'})); 
			$logging =~ m/TransHandler/&&$r->log->info("New Dest: ".$r->construct_url($r->uri)); 
			$r->uri(DotMac::CommonCode::URLDecode($r->headers_in->{'X-Source-Href'}));
			#$r->header_in->{'uri'}=$r->header_in->{'X-Source-Href'};
			$r->method('MOVE');
			$r->method_number(Apache2::Const::M_MOVE);
			$logging =~ m/Sections/&&$rlog->info($r->as_string());
			return Apache2::Const::DECLINED;
			}
	
	
			return Apache2::Const::DECLINED;
	}

1;
