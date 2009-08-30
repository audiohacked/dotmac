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
use CGI::Carp;

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;

	carp "new DotMacDB-mysql";

	my $var_hash={@_};
  	my $dbname = exists $var_hash->{'db'} ? $var_hash->{'db'} : "dotmac";
	my $host = exists $var_hash->{'host'} ? $var_hash->{'host'} : "localhost";
	my $dbuser = exists $var_hash->{'user'} ? $var_hash->{'user'} : "dotmac";
	my $dbpass = exists $var_hash->{'pass'} ? $var_hash->{'pass'} : "dotmac";
	my $dbRealm = exists $var_hash->{'dotMacRealm'} ? $var_hash->{'dotMacRealm'} : "idisk.mac.com";

	my $dotmacDBconn = DBI->connect('dbi:mysql:database='.$dbname.';host='.$host, $dbuser, $dbpass);
	my $self = {
		dbh => $dotmacDBconn,
		realm => $dbRealm,
	};
	return bless $self, $class;
}

sub fetch_apache_auth{
	my $self = shift;
	my ($user, $realm) = @_;

	my $dbh = $self->{dbh};
	$realm ||= $self->{realm};

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
	$realm ||= $self->{realm};

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
	$realm ||= $self->{realm};

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
	$realm ||= $self->{realm};
	
	my $insertQuery = "INSERT INTO auth (username, passwd) VALUES (\'$user\', MD5(\'$user:$realm:$newpass\'));";
	my $q = $dbh->do($insertQuery);
	$q->finish;
}

sub update_user_info{
	my $self = shift;
	my ($user, $email, $quota, $realm) = @_;

	my $dbh = $self->{dbh};
	$realm ||= $self->{realm};

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
	$realm ||= $self->{realm};
	
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
	$realm ||= $self->{realm};
	
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
