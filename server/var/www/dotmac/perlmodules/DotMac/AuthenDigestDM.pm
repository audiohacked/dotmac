package DotMac::AuthenDigestDM;

use Apache::Log;
use Apache::Const -compile => qw(OK DECLINED HTTP_UNAUTHORIZED);

use strict;

sub handler {
	my ($r, $user, $realm, $hash) = @_;
	my $dbType = $r->dir_config('dotMacDBServType');
	my $dbauth = '';
	if ($dbType eq 'mysql') { # mysql
		use DotMac::DotMacDB::MySQL;
		$dbauth = DotMac::DotMacDB::MySQL;
	} elsif ($dbType eq 'sqlite') {
		use DotMac::DotMacDB::SQLite;
		$dbauth = DotMac::DotMacDB::SQLite;
	} else {
		return Apache::DECLINED;
	}

	my $savedHash = $dbauth->fetch_hash($user, $realm);

	if ($hash eq $saveHash) {
		return Apache::OK;
	} else {
		return Apache::HTTP_UNAUTHORIZED;
		#return Apache::DECLINED;
	}
}

1;
