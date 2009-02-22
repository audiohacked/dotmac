#!/usr/bin/perl

use Digest::MD5;
use DBI;
use Data::Dumper;

my $idiskusers='iDiskUsers';
my $idiskadmins='iDiskAdmins';

my $connectstr="dbi:SQLite:./dotmac";
my $dbh=DBI->connect($connectstr);
my $realm = "idisk.mac.com";

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

#my $insertQuery = "INSERT INTO auth (username, passwd,realm,is_admin) VALUES (?,?,?,1)";
#my $q = $dbh->prepare($insertQuery);
#$q->execute($user,$genPassWd,$realm);
#$q->finish;	
