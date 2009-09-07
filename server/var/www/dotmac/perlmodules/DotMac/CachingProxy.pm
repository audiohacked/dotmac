## Copyright (C) 2008 walinsky
### This file is part of dotMac.
#
### dotMac is free software: you can redistribute it and/or modify
### it under the terms of the Affero GNU General Public License as published by
### the Free Software Foundation, either version 3 of the License, or
### (at your option) any later version.
#
### dotMac is distributed in the hope that it will be useful,
### but WITHOUT ANY WARRANTY; without even the implied warranty of
### MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### Affero GNU General Public License for more details.
#
### You should have received a copy of the Affero GNU General Public License
### along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
#
#
package DotMac::CachingProxy;
 # file: DotMac/CachingProxy.pm
 
use strict;
use vars qw(@ISA $VERSION);
use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Const -compile => qw(OK);

use LWP::UserAgent ();
# use LWP::Debug qw(+);

use CGI::Carp;

@ISA = qw(LWP::UserAgent);
$VERSION = '1.00';

my $UA = __PACKAGE__->new;
$UA->agent(join "/", __PACKAGE__, $VERSION);


sub download {
	my $r = shift;
	my $uri=$r->uri;
	my $httpType="http://";
	$httpType="https://" if $r->get_server_port() == 443;
	my $uri = escape_input($httpType.$r->get_server_name.$r->uri);
	my $filepath=$r->dir_config('dotMacCachePath');
	#### This is a really potentially bad way to do things
	$r->log->info("CACHE: Downloading $uri ");
	`wget -P $filepath -nH -x $uri`;
	return Apache2::Const::OK;
}
## I think this will mitigate some of my concerns. I'd still someone else to verify this will take care of all security
## concerns before we recommend using it in production
sub escape_input {
  my ($str) = @_; 
	$str =~ s/([;<>\*\|`&\$!#\(\)\[\]\{\}:'"])/\\$1/g;
  return $str;
}


sub handler {
	my $r = shift;
	my $httpType="http://";
	$httpType="https://" if $r->get_server_port() == 443;
	my $uri = join '', $httpType, $r->get_server_name, $r->uri;
	
	my $query = $r->args() || '';
	$uri .= "?$query" if defined $query and length $query;
	my $request = new HTTP::Request($r->method, $uri);
	my(%headers) = $r->headers_in;
	for (keys(%headers)) {
		$request->header($_, $headers{$_});
	}
	
	# copy POST data, if any
	if($r->method eq 'POST') {
		my $len = $r->header_in('Content-length');
		my $buf;
		$r->read($buf, $len);
		$request->content($buf);
		$request->content_type($r->content_type);
	}
	my $res = (new LWP::UserAgent)->request($request);
#	warn $uri;
#	warn $headers->as_string;

	#feed reponse back into our request_rec*
	$r->status($res->code);
	$r->status_line(join " ", $res->code, $res->message);
	# we'll want to loop over these to retrieve our Content-type
	# Apple sends these twice, which barfs our proxy. Yea, really!
	$res->headers->scan(sub {
		$r->header_out($_[0],$_[1]);
		if ($_[0] eq 'Content-Type')
			{
			$r->content_type($_[1]);
			}
	});
#	warn $r->content_type();
	
	if ($r->header_only) {
		$r->send_http_header();
		return Apache2::Const::OK;
	}
	
	$r->send_http_header();
	print $res->content;
	return Apache2::Const::OK;
}

1;
