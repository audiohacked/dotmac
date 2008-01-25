package DotMac::DotMacDB::SQLite;

use DBI;
use strict;
use CGI::Carp;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;

	my $dbfile = exists $_{file} ? $_{file} : "/var/www/dotmac/private/dotmac";

	my $dotmacDBConn = DBI->connect("DBI:sqlite:".$dbfile, "", "");
	my $self = {
		dbn => $dotmacDBConn,

	};
	return bless $self, $class;
}

sub fetch_hash{
	my $self = shift;
	my ($user, $realm) = @_;
	
	my $dbh = $self->get_dbh();

	my $QueryPW = $dbh->prepare(qq{SELECT passwd FROM auth WHERE username=? AND realm=?});
	$QueryPW->execute($user, $realm);
	my ($passwd) = $QueryPW->fetchrow_array;
	
	$QueryPW->finish;
	return $passwd;
}

sub get_dbh {
	shift->{dbh};
}

sub DESTROY {
	my $self = shift;
	$self->dbh->disconnect if defined $self->dbh;
}
1;
