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

sub fetch_hash{
	my $self = shift;
	my ($user, $realm) = @_;

	my $dbh = $self->get_dbh();

	#carp "Fetch Hash from DB";
	#carp $user;
	#carp $realm;
	#carp $dbh;

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

sub rearrange {
	my($order,@param) = @_;
	return unless @param;
	my %param;

	if (ref $param[0] eq 'HASH') {
		%param = %{$param[0]};
	} else {
		return @param unless (defined($param[0]) && substr($param[0],0,1) eq '-');

		my $i;
		for ($i=0;$i<@param;$i+=2) {
			$param[$i]=~s/^\-//;     # get rid of initial - if present
			$param[$i]=~tr/a-z/A-Z/; # parameters are upper case
		}

		%param = @param;                # convert into associative array
	}

	my(@return_array);

	local($^W) = 0;
	my($key)='';
	foreach $key (@$order) {
		my($value);
		if (ref($key) eq 'ARRAY') {
			foreach (@$key) {
				last if defined($value);
				$value = $param{$_};
				delete $param{$_};
			}
		} else {
			$value = $param{$key};
			delete $param{$key};
		}
		push(@return_array,$value);
	}
	push (@return_array,{%param}) if %param;
	return @return_array;
}
1;
#sub authen_user{
#	my ($dsn, $user, $sent_pw) = @_;
#	carp "AuthenDOTMAC_SQL";
#	#my $u = $user;
#	my $dbh = DBI->connect("DBI:mysql:database=dotmac;host=localhost", "dotmac", "dotmac");
#	my $q = "SELECT passwd FROM auth WHERE username=\'$user\'";
#	my $QueryPW = $dbh->prepare($q);
#	$QueryPW->execute;
#	my $passwd = $QueryPW->fetchrow_array;
#	
#	$QueryPW->finish;
#	$dbh->disconnect;
#
#	my $md5 = Digest::MD5->new();
#	$md5->add("$user:idisk.mac.com:$sent_pw");
#	my $gen_passwd = $md5->hexdigest; 
#
#	if ($passwd eq $gen_passwd) {
#		return 1;
#	} else {
#		return 0;
#	}
#}

#sub get_user_quota{
#	my ($dsn, $user) = @_;
#	carp "QuotaDotMac_SQL";
#	my $dbh = DBI->connect("DBI:mysql:database=dotmac;host=localhost", "dotmac", "dotmac");
#	my $q = "SELECT idisk_quota_limit FROM auth WHERE username=\'$user\'"; 
#	my $dbq = $dbh->prepare($q);
#	$dbq->execute;
#	my ($quota) = $dbq->fetchrow_array;
#	$dbq->finish;
#	$dbh->disconnect;
#	return $quota;
#}

#sub list_users{
#	my ($dsn) = @_;
#	carp "ListUsersDotMac_SQL";
#	my $dbh = DBI->connect("DBI:mysql:database=dotmac;host=localhost", "dotmac", "dotmac");
#	my $q = $dbh->prepare("SELECT username FROM auth");
#	$q->execute;
#
#	my @userlist = ();
#	while (my ($user) = $q->fetchrow_array) {
#		push @userlist, $user;
#	}
#
#	$q->finish;
#	$dbh->disconnect;
#
#	return sort @userlist;
#}
