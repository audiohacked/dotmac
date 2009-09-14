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
package DotMac::DotMacDB::mysql;

use DBI;
use strict;
#use CGI::Carp;

our @ISA = qw(DotMac::DotMacDB);

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;

	#carp "new DotMacDB-mysql";

	my $var_hash={@_};
  	my $dbname = exists $var_hash->{'dotMacDBName'} ? $var_hash->{'dotMacDBName'} : "dotmac";
	my $host = exists $var_hash->{'dotMacDBServName'} ? $var_hash->{'dotMacDBServName'} : "localhost";
	my $dbuser = exists $var_hash->{'dotMacDBUser'} ? $var_hash->{'dotMacDBUser'} : "dotmac";
	my $dbpass = exists $var_hash->{'dotMacDBPasswd'} ? $var_hash->{'dotMacDBPasswd'} : "dotmac";
	my $dbRealm = exists $var_hash->{'dotMacRealm'} ? $var_hash->{'dotMacRealm'} : "idisk.mac.com";
	my $dbistring = exists $var_hash->{'dotMacPerlDBI'} ? $var_hash->{'dotMacPerlDBI'} : "dbi:mysql:database=dotmac;host=localhost";
	my $dotmacDBconn = DBI->connect($dbistring, $dbuser, $dbpass);
	my $self = {
		dbh => $dotmacDBconn,
		realm => $dbRealm,
	};
	return bless $self, $class;
}

1;
