#!/usr/bin/perl

use Digest::MD5;
use DBI;

my $connectstr="dbi:SQLite:./dotmac";
my $dbh=DBI->connect($connectstr);
my $user=$ARGV[0];
my $newpass=$ARGV[1];
my $realm = "idisk.mac.com";

my $md5 = Digest::MD5->new();
$md5->add("$user:$realm:$newpass");
my $genPassWd = $md5->hexdigest;

my $insertQuery = "INSERT INTO auth (username, passwd,realm,is_admin) VALUES (?,?,?,1)";
my $q = $dbh->prepare($insertQuery);
$q->execute($user,$genPassWd,$realm);
$q->finish;	
