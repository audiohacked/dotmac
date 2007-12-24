package DotMac::DMTransHandler;

use strict;
use warnings;

use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::Log;

use Apache2::Const -compile => qw(DECLINED);
use APR::Const    -compile => qw(:error SUCCESS);
use CGI::Carp;
use DotMac::CommonCode;


sub handler
	{
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	
	if (($r->method() eq "POST") && ($r->headers_in->{'X-Webdav-Method'}) && ($r->headers_in->{'X-Webdav-Method'} eq "DMPUTFROM")){
			$logging =~ m/Sections/&&$rlog->info("In the DMPUTFROM to MOVE TransHandler");
			my $httpType="http://";
			$httpType="https://" if $r->get_server_port() == 443;
			$logging =~ m/Sections/&&$rlog->info($httpType.$r->headers_in->{'Host'}.$r->uri." ".$r->headers_in->{'X-Source-Href'});
			$r->headers_in->{'Destination'}=$httpType.$r->headers_in->{'Host'}.$r->uri;
			$r->uri(DotMac::CommonCode::URLDecode($r->headers_in->{'X-Source-Href'}));
			#$r->header_in->{'uri'}=$r->header_in->{'X-Source-Href'};
			$r->method("MOVE");
		#	$logging =~ m/Sections/&&$rlog->info($r->as_string());
			}
			
			return Apache2::Const::DECLINED;
		}

1;