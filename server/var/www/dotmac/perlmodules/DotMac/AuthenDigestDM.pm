package DotMac::AuthenDigestDM;

use DotMac::DotMacDB;
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);
use CGI::Carp;
use strict;
use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::Log;
use Apache2::ServerUtil ();
use Data::Dumper;

sub handler {
	carp "AuthenDigestDM";
	my ($r, $user, $realm, $hash) = @_;
	my $dbauth;

	my $dbType = $r->dir_config('dotMacDBServType');
	my $s = Apache2::ServerUtil->server;	

	#carp $user;
	#carp $realm;

	$dbauth = DotMac::DotMacDB->new();

	my $savedHash = $dbauth->fetch_apache_auth($user, $realm);
	#carp $savedHash;
	if($savedHash) {
		$$hash = $savedHash;
		return Apache2::Const::OK;
	} else {
		return Apache2::Const::HTTP_UNAUTHORIZED;
		#return Apache2::ConstDECLINED;
	}
}
1;
