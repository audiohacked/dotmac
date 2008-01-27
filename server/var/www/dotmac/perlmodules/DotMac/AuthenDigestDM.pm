package DotMac::AuthenDigestDM;

use DotMac::DotMacDB;
use Apache2::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);
use CGI::Carp;
use strict;

sub handler {
	carp "AuthenDigestDM";
	my ($r, $user, $realm, $hash) = @_;
	my $dbauth;

	my $dbType = $r->dir_config('dotMacDBServType');
	#carp $dbType;
	#carp $user;
	#carp $realm;

	$dbauth = DotMac::DotMacDB->new( -provider=>'mysql', 
		-db=>'dotmac',
		-host=>'localhost',
		-user=>'dotmac',
		-pass=>'dotmac'
		);

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
