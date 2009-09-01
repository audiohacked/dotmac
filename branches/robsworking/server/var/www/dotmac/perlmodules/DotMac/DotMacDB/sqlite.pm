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

sub fetch_apache_auth{
	#carp "DotMacDB-sqlite: fetch_apache_auth";
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
	#carp "DotMacDB-sqlite: authen_user";
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

	my $md5 = Digest::MD5->new();
	$md5->add("$user:$realm:$newpass");
	my $genPassWd = $md5->hexdigest;

	my $insertQuery = "INSERT INTO auth (username, passwd, realm) VALUES (?,?,?)";
	
	my $q = $dbh->prepare($insertQuery);
	$q->execute($user,$genPassWd,$realm);
	$q->finish;
}

sub update_user_info{
	my $self = shift;
	my ($storageHash, $realm) = @_;
	my $dbh = $self->{dbh};
	$realm ||= $self->{realm};
	my $q = $dbh->prepare(qq{UPDATE auth SET idisk_quota_limit=?, is_admin=?, is_idisk=?, email_addr=?, firstname=?, lastname=? WHERE username=? AND realm=?});
	$q->execute($storageHash->{'idisk_quota_limit'},$storageHash->{'is_admin'},$storageHash->{'is_idisk'}, $storageHash->{'email_addr'}, $storageHash->{'firstname'}, $storageHash->{'lastname'}, $storageHash->{'user'}, $realm);
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

sub return_delta_records{
	my $self = shift;
	my ($username, $queryts)=@_;
	my $dbh = $self->{dbh};
	my $sql="select * from delta where user = '$username' and timestamp >= $queryts";
	#carp $sql;
	my $sth=$dbh->prepare($sql);
	$sth->execute();
	my @retarr;
	my $count=0;
	while (my @arrayref = $sth->fetchrow_array()) {

			push(@retarr,\@arrayref);
			$count++;
	}
	$sth->finish();
	#carp "Count: ".$count;
	return \@retarr;
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

sub list_user_idisk{
	my $self = shift;
	my ($realm,$user) = @_;

	my $dbh = $self->{dbh};
	$realm ||= $self->{realm};
	
	my $q = $dbh->prepare(qq{SELECT username FROM auth WHERE realm=? and username=? and is_idisk=1});
	$q->execute($realm,$user);

	$q->finish;

	return $q->fetchrow_array;
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

sub write_comment_properties{
	my $self = shift;
        my $user = shift;
        my $path = shift;
        my $properties = shift;

	my $dbh = $self->{dbh};

	my $q = $dbh->prepare("INSERT OR REPLACE INTO commentProperties ('user', 'path', 'properties') SELECT id, ?, ? FROM auth WHERE username=?") or die "Error in write_comment_properties: ".$dbh->errstr;
	$q->execute($path,$properties,$user) or die "Error in write_comment_properties: ".$q->errstr;
	$q->finish();
}

sub fetch_comment_properties{
        my $self = shift;
        my $user = shift;
        my $path = shift;

        my $dbh = $self->{dbh};
	my $q = $dbh->prepare("SELECT commentProperties.properties FROM commentProperties, auth WHERE auth.username=? AND auth.id=commentProperties.user AND path=?") or die "Error in fetch_comment_properties: ".$dbh->errstr;
        $q->execute($user,$path) or die "Error in fetch_comment_properties: ".$q->errstr;
        my($result) = $q->fetchrow_array();
        $q->finish();

        return $result;
}

# Fetches the path of the nearest path upwards in the file tree where comment properties has been set
sub find_nearest_path_with_properties{
        my $self = shift;
        my $user = shift;
        my $path = shift;

        my @dirs = File::Spec->splitdir($path);

        my $dbh = $self->{dbh};
        my $q = $dbh->prepare("SELECT commentProperties.path FROM commentProperties, auth WHERE auth.username=? AND auth.id=commentProperties.user AND commentProperties.path=?") or die "Error in fetch_commentprop_path_recursive: ".$dbh->errstr;

        my $result;
        until($result) {
                warn "find_nearest_path_with_properties: calling sql with params: $user, ".File::Spec->catdir(@dirs)."\n";
                $q->execute($user, File::Spec->catdir(@dirs)) or die "Error in find_nearest_path_with_properties: ".$dbh->errstr;
                $result = ($q->fetchrow_array())[0];
        } continue {
                pop(@dirs);
                last if $#dirs <= 0;
        }

        warn "No result found in find_nearest_path_with_properties\n";

        return $result;
}

sub write_comment{
	my $self = shift;
        my $user = shift;
        my $path = shift;
        my $commentID = shift;
        my $tag = shift;
        my $comment = shift;

	my $dbh = $self->{dbh};

	my $q = $dbh->prepare("INSERT OR REPLACE INTO comments ('user', 'path', 'commentID', 'tag', 'comment') SELECT auth.id, ? as path, ? as commentID, ? as tag, ? as comment FROM auth WHERE username=? ") or die "Error in write_comment: ".$dbh->errstr;
	$q->execute($path,$commentID,$tag,$comment,$user) or die "Error in write_comment: ".$q->errstr;
	$q->finish();
}

sub delete_comment {
        my $self = shift;
        my $user = shift;
        my $path = shift;
        my $commentID = shift;

        my $dbh = $self->{dbh};

        my $q = $dbh->prepare("DELETE FROM comments WHERE EXISTS( SELECT 1 FROM auth WHERE comments.user=auth.id AND auth.username=? ) AND path=? AND commentID=?") or die "Error in delete_comment: ".$dbh->errstr;
        $q->execute($user,$path,$commentID) or die "Error in delete_comment: ".$q->errstr;
        $q->finish();
}

sub list_comments_since_tag {
	my $self = shift;
        my $user = shift;
        my $path = shift;
        my $tag = shift;

	my $dbh = $self->{dbh};
	
	my $q = $dbh->prepare("SELECT comments.commentID FROM comments, auth WHERE auth.username=? AND auth.id=comments.user AND comments.path=? AND comments.tag>?") or die "Error in list_comments_since_tag: ".$dbh->errstr;
	$q->execute($user,$path,$tag);

	my @result = ();
	while (my ($comment) = $q->fetchrow_array) {
		push(@result, $comment);
	}

	$q->finish;

	return @result;
}

sub list_comments_for_path {
        my $self = shift;
        my $user = shift;
        my $path = shift;

        my $dbh = $self->{dbh};
        my $q = $dbh->prepare("SELECT comments.commentID FROM comments, auth WHERE auth.username=? AND auth.id=comments.user AND path=?") or die "Error in list_comments_for_path: ".$dbh->errstr;
        $q->execute($user, $path) or die "Error in list_comments_for_path: ".$q->errstr;

        my @result = ();
        while( my($comment) = $q->fetchrow_array ){
                push(@result, $comment);
        }

        $q->finish;

        return @result;
}

sub fetch_comment{
        my $self = shift;
        my $user = shift;
        my $path = shift;
        my $commentID = shift;

        my $dbh = $self->{dbh};
	my $q = $dbh->prepare("SELECT comments.comment FROM comments, auth WHERE auth.username=? AND auth.id=comments.user AND path=? AND commentID=?") or die "Error in fetch_comment: ".$dbh->errstr;
        $q->execute($user,$path,$commentID) or die "Error in fetch_comment: ".$q->errstr;
        my($result) = $q->fetchrow_array();
        $q->finish();

        return $result;
}

sub increase_comment_tag{
	my $self = shift;
        my $user = shift;

	my $dbh = $self->{dbh};

        # First create the row for the user if it doesn't exist
        my $q = $dbh->prepare("INSERT OR IGNORE INTO commentTag SELECT auth.id, 0 as tag FROM auth WHERE auth.username=?") or die "Error in increase_comment_tag: ".$dbh->errstr;
        $q->execute($user) or die "Error in increase_comment_tag: ".$q->errstr;
        $q->finish();

        # Then increase the tag
        $q = $dbh->prepare("UPDATE commentTag SET tag=tag+1 WHERE EXISTS( SELECT 1 FROM auth WHERE commentTag.user=auth.id AND auth.username=? )") or die "Error in increase_comment_tag: ".$dbh->errstr;
        $q->execute($user) or die "Error in increase_comment_tag: ".$q->errstr;
	$q->finish();

        return $self->fetch_comment_tag($user);
}

sub fetch_comment_tag{
        my $self = shift;
        my $user = shift;

        my $dbh = $self->{dbh};
	my $q = $dbh->prepare("SELECT commentTag.tag FROM commentTag, auth WHERE auth.username=? AND commentTag.user=auth.id") or die "Error in fetch_comment_tag: ".$dbh->errstr;
        $q->execute($user) or die "Error in fetch_comment_tag: ".$q->errstr;
        my($result) = $q->fetchrow_array();
        $q->finish();

        return $result;
}

1;
