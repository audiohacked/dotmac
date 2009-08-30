## Copyright (C) 2007 Sean Nelson, Robert See
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
