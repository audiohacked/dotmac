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

sub new {
	my $invocant = shift;
	my $class = ref($invocant) || $invocant;

	carp "new DotMacDB-sqlite";

    my ($var_hash)=@_;
    
    my $privatePath = exists $var_hash->{'dotMacPrivatePath'} ?  $var_hash->{'dotMacPrivatePath'} : "nullprivatepath";
  	my $dbname = exists $var_hash->{'dotMacDBName'} ? $var_hash->{'dotMacDBName'} : "nulldbname";
	my $dmRealm = exists $var_hash->{'dotMacRealm'} ? $var_hash->{'dotMacRealm'} : "nullrealm";
	my $dbistring= 'dbi:SQLite:dbname='.$privatePath.'/'.$dbname;

	my $dotmacDBconn = DBI->connect($dbistring, "", "");
	carp $dbistring;
	$dotmacDBconn->do("	PRAGMA default_synchronous = OFF");
	my $self = {
		dbh => $dotmacDBconn,
		realm => $dmRealm,
	};
	return bless $self, $class;
}

sub fetch_apache_auth{
	carp "DotMacDB-sqlite: fetch_apache_auth";
	my $self = shift;
	my ($user, $realm) = @_;

	my $dbh = $self->{dbh};
	$realm ||= $self->{realm};

	my $QueryPW = $dbh->prepare(qq{SELECT passwd FROM auth WHERE username=? AND realm=?});
	$QueryPW->execute($user, $self->{realm});
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
	carp "DotMacDB-sqlite: authen_user";
	my $self = shift;
	my ($user, $sent_pw, $realm) = @_;

	my $dbh = $self->{dbh};
	$realm ||= $self->{realm};

	my $QueryPW = $dbh->prepare(qq{SELECT passwd FROM auth WHERE username=? AND realm=?});
	$QueryPW->execute($user, $realm);
	my $passwd = $QueryPW->fetchrow_array;
	
	$QueryPW->finish;

	carp $user;
	carp $realm;
	carp $sent_pw;

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

	my $md5 = Digest::MD5->new();
	$md5->add("$user:$realm:$newpass");
	my $genPassWd = $md5->hexdigest;

	my $insertQuery = "INSERT INTO auth (username, passwd,realm) VALUES (?,?,?)";
	
	my $q = $dbh->prepare($insertQuery);
	$q->execute($user,$genPassWd,$realm);
	$q->finish;
}

sub update_user_info{
	my $self = shift;
	my ($storageHash, $realm) = @_;
	my $dbh = $self->{dbh};
	$realm ||= $self->{realm};
	my $q = $dbh->prepare(qq{UPDATE auth SET idisk_quota_limit=?, is_admin=?, is_idisk=?, email_addr=? WHERE username=? AND realm=?});
	$q->execute($storageHash->{'quota'},$storageHash->{'is_admin'},$storageHash->{'is_idisk'}, $storageHash->{'email'}, $storageHash->{'user'}, $realm);
	$q->finish;
}

sub fetch_user_info{
	my $self = shift;
	my ($user, $realm) = @_;

	my $defaultQuota = '';
	my $defaultEmail = '';
	my $returnHash;
	
	my $dbh = $self->{dbh};
	$realm ||= $self->{realm};
	
	my $q = $dbh->prepare(qq{SELECT * FROM auth WHERE username=? AND realm=?});
	$q->execute($user,$realm);
	$returnHash = $q->fetchrow_hashref;
	$q->finish;
	return ($returnHash);
}

sub write_delta_record{
	my $self = shift;
	my $dbh = $self->{dbh};
	my $timestamp = time();
	my ($user, $opcode, $source, $target) = @_;
	my $q = $dbh->prepare("insert into delta values(?,?,?,?,?)");
	$q->execute($user,$opcode,$source,$target,$timestamp);
	$q->finish();
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

sub generate_htdigest_files{
	my $self = shift;
	my ($idiskusers, $idiskadmins) = @_;
	my $realm = $self->{realm};
	my $dbh = $self->{dbh};
	my $sql = "select * from auth where is_idisk=1";
	my $record;

	my $q=$dbh->prepare($sql);
	$q->execute();
	open IDU,">$idiskusers";
	while($record = $q->fetchrow_hashref()) {

        print IDU $record->{'username'}.":".$realm.":".$record->{'passwd'}."\n";

	}
	close IDU;
	$q->finish;

	my $sql = "select * from auth where is_admin=1";

	my $q=$dbh->prepare($sql);
	$q->execute();
	open IDA,">$idiskadmins";
	while($record = $q->fetchrow_hashref()) {

        print IDA $record->{'username'}.":".$realm.":".$record->{'passwd'}."\n";

	}
	close IDA;
	$q->finish;
	
}

sub list_users_idisk{
	my $self = shift;
	my ($realm) = @_;

	my $dbh = $self->{dbh};
	$realm ||= $self->{realm};
	
	my $q = $dbh->prepare(qq{SELECT username FROM auth WHERE realm=? and is_idisk=1});
	$q->execute($realm);

	my @userlist = ();
	while (my ($user) = $q->fetchrow_array) {
		push @userlist, $user;
	}

	$q->finish;

	return sort @userlist;
}
1;
