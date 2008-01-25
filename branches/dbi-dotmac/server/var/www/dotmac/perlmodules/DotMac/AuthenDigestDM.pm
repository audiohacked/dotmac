package DotMac::AuthenDigestDM;

use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);
use CGI::Carp;
use strict;

sub handler {
	my ($r, $user, $realm, $hash) = @_;
	my $dbauth;

	#my $dbType = $r->dir_config('dotMacDBServType');
	#carp $dbType;
	my $dbType = 'mysql';

	$dbauth = DotMac::DotMacDB::new(provider => $dbType);

	my $savedHash = $dbauth->fetch_apache_auth($user, $realm);
	if($savedHash) {
		$$hash = $savedHash;
		return Apache2::Const::OK;
	} else {
		return Apache2::Const::HTTP_UNAUTHORIZED;
		#return Apache2::ConstDECLINED;
	}
}
1;
