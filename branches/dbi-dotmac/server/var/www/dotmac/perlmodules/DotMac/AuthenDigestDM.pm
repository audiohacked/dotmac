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

	if ($dbType eq 'mysql') { # mysql
		use DotMac::DotMacDB::MySQL;
		$dbauth = new DotMac::DotMacDB::MySQL::;
		#carp "using mysql";
	} elsif ($dbType eq 'sqlite') {
		use DotMac::DotMacDB::SQLite;
		$dbauth = new DotMac::DotMacDB::SQLite::;
		carp "using sqlite";
	} else {
		return Apache2::Const::DECLINED;
	}

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
