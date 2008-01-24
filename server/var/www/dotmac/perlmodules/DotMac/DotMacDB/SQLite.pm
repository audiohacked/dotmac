package DotMac::DotMacDB::MySQL;

use DBI;

my $dsn = "DBI:mysql:database=dotmac;host=localhost";
my $dbuser = 'dotmac';
my $dbpass = 'dotmac';

sub fetch_hash{
	my ($user, $realm) = @_;
	my $dbh = DBI->connect($dsn, $dbuser, $dbpass);
	my $q = "SELECT passwd FROM auth WHERE username=\'$u\'";
	my $QueryPW = $dbh->prepare($q);
	$QueryPW->execute;
	my $passwd = $QueryPW->fetchrow_array;
	
	$QueryPW->finish;
	$dbh->disconnect;

	my $md5 = Digest::MD5->new();
	$md5->add("$u:idisk.mac.com:$sent_pw");
	my $gen_passwd = $md5->hexdigest;
	
	return $gen_passwd;
}

sub authen_user{
	my ($dsn, $user, $sent_pw) = @_;
	carp "AuthenDOTMAC_SQL";
	my $u = $user;
	my $dbh = DBI->connect($dsn, $dbuser, $dbpass);
	my $q = "SELECT passwd FROM auth WHERE username=\'$u\'";
	my $QueryPW = $dbh->prepare($q);
	$QueryPW->execute;
	my $passwd = $QueryPW->fetchrow_array;
	
	$QueryPW->finish;
	$dbh->disconnect;

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
	my ($dsn, $user) = @_;
	carp "QuotaDotMac_SQL";
	my $dbh = DBI->connect($dsn, $dbuser, $dbpass);
	my $q = "SELECT idisk_quota_limit FROM auth WHERE username=\'$user\'"; 
	my $dbq = $dbh->prepare($q);
	$dbq->execute;
	my ($quota) = $dbq->fetchrow_array;
	$dbq->finish;
	$dbh->disconnect;
	return $quota;
}

sub list_users{
	my ($dsn) = @_;
	carp "ListUsersDotMac_SQL";
	my $dbh = DBI->connect($dsn, $dbuser, $dbpass);
	my $q = $dbh->prepare("SELECT username FROM auth");
	$q->execute;

	my @userlist = ();
	while (my ($user) = $q->fetchrow_array) {
		push @userlist, $user;
	}

	$q->finish;
	$dbh->disconnect;

	return sort @userlist;
}
