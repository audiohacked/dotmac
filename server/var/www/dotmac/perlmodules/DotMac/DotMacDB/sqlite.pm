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
package DotMac::DotMacDB::sqlite;

use DBI;
use strict;
use CGI::Carp;
use Data::Dumper;
use File::Spec;

our @ISA = qw(DotMac::DotMacDB);

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;

	#carp "new DotMacDB-sqlite";

    my ($var_hash)=@_;
    
    my $privatePath = exists $var_hash->{'dotMacPrivatePath'} ?  $var_hash->{'dotMacPrivatePath'} : "nullprivatepath";
  	my $dbname = exists $var_hash->{'dotMacDBName'} ? $var_hash->{'dotMacDBName'} : "nulldbname";
	my $dmRealm = exists $var_hash->{'dotMacRealm'} ? $var_hash->{'dotMacRealm'} : "nullrealm";
	my $dbistring= 'dbi:SQLite:dbname='.$privatePath.'/'.$dbname;

	my $dotmacDBconn = DBI->connect($dbistring, "", "");
	#carp $dbistring;
	$dotmacDBconn->do("	PRAGMA default_synchronous = OFF");
	my $self = {
		dbh => $dotmacDBconn,
		realm => $dmRealm,
	};
	return bless $self, $class;
}

1;
