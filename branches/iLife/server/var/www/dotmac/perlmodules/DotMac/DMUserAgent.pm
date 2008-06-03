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
package DotMac::DMUserAgent;
 # file: DotMac/UserAgentDM.pm
 
use strict;
use vars qw(@ISA $VERSION);
use Apache::Constants qw(:common);
use LWP::UserAgent ();
use DotMac::DotMacDB;
# use DotMac::Authen::Digest;

@ISA = qw(LWP::UserAgent);
$VERSION = '1.00';

my $UA = __PACKAGE__->new;
# $UA->agent(join "/", __PACKAGE__, $VERSION);
$UA->agent(join "/", 'DotMacKit', __PACKAGE__);
#globalize these variables here - they'll be filled in upon a ->new request
my $username;
my $realm;
my $uNameRealmPwHash;

sub handler {
	my ($r, $rMethod, $href, $newXMLstring, $headers) = @_;
	my $logging = $r->dir_config('LoggingTypes');
	$username = $r->user();
	$realm  = $r->dir_config('dotMacRealm');
	my $dotMacIPAddress = $r->dir_config('dotMacIPAddress');
	my $dbauth = DotMac::DotMacDB->new();
	$uNameRealmPwHash = $dbauth->fetch_apache_auth($username, $realm);
	$logging =~ m/Sections/&&$r->log->info("Request href: $href method: $rMethod if headers: ".$r->headers_in->{'If'});
	#set _all_ headers here!!!
	#fetch 'our' server ip-address here from $r->dir_config
	my $httpType="http://";
	$httpType="https://" if $r->get_server_port() == 443;
	my $host = $r->headers_in->{'Host'};
	$href = $httpType.$dotMacIPAddress.$href;
	my $request = HTTP::Request->new($rMethod, $href);
	if ($newXMLstring) {
		$request->header( 'Content-Length' => length($newXMLstring) );
		$request->content($newXMLstring);
		$logging =~ m/Sections/&&$r->log->info("content: $newXMLstring");
		}
	$request->header( 'Host' => $host );
	$request->header( 'Content-Type' => 'text/xml' );
	$request->header( 'If' => $r->headers_in->{'If'} );
	if ($headers) {
		foreach my $key (keys %$headers) {
			$request->header($key => $$headers{$key});
		}
	}
	
	
	my $response = $UA->request($request);
	
	# $response->header('Content-type')
	# $response->code
	# $response->message
	$logging =~ m/Sections/&&$r->log->info("Response code: ".$response->code. ' message: '.$response->message);

	return [$response->code, $response->content];
	}


# subclassing get_basic_credentials - providing *our* user/pw
# should return ($username, $password)
# in our case we're going to return ($username, $hash)
# username being useless,
# hash being already calculated, and stored in our db/htdigest file
# use *our* modified Digest.pm as it needs to use the precalculated hash

# $dbauth = DotMac::DotMacDB->new();
# my $savedHash = $dbauth->fetch_apache_auth($user, $realm);
# (from AuthenDigestDM.pm)
sub get_basic_credentials {
     my($self, $realm, $uri) = @_;
     return ($username, $uNameRealmPwHash);
 }

