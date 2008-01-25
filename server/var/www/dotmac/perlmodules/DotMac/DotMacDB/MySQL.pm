package DotMac::DotMacDB::MySQL;

use DBI;
use strict;
use CGI::Carp;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;

	my $dbname = exists $_{db} ? $_{db} : "dotmac";
	my $host = exists $_{host} ? $_{host} : "localhost";
	my $dbuser = exists $_{user} ? $_{user} : "dotmac";
	my $dbpass = exsits $_{pass} ? $_{pass} : "dotmac";

	my $dotmacDBconn = DBI->connect('dbi:mysql:database='.$dbname.';host='.$host, $dbuser, $dbpass);
	my $self = {
		dbh => $dotmacDBconn,
	};
	return bless $self, $class;
}

sub fetch_apache_auth{
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

sub authen_user{
	my $self = shift;
	my ($user, $sent_pw, $realm) = @_;

	my $dbh = $self->get_dbh();

	my $QueryPW = $dbh->prepare(qq{SELECT passwd FROM auth WHERE username=? AND realm=?});
	$QueryPW->execute($user, $realm);
	my $passwd = $QueryPW->fetchrow_array;
	
	$QueryPW->finish;

	my $md5 = Digest::MD5->new();
	$md5->add("$u:idisk.mac.com:$sent_pw");
	my $gen_passwd = $md5->hexdigest; 

	if ($passwd eq $gen_passwd) {
		return 1;
	} else {
		return 0;
	}
}

sub get_user_quota{
	my $self = shift;
	my ($user, $realm) = @_;

	my $dbh = $self->get_dbh();

	my $dbq = $dbh->prepare(qq{SELECT idisk_quota_limit FROM auth WHERE username=? AND realm=?});
	$dbq->execute;
	my ($quota) = $dbq->fetchrow_array;
	$dbq->finish;
	return $quota;
}

sub list_users{
	my $self = shift;
	my $dbh = $self->get_dbh()
	
	my $q = $dbh->prepare("SELECT username FROM auth");
	$q->execute;

	my @userlist = ();
	while (my ($user) = $q->fetchrow_array) {
		push @userlist, $user;
	}

	$q->finish;

	return sort @userlist;
}
