package DotMac::DotMacDB::sqlite;

use DBI;
use strict;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;

	carp "new DotMacDB-mysql";

    my $var_hash={@_};
  	my $dbname = exists $var_hash->{'db'} ? $var_hash->{'db'} : "dotmac";
	my $dbuser = exists $var_hash->{'user'} ? $var_hash->{'user'} : "dotmac";
	my $dbpass = exists $var_hash->{'pass'} ? $var_hash->{'pass'} : "dotmac";


	my $dotmacDBconn = DBI->connect('dbi:SQLite:dbname='.$dbname, "", "");
	my $self = {
		dbh => $dotmacDBconn,
	};
	return bless $self, $class;
}

sub fetch_apache_auth{
	my $self = shift;
	my ($user, $realm) = @_;

	my $dbh = $self->{dbh};

	my $QueryPW = $dbh->prepare(qq{SELECT passwd FROM auth WHERE username=? AND realm=?});
	$QueryPW->execute($user, $realm);
	my ($passwd) = $QueryPW->fetchrow_array;
	$QueryPW->finish;	
	return $passwd;
}

sub dbh {
	shift->{dbh};
}

sub DESTROY {
	my $self = shift;
	$self->{dbh}->disconnect if defined $self->{dbh};
}

sub authen_user{
	my $self = shift;
	my ($user, $sent_pw, $realm) = @_;

	my $dbh = $self->{dbh};

	my $QueryPW = $dbh->prepare(qq{SELECT passwd FROM auth WHERE username=? AND realm=?});
	$QueryPW->execute($user, $realm);
	my $passwd = $QueryPW->fetchrow_array;
	
	$QueryPW->finish;

	my $md5 = Digest::MD5->new();
	$md5->add("$user:$realm:$sent_pw");
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

	my $dbh = $self->{dbh};

	my $dbq = $dbh->prepare(qq{SELECT idisk_quota_limit FROM auth WHERE username=? AND realm=?});
	$dbq->execute($user,$realm);
	my ($quota) = $dbq->fetchrow_array;
	$dbq->finish;
	return $quota;
}

sub add_user{
	my $self = shift;
	my ($user, $newpass, $realm) = @_;

	my $dbh = $self->{dbh};
	
	my $insertQuery = "INSERT INTO auth (username, passwd) VALUES (\'$user\',  encode(digest( $user || ':' || $realm || ':' || $newpass , 'md5'), 'hex'));";
	my $q = $dbh->do($insertQuery);
	$q->finish;
}

sub update_user_info{
	my $self = shift;
	my ($user, $email, $quota, $realm) = @_;

	my $dbh = $self->{dbh};

	my $q = $dbh->prepare(qq{UPDATE auth SET idisk_quota_limit=?, email_addr=? WHERE username=? AND realm=?});
	$q->execute($quota, $email, $user, $realm);
	$q->finish;
}

sub fetch_user_info{
	my $self = shift;
	my ($user, $realm) = @_;

	my $defaultQuota = '';
	my $defaultEmail = '';

	my $dbh = $self->{dbh};
	
	my $q = $dbh->prepare(qq{SELECT idisk_quota_limit, email_addr FROM auth WHERE username=? AND realm=?});
	$q->execute($user,$realm);
	($defaultQuota, $defaultEmail) = $q->fetchrow_array;
	$q->finish;
	return ($defaultQuota, $defaultEmail);
}

sub list_users{
	my $self = shift;
	my ($realm) = @_;

	my $dbh = $self->{dbh};
	
	my $q = $dbh->prepare(qq{SELECT username FROM auth WHERE realm=?});
	$q->execute($realm);

	my @userlist = ();
	while (my ($user) = $q->fetchrow_array) {
		push @userlist, $user;
	}

	$q->finish;

	return sort @userlist;
}

1;