# subclassing request - calling *our* Digest.pm
sub request
{
    my($self, $request, $arg, $size, $previous) = @_;

    LWP::Debug::trace('()');

    my $response = $self->simple_request($request, $arg, $size);

    my $code = $response->code;
    $response->previous($previous) if defined $previous;

    LWP::Debug::debug('Simple response: ' .
		      (HTTP::Status::status_message($code) ||
		       "Unknown code $code"));

    if ($code == &HTTP::Status::RC_MOVED_PERMANENTLY or
	$code == &HTTP::Status::RC_FOUND or
	$code == &HTTP::Status::RC_SEE_OTHER or
	$code == &HTTP::Status::RC_TEMPORARY_REDIRECT)
    {
	my $referral = $request->clone;

	# These headers should never be forwarded
	$referral->remove_header('Host', 'Cookie');
	
	if ($referral->header('Referer') &&
	    $request->url->scheme eq 'https' &&
	    $referral->url->scheme eq 'http')
	{
	    # RFC 2616, section 15.1.3.
	    LWP::Debug::trace("https -> http redirect, suppressing Referer");
	    $referral->remove_header('Referer');
	}

	if ($code == &HTTP::Status::RC_SEE_OTHER ||
	    $code == &HTTP::Status::RC_FOUND) 
        {
	    my $method = uc($referral->method);
	    unless ($method eq "GET" || $method eq "HEAD") {
		$referral->method("GET");
		$referral->content("");
		$referral->remove_content_headers;
	    }
	}

	# And then we update the URL based on the Location:-header.
	my $referral_uri = $response->header('Location');
	{
	    # Some servers erroneously return a relative URL for redirects,
	    # so make it absolute if it not already is.
	    local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;
	    my $base = $response->base;
	    $referral_uri = "" unless defined $referral_uri;
	    $referral_uri = $HTTP::URI_CLASS->new($referral_uri, $base)
		            ->abs($base);
	}
	$referral->url($referral_uri);

	# Check for loop in the redirects, we only count
	my $count = 0;
	my $r = $response;
	while ($r) {
	    if (++$count > $self->{max_redirect}) {
		$response->header("Client-Warning" =>
				  "Redirect loop detected (max_redirect = $self->{max_redirect})");
		return $response;
	    }
	    $r = $r->previous;
	}

	return $response unless $self->redirect_ok($referral, $response);
	return $self->request($referral, $arg, $size, $response);

    }
    elsif ($code == &HTTP::Status::RC_UNAUTHORIZED ||
	     $code == &HTTP::Status::RC_PROXY_AUTHENTICATION_REQUIRED
	    )
    {
	my $proxy = ($code == &HTTP::Status::RC_PROXY_AUTHENTICATION_REQUIRED);
	my $ch_header = $proxy ?  "Proxy-Authenticate" : "WWW-Authenticate";
	my @challenge = $response->header($ch_header);
	unless (@challenge) {
	    $response->header("Client-Warning" => 
			      "Missing Authenticate header");
	    return $response;
	}

	require HTTP::Headers::Util;
	CHALLENGE: for my $challenge (@challenge) {
	    $challenge =~ tr/,/;/;  # "," is used to separate auth-params!!
	    ($challenge) = HTTP::Headers::Util::split_header_words($challenge);
	    my $scheme = lc(shift(@$challenge));
	    shift(@$challenge); # no value
	    $challenge = { @$challenge };  # make rest into a hash
	    for (keys %$challenge) {       # make sure all keys are lower case
		$challenge->{lc $_} = delete $challenge->{$_};
	    }

	    unless ($scheme =~ /^([a-z]+(?:-[a-z]+)*)$/) {
		$response->header("Client-Warning" => 
				  "Bad authentication scheme '$scheme'");
		return $response;
	    }
	    $scheme = $1;  # untainted now
	    my $class = "DotMac::Authen::\u$scheme";
	    $class =~ s/-/_/g;

	    no strict 'refs';
	    unless (%{"$class\::"}) {
		# try to load it
		eval "require $class";
		if ($@) {
		    if ($@ =~ /^Can\'t locate/) {
			$response->header("Client-Warning" =>
					  "Unsupported authentication scheme '$scheme'");
		    }
		    else {
			$response->header("Client-Warning" => $@);
		    }
		    next CHALLENGE;
		}
	    }
	    unless ($class->can("authenticate")) {
		$response->header("Client-Warning" =>
				  "Unsupported authentication scheme '$scheme'");
		next CHALLENGE;
	    }
	    return $class->authenticate($self, $proxy, $challenge, $response,
					$request, $arg, $size);
	}
	return $response;
    }
    return $response;
}

 
1;
 
