#file:DotMac/ServiceRequest.pm
#----------------------

## Copyright (C) 2007 Walinsky
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.


## todo:
## set dotunderscore, dotunderscore-size, modificationdate(sdf_rfc1123_2.format) in mod_dav
# iterate over Element elementKey = new Element(key,"X","http://www.apple.com/SyncServices") in mod_dav
# either set: no warnings 'utf8'; (kinda cheating) or $r->print everything except getfile requests (wide char warnings on print)
# actually try using the locks we're providing - in case two clients in 1 account start syncing at the same time

package DotMac::ServiceRequest;

use strict;
use warnings;

#	binmode (STDIN, ":raw");
#	binmode (STDOUT, ":raw");

use Apache2::RequestRec ();
use Apache2::RequestIO ();
#use Apache2::Filter (); # Trying this; think we need it for correctly printing binary data to client
use Apache2::Const -compile => qw(:common :methods :http);

$DotMac::ServiceRequest::VERSION = '0.1';

use XML::DOM; # need to port the code to xml::libxml
# use XML::LibXML;
use CGI::Carp; # for neat logging to the error log
use DB_File; # we're storing our token/user and attribute keys/values in a Berkeley DB
use APR::UUID; # for generating UUIDs
use MIME::Base64;
use Encode;#use encoding "utf8";


use HTTP::Date; # we'd like some neat date formatting

use Time::gmtime;


use DirHandle; # for reading dirs
# $r->dir_config('dotMacUserDataPath');
my $rootpath;
my $userTokenDB;
my $lockTokenDB;
my $infoDBname; #'info.dat';# note that the .dat extension is hardcoded right now
my $attributesDBname; #'attributes.dat';
## we could define globals here, like
##my ($dbinfo, $sth, $sql, $r, $dbh);

sub handler {
	my $r = shift;
	
	$rootpath = $r->dir_config('dotMacUserDataPath'); #"/var/www/dotmac/userxml";
	$userTokenDB = $rootpath.$r->dir_config('dotMacUserTokenDBname'); #"/usertoken.dat";
	$lockTokenDB = $rootpath.$r->dir_config('dotMacLockTokenDBname'); #"/locktoken.dat";
	$infoDBname = $r->dir_config('dotMacInfoDBname'); #'info.dat';# note that the .dat extension is hardcoded right now
	$attributesDBname = $r->dir_config('dotMacAttrDBname'); #'attributes.dat';
	# Check that method is POST
	# syntaxis like Apache2::Const::OK;
	unless($r->method_number() == Apache2::Const::M_POST) {
		# carp "method not allowed";
		return $r->status(Apache2::Const::HTTP_METHOD_NOT_ALLOWED);
	}

	# Check the content type
#	my $content_type = $r->header_in('Content-Type');
#	unless(defined($content_type)) {
#		return $r->status(Apache2::Const::HTTP_BAD_REQUEST);
#	}
#	unless($content_type  =~ m|^text/xml\b|) {
#		return $r->status(Apache2::Const::HTTP_BAD_REQUEST);
#	}

	# Check the content length
	my $content_length = $r->header_in('Content-Length');
	unless(defined($content_length)) {
		# carp "bad request 3";
		return $r->status(Apache2::Const::HTTP_BAD_REQUEST);
	}
	#carp "content_length: $content_length";
	unless(($content_length =~ /^\d{1,10}$/) && $content_length) {
		# carp "bad request 4";
		return $r->status(Apache2::Const::HTTP_BAD_REQUEST);
	}
	
	# Get the content
	my $content;# the raw xml, sync sends us
	if (1) {
		my $buf;
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
	}
	unless(defined($content) && length($content)) {
		# carp "no content";
		return $r->status(Apache2::Const::HTTP_NO_CONTENT);
	}
	

	
	
	# Handle XML request.
	my $response_xml = processXML($content); # note that response_xml is already stringified
	
	
	$r->send_http_header('text/xml');

	$r->print ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");

	#$r->print ($response_xml);
	print ($response_xml); # if we issue a $r->print our data gets converted to utf-8 - and corrupted if sending bin data
	return Apache2::Const::OK;
}

sub processXML {
	my $indata = shift; # the stringified xml we get
	my ( $fileData, $fiop, $fileLength, $postProcess );# if raw binary data gets sent, we catch it in $fileData, need to set $postProcess if we need to embed binary data ourselves
	my $outdata; # the stringified xml we return
	#first scan the incoming xml for forbidden tokens;
	#apple throws the raw binary in xml; take it out
	# the node looks like:
	# #<file fiop="blah" length="304507"/>raw bin data</file>
	#not mac does it as follows:
	#if (xml.indexOf("type=\"putfile\"") >= 0)
	#	{
	#		fileData = xml.substring(xml.indexOf("file fiop="));
	#		String fileLength = fileData.substring(fileData.indexOf("length=\"")+"length=\"".length(),fileData.indexOf("\"",fileData.indexOf("length=\"")+"length=\"".length()));
	#		fileData = fileData.substring(fileData.indexOf("/>")+2);
	#		fileData = fileData.substring(0,Integer.parseInt(fileLength));
	#		xml = xml.substring(0, xml.indexOf(">",xml.indexOf("file fiop="))+1)+xml.substring(xml.indexOf(">",xml.indexOf("file fiop="))+1+Integer.parseInt(fileLength)+"</file>".length());
	#	}
	if (index($indata, "type=\"putfile\"") > 0) # we're going to get raw binary data
		{
		#if ( $indata =~ s{<file fiop="([^"]+)" length="([^"]+)"/>(.*?)</file>}{}s ) { # now notice the difference; this is the non-greedy way: now we have the risk of having a </file> part within the binary data
		if ( $indata =~ s{<file fiop="([^"]+)" length="([^"]+)"/>(.*)</file>}{}s ) { # assuming we have only 1 <file/> node we match the latest occurence (greedy) of </file>, and assume binary $fileData to run until there
			( $fiop, $fileLength, $fileData ) = ( $1, $2, $3 );
			carp "extracted $fiop, $fileLength, (won't show fileData); left $indata";
			# we could even test if length($fileData) == $fileLength
			# actually we should
			}
		}
	carp "request: $indata";
	# instantiate parser for indata
	#ErrorContext => 2 gives us some detailed info on possible xml errors
	my $xp = new XML::DOM::Parser(ErrorContext => 2);
	my $requestxml = $xp->parse($indata);
	my $requestrootnode = $requestxml->getElementsByTagName('request')->[0]; # this is the root node; mind you!!! this is the xml; requestxml is just the XML::DOM::Document object
	my $requestversion = $requestrootnode->getAttributeNode('version')->getValue;
	my $requestid = $requestrootnode->getAttributeNode('id')->getValue; # this seems to be empty; for now
	my $username;
	my $locktoken;
	# instantiate new xml doc (our answer)
	my $responsexml = XML::DOM::Document->new();
	# create root element
	my $responserootnode = $responsexml->createElement('response'); # this is the root node
	$responserootnode->setAttribute("version", "1.0");
	$responserootnode->setAttribute("id", "");
	
	
	
	my $transactions = $requestrootnode->getElementsByTagName('transaction'); # gather all 'transaction' child nodes
	my $transactionCount = $transactions->getLength();
	for (my $i = 0; $i < $transactionCount; $i++)
	{
		my $responsetransaction;
		my $transaction = $transactions->[$i];
		my $transactiontype = $transaction->getAttributeNode('type')->getValue;
		#set up a similar transaction childnode in the response
		$responsetransaction = $responsexml->createElement('transaction'); # create a 'transaction' childnode; needs to be appended yet
		
		# let's set the response transaction info here; otherwise we'd have to do it in all types of transactions
		$responsetransaction->setAttribute('type', $transactiontype);
		$responsetransaction->setAttribute('version', '1.0');#$transaction->getAttributeNode('version')->getValue; # we don't use the given version (yet); just set it to 1.0
		$responsetransaction->setAttribute('id', $transaction->getAttributeNode('id')->getValue);

		if ($transactiontype eq "authorization")
			{
			# processAuthorization should return usercredentials; all other subs return nothing; just alter the xml (except for 'getfile', which returns filedata (which we may even circumvent))
			($username, $locktoken) = processAuthorization ($responsexml, $transaction, $responsetransaction);
			} 

		else
			{
			if ($username)
				{
					if ($transactiontype eq "select")
						{
						&processSelect($username, $responsexml, $transaction, $responsetransaction);
						}
					elsif ($transactiontype eq "create")
						{
						&processCreate($username, $responsexml, $transaction, $responsetransaction);
						}
					elsif ($transactiontype eq "delete")
						{
						&processDelete($username, $responsexml, $transaction, $responsetransaction);
						}
					elsif ($transactiontype eq "update")
						{
						&processUpdate($username, $responsexml, $transaction, $responsetransaction);
						}
					elsif ($transactiontype eq "reset")
						{
						&processReset($username, $responsexml, $transaction, $responsetransaction);
						}
					elsif ($transactiontype eq "commit")
						{
						&processCommit($username, $responsexml, $transaction, $responsetransaction, $locktoken);
						}
					elsif ($transactiontype eq "lockacquire")
						{
						&processLock($username, $responsexml, $transaction, $responsetransaction, $locktoken);
						}
					elsif ($transactiontype eq "lockrenew")
						{
						&processLock($username, $responsexml, $transaction, $responsetransaction, $locktoken);
						}
					elsif ($transactiontype eq "lockrelease")
						{
						&processLock($username, $responsexml, $transaction, $responsetransaction, $locktoken);
						}
					elsif ($transactiontype eq "putfile")
						{
						&processPutfile($username, $responsexml, $transaction, $responsetransaction, $locktoken, $fiop, $fileData);
						}
					elsif ($transactiontype eq "getfile")
						{
						$fileData = processGetfile($username, $responsexml, $transaction, $responsetransaction, $locktoken, $fiop, $fileData);
						$postProcess = 'getfile';
						carp "length fileData is now: ".length($fileData);
						}
					else
						{
						carp "transactiontype: $transactiontype not implemented yet ;)";
						}
				}
			else # incorrect or no usercredentials; we don't process the xml; just add a Failure result to remaining transaction(s)
				{
				addFailure($responsexml, $responsetransaction, ,"-1","Unable to complete due to previous errors");
				}
			}
		$responserootnode->appendChild($responsetransaction); # append the 'transaction' childnode;
	}
	$outdata = $responserootnode->toString;
	carp "response: $outdata"; # don't show binary data
	if ($postProcess) {
		carp 'replacing __________FileData__________ with fileData';
		$outdata =~ s/__________FileData__________/$fileData/;
		}
	
	# Avoid memory leaks - cleanup circular references for garbage collection
	#so we should return xml to string; and dispose the xml object
#	$xp->dispose;
	$responsexml->dispose;
	
	#$r->print ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>");
	#$r->print($response_xml->toString);
	return $outdata;	
}

sub processAuthorization {
	# in the 1st request we get username/password
	# we provide the user with a unique token which we store with the user; so that in subsequent requests
	# we can lookup this token and fetch the username/password
	# carp "processing authorization request";
	my ($responsexml, $requesttransaction, $responsetransaction) = @_; #we get pointers to the xml-object, requesttransaction node and responsetransaction node
	my $object = getFirstChildByName ($requesttransaction, 'object');
	my $attributelist = $object->getElementsByTagName('attribute');
	my %attributes = getAttributes($attributelist);## put name/value pairs from xml into an associative array

	my $username;
	my $locktoken;
	my %user;
	my $ok = 'true';
	if ((exists($attributes{"locktoken"})) && ($attributes{"locktoken"} ne '')) {
		$locktoken = $attributes{"locktoken"};
		carp "processAuthorization got locktoken: $locktoken";
		}
	
	if((exists($attributes{"type"})) && ($attributes{"type"} eq "token")) {
		# the user already has a token
		# lookup the user
		$username = getUserFromToken($attributes{"token"});
		if ($username)
			{
			my $responsetransactionobject = $responsexml->createElement('object');
			%user = getUserCredentials($username);
			&setObjectAttributes($responsetransactionobject, %user);
			$responsetransaction->appendChild($responsetransactionobject);
			&addSuccess($responsexml, $responsetransaction);
			carp "authorized user: $username by token";
			}
		else
			{
			addFailure($responsexml, $responsetransaction, ,"-1","Missing required attribute &apos;username&apos;");
			carp "could not authorize user by token";
			}
		}
	else
		{
		if((exists($attributes{"username"})) && (exists($attributes{"password"}))) {
			# we could/should do digest auth here
			# something like: $ok = authUser($attributes{"username"}, $attributes{"password"});
			if ($ok)
				{
				my $responsetransactionobject = $responsexml->createElement('object');
				$username = $attributes{"username"};
				%user = getUserCredentials($username);
				carp "generating token";
				my $token = getNewToken();
				addUsertoken($username, $token);
				&setObjectAttributes($responsetransactionobject, %user);
				&addObjectAttribute($responsexml, $responsetransactionobject, 'token', $token);
				&setObjectAttributes($responsetransactionobject, %user);
				$responsetransaction->appendChild($responsetransactionobject);
				&addSuccess($responsexml, $responsetransaction);
				}
			else
				{
				my $givenUsername = $attributes{"username"};
				addFailure($responsexml, $responsetransaction, ,"-1","102 Auth token not valid  (invalid credentials)  ($givenUsername)");
				}
			}
		else
			{
			addFailure($responsexml, $responsetransaction, ,"-1","Missing required attribute username");
			}
		}
	return ($username, $locktoken);
	}

sub processSelect {
	carp "processing select request";
	my ($username, $responsexml, $requesttransaction, $responsetransaction) = @_; #we get pointers to the xml-object, requesttransaction node and responsetransaction node
	my $storageconsumed = 0;# total storage consumed by all sync clients under 1 account
	my $object = getFirstChildByName ($requesttransaction, 'object');
	my $attributelist = $object->getElementsByTagName('attribute');
	my %attributes = getAttributes($attributelist);

 	# create object node
	my $responsetransactionobject = $responsexml->createElement('object');
	my $ok = 'true';
	my $devicedir = $rootpath.'/'.$username.'/device';
	if (!(-d $devicedir))  { # the -d bit means check if there is a directory called ...
		my $devicedirok = recursiveMKdir($rootpath, $username.'/device');
	}
 	if(exists($attributes{"info"})) {
 		if((($attributes{"info"} eq "device") || ($attributes{"info"} eq "devices")) && ($object->getAttributeNode('entityname')->getValue eq ".mac")){
			carp "info is device(s) and entityname = .mac";
			my %user = getUserCredentials($username);
			&setObjectAttributes($responsetransactionobject, %user);

			my @subdirs = findSubDirs($devicedir);
			foreach  my $subdir (@subdirs) {
				carp "$subdir";
				my $responsetransactionobjectobject = $responsexml->createElement('object');
				#&setObjectAttributes($responsetransactionobjectobject, %user);
				loadObject($responsexml, $responsetransactionobjectobject, $subdir);
				$responsetransactionobject->appendChild($responsetransactionobjectobject);
				}
			}
		elsif ($attributes{"info"} eq "dc") {
			carp "info is dc";
			my $dcdir = $rootpath.'/'.$username.'/dc';
			if (!(-d $dcdir))  {
				my $dcdirok = recursiveMKdir($rootpath, $username.'/dc');
				}
			my %properties = loadProperties($devicedir.'/'.$object->getAttributeNode('resourceguid')->getValue);
			&setObjectAttributes($responsetransactionobject, %properties);
			
			my @subdirs = findSubDirs($dcdir);
			foreach  my $subdir (@subdirs) {
				carp "$subdir";
				my $responsetransactionobjectobject = $responsexml->createElement('object');
				
				#now we could either issue a loadobject; and read the attributes database again;
				#or read both info and attributes databases; and assign them to the xml - and reuse the attributes
				#we'll do the latter...
				my %objectobjectproperties = loadProperties($subdir);
				&setObjectAttributes($responsetransactionobjectobject, %objectobjectproperties);
				my %objectobjectattributes = loadAttributes($subdir);
				&addObjectAttributes($responsexml, $responsetransactionobjectobject, %objectobjectattributes);
				#so we've assigned both info and attributes to the object-object now
				
				my %infoMachine = loadAttributes($subdir."/".$object->getAttributeNode('resourceguid')->getValue);#this might not be correct as /subdir/guid might not exist as it hasn't been created yet
				if (exists($infoMachine{"localversion"}))
					{
					&addObjectAttribute($responsexml, $responsetransactionobjectobject, 'localversion', $infoMachine{"localversion"});
					}
				$responsetransactionobject->appendChild($responsetransactionobjectobject);
				if (exists($objectobjectattributes{"storageconsumed"}))
					{
					$storageconsumed += $objectobjectattributes{"storageconsumed"};#this is our counter for all clients on this account
					}
				}# end foreach
			#addObjectAttribute($responsexml, $node, $name, $value)
			addObjectAttribute($responsexml, $responsetransactionobject, "storageconsumed", $storageconsumed);
			}# end elsif ($attributes{"info"} eq "dc")
		}# end if(exists($attributes{"info"}))

	
	$responsetransaction->appendChild($responsetransactionobject);
	if ($ok eq 'true') {
		&addSuccess($responsexml, $responsetransaction);
		}
	#return $responsetransaction;
	}

sub processCreate {
	carp "processing create request";
	my ($username, $responsexml, $requesttransaction, $responsetransaction) = @_; #we get pointers to the xml-object, requesttransaction node and responsetransaction node
	my $object = getFirstChildByName ($requesttransaction, 'object');
	my $attributelist = $object->getElementsByTagName('attribute');
	my %attributes = getAttributes($attributelist);

 	# create object node
	my $responsetransactionobject = $responsexml->createElement('object');
	my $ok = 'true';
	my $userdirok = 'true';
	my $resourceguid = getNewGUID();
	my $resourceid = getNewResourceid();
	# carp "rootpath: $rootpath";
	# carp "username: $username";
	my $userdir = $rootpath.'/'.$username.'/device/'.$resourceguid;
	if (!(-d $userdir))  { # the -d bit means check if there is a directory called ...
		$userdirok = recursiveMKdir($rootpath, $username.'/device/'.$resourceguid);
	}
	my %info = ();
	$info{'entityid'}= $object->getAttributeNode('entityid')->getValue;
	$attributes{'entityid'}= $object->getAttributeNode('entityid')->getValue;
	
	if ($object->getAttributeNode('entityid')->getValue eq '11')
		{
		$info{'entitytype'}='1';
		$info{'entityname'}='macintosh';
		$info{'resourceid'}= $resourceid;
		$info{'resourceguid'}= $resourceguid;

		$attributes{"resourceid"}=$resourceid;
		$attributes{"resourceguid"}=$resourceguid;
		$attributes{"parentid"}="0";
		$attributes{"inservice"}="0";
		$attributes{"status"}="0";
		$attributes{"umi"}="0";
		$attributes{"flag_autotrigger"}="0";
		}

	
	$responsetransaction->appendChild($responsetransactionobject);
	&setObjectAttributes($responsetransactionobject, %info);
	&addObjectAttributes($responsexml, $responsetransactionobject, %attributes);
	$attributes{"createdate"}=simpleDateFormat();
	writeUserDB ($userdir.'/'.$infoDBname, %info);
	writeUserDB ($userdir.'/'.$attributesDBname, %attributes);
	if ($ok eq 'true') {
		&addSuccess($responsexml, $responsetransaction);
		}
	return $responsetransaction;
	}


sub processLock {
	carp "processing lock request";
	my ($username, $responsexml, $requesttransaction, $responsetransaction, $locktoken) = @_; #we get pointers to the xml-object, requesttransaction node and responsetransaction node
	my $transactiontype = $requesttransaction->getAttributeNode('type')->getValue;
	my $object = getFirstChildByName ($requesttransaction, 'object');
	my $attributelist = $object->getElementsByTagName('attribute');
	my %attributes = getAttributes($attributelist);#<attribute name="type" value="write"/><attribute name="duration" value="10"/>
	my $resourceguid = $object->getAttributeNode('resourceguid')->getValue;
	my $responsetransactionobject = $responsexml->createElement('object');

	my %rawattributes = loadAttributes($rootpath.'/'.$username.'/device/'.$resourceguid);# todo; verify if we're not mixing up info and attributes!
	my %rawinfo =loadProperties($rootpath.'/'.$username.'/device/'.$resourceguid);# todo; I'm pretty sure we're mixing up things here!

	#lockacquire
	if ($transactiontype eq 'lockacquire') {
		$rawattributes{'sessionkey'} = getNewToken();
		$rawattributes{'locktoken'} = getNewToken();
		addLocktoken($resourceguid, $rawattributes{'locktoken'});
		}
	#lockrenew
	elsif ($transactiontype eq 'lockrenew') {
		#notmac says" do nothing...just renew it
		}
	#lockrelease
	elsif ($transactiontype eq 'lockrelease') {
		#<transaction type="lockrelease" version="1.0" id="585640194">
		#	<object resourceguid="a125339c-faa3-4ddc-9724-4c2a29950a13" entityid="11">
		#		<attribute name="locktoken" value="MzI4NTUwYmUtYTVlZC00Mzc2LTljMjktZDZlNjYy1194369284"/>
		#		<attribute name="password" value="*pass*"/>
		#	</object>
		#</transaction>
		delete $rawinfo{'resourceid'};
		delete $rawinfo{'entitytype'};
		removeLocktoken($attributes{'locktoken'});#we could even verify the password
		}
	
	&setObjectAttributes($responsetransactionobject, %rawinfo);
	&addObjectAttributes($responsexml, $responsetransactionobject, %rawattributes);
	$responsetransaction->appendChild($responsetransactionobject);
	&addSuccess($responsexml, $responsetransaction);
	return $responsetransaction;
	}

sub processDelete {
	carp "processing delete request";
	my ($username, $responsexml, $requesttransaction, $responsetransaction) = @_; #we get pointers to the xml-object, requesttransaction node and responsetransaction node
	my $object = getFirstChildByName ($requesttransaction, 'object');
#	my $attributelist = $object->getElementsByTagName('attribute');
#	my %attributes = getAttributes($attributelist);

 	# create object node
	my $responsetransactionobject = $responsexml->createElement('object');
	my $ok = 'true';
	my %properties = loadProperties($rootpath.'/'.$username.'/device/'.$object->getAttributeNode('resourceguid')->getValue);
	#delete $database{$key};
	if (exists $properties{"resourceid"}) {
		delete $properties{"resourceid"};
		}
	if (exists $properties{"entitytype"}) {
		delete $properties{"entitytype"};
		}
	&setObjectAttributes($responsetransactionobject, %properties);
	recurseDelete($rootpath.'/'.$username.'/device/'.$object->getAttributeNode('resourceguid')->getValue);
	
	$responsetransaction->appendChild($responsetransactionobject);
	&addSuccess($responsexml, $responsetransaction);
	return $responsetransaction;
	}

sub processPutfile {
	carp "processing putfile request";
	my ($username, $responsexml, $requesttransaction, $responsetransaction, $locktoken, $fiop, $fileData) = @_;
	my $object = getFirstChildByName ($requesttransaction, 'object');
	my $attributelist = $object->getElementsByTagName('attribute');
	my %attributes = getAttributes($attributelist);

 	# create object node
	my $responsetransactionobject = $responsexml->createElement('object');
	my $machineGuid = getGuidFromLockToken($locktoken);
	my $ok = 'true';
	my $guid = $object->getAttributeNode('resourceguid')->getValue;

	if (!(-d $rootpath.'/'.$username.'/dc/'.$guid.'/versions')) {
		my $guiddirok = recursiveMKdir($rootpath.'/'.$username.'/dc/'.$guid, '/versions');
		}
	#fiop: 2|0|3DC8A542-D33D-41A1-847F-AE81BF3CD2F7.D000|94843a2ba4e16d1132192f02232dfaad521cc786|304507|3DC8A542-D33D-41A1-847F-AE81BF3CD2F7|-1|
	my @fiopValues = split(/\|/, $fiop);# split it by the | symbol
	my $filename = $fiopValues[2];
	$filename =~ s/\// /g;# replacing / with space - actually I've never seen this happen; the filename is a GUID (we provide) with a .D### extension
	$filename =~ s/\\/ /g;# replacing \ with space
	my $putFile = $rootpath.'/'.$username.'/dc/'.$guid.'/versions/'.$filename;
	open(PUTFILE,">$putFile") || `cat /dev/null > $putFile;chmod 666 $putFile`;
	binmode PUTFILE;
	print PUTFILE $fileData;
	close(PUTFILE);
	
	#notmac loads both info and attributes, and deletes attributes immediatly afterwards
	my %rawproperties = loadProperties($rootpath.'/'.$username.'/dc/'.$guid);
	my %rawattributes =loadAttributes($rootpath.'/'.$username.'/dc/'.$guid);
	my %objectproperties = %rawproperties; # make a copy we can play around with; need %rawproperties later again
	delete $objectproperties{"resourceid"};
	delete $objectproperties{"entitytype"};
	&setObjectAttributes($responsetransactionobject, %objectproperties);
	
	$rawattributes{'storageconsumed'} = length($fileData);
	$rawattributes{'version'} = $fiopValues[1];
	$rawattributes{'f1version'} = $fiopValues[1];
	delete $rawattributes{'localversion'};
	
	writeUserDB ($rootpath.'/'.$username.'/dc/'.$guid.'/'.$infoDBname, %rawproperties); # TODO: look at this - are we writing the exact same info back as we read in 5 lines earlier ?
	writeUserDB ($rootpath.'/'.$username.'/dc/'.$guid.'/'.$attributesDBname, %rawattributes);
	
	if (!(-d $rootpath.'/'.$username.'/dc/'.$guid.'/'.$machineGuid)) {
		my $guiddirok = recursiveMKdir($rootpath.'/'.$username.'/dc/'.$guid, $machineGuid);
		}
	my %localInfo = ();
	my %localAttributes = loadAttributes($rootpath.'/'.$username.'/dc/'.$guid.'/'.$machineGuid);
	$localAttributes{'localversion'} = $fiopValues[1];
	writeUserDB ($rootpath.'/'.$username.'/dc/'.$guid.'/'.$machineGuid.'/'.$infoDBname, %localInfo); # TODO: look at this - why are we writing an empty hash to a db ?
	writeUserDB ($rootpath.'/'.$username.'/dc/'.$guid.'/'.$machineGuid.'/'.$attributesDBname, %localAttributes);
	
	$fileData = "";# let's free some memory
	
	updateMachineSyncDates($username, $machineGuid);
	
	$responsetransaction->appendChild($responsetransactionobject);
	&addSuccess($responsexml, $responsetransaction);
	return $responsetransaction;
	}

sub processGetfile {
	carp "processing getfile request";
	my ($username, $responsexml, $requesttransaction, $responsetransaction, $locktoken, $fiop, $fileData) = @_;
	my $object = getFirstChildByName ($requesttransaction, 'object');
	#object doesn't have 'attribute' childnodes
	#my $attributelist = $object->getElementsByTagName('attribute');
	#my %attributes = getAttributes($attributelist);
	#it does have an attribute 'entityname' though
	my $objectEntityname = $object->getAttributeNode('entityname')->getValue;
	
	# create object node
	my $responsetransactionobject = $responsexml->createElement('object');
	my $machineGuid = getGuidFromLockToken($locktoken);
	my $ok = 'true';
	my $guid = $object->getAttributeNode('resourceguid')->getValue;
	
	my $fileNode = getFirstChildByName ($object, 'file');
	$fiop = $fileNode->getAttributeNode('fiop')->getValue;
	my @fiopValues = split(/\|/, $fiop);# split it by the | symbol
	my $filename = $fiopValues[2];
	$filename =~ s/\// /g;# replacing / with space
	$filename =~ s/\\/ /g;# replacing \ with space
	my $getFile = $rootpath.'/'.$username.'/dc/'.$guid.'/versions/'.$filename;

	my $binfileLength = (stat($getFile))[7];
	open (GETFILE, $getFile) || die "couldn't open $getFile for reading!";
	binmode GETFILE;
	read (GETFILE, $fileData, $binfileLength);
	close(GETFILE);
	carp "reading $getFile";

	
	
	# let's see if (string) filelength differs from (binary) filelength
	my $fileLength = length($fileData);
	if ($fileLength != $binfileLength) {
		carp "filelength string ($fileLength) actually differs from filelength binary ($binfileLength)";
		}
	else
		{
		carp "filelength string ($fileLength) matches filelength binary ($binfileLength)";
		}
 	# now for some strange reason, notmac not only just constructs a new object node (without attributes)
 	# but also explicitly removes attributes, and child attribute nodes from this newly created object node
 	# so let's just sing along, and don't set/add object attributes
	
	#create file node
	my $responsetransactionobjectfile = $responsexml->createElement('file');
	$responsetransactionobjectfile->setAttribute('length', $fileLength);
	my $dummyFileData = $responsexml->createTextNode('__________FileData__________');
	# my $dummyFileData = $responsexml->createTextNode($fileData); #doens't work - it will embed data; but gives an error on client (- not on server!)
	$responsetransactionobjectfile->appendChild($dummyFileData);
	$responsetransactionobject->appendChild($responsetransactionobjectfile);
	
	$responsetransaction->appendChild($responsetransactionobject);
	&addSuccess($responsexml, $responsetransaction);
	return $fileData;
	}

sub processCommit {
	carp "processing commit request";
	my ($username, $responsexml, $requesttransaction, $responsetransaction, $locktoken) = @_; #we get pointers to the xml-object, requesttransaction node and responsetransaction node
	my $object = getFirstChildByName ($requesttransaction, 'object');
	my $attributelist = $object->getElementsByTagName('attribute');
	my %attributes = getAttributes($attributelist);
 	# create object node
	my $responsetransactionobject = $responsexml->createElement('object');
	my $ok = 'true';

	my $guid = $object->getAttributeNode('resourceguid')->getValue;
	my $entityname = $object->getAttributeNode('entityname')->getValue;
	#carp $rootpath.'/'.$username.'/dc/'.$guid;
	if (!(-d $rootpath.'/'.$username.'/dc/'.$guid))  {
		makeObject($rootpath.'/'.$username.'/dc/', "", "", $entityname, "", $guid);
	}
	
	my %rawinfo = loadProperties($rootpath.'/'.$username.'/dc/'.$guid);
	my %rawattributes =loadAttributes($rootpath.'/'.$username.'/dc/'.$guid);
	
	#TODO: special case where "adds" is always added and not just replaced.
	
	%rawattributes = (%rawattributes, %attributes); #If the two combined hashes contain several identical keys, then the values of the latter hash will win.

	#if ($fieldValue eq '') {
  	# $fieldValue is defined but empty
	#}
	#if ($fieldValue ne '') {
	  # $fieldValue is not blank (but may be false)
	#}
	my $localversion;
	if (exists($rawattributes{"localversion"}))
		{
		$localversion = $rawattributes{"localversion"};
		delete $rawattributes{"localversion"};
		}
	writeUserDB ($rootpath.'/'.$username.'/dc/'.$guid.'/'.$infoDBname, %rawinfo); # TODO: look at this - are we writing the exact same info back as we read in 5 lines earlier ?
	writeUserDB ($rootpath.'/'.$username.'/dc/'.$guid.'/'.$attributesDBname, %rawattributes);
	
	if (!($localversion eq ''))
		{
		# fetch the locktoken
		carp 'fetch the locktoken / machine guid here; and create the directory';
		my $machineGuid = getGuidFromLockToken($locktoken);
		if (!(-d $rootpath.'/'.$username.'/dc/'.$guid.'/'.$machineGuid)) {
			my $guiddirok = recursiveMKdir($rootpath.'/'.$username.'/dc/'.$guid, $machineGuid);
			}
		my %localattributes =loadAttributes($rootpath.'/'.$username.'/dc/'.$guid.'/'.$machineGuid);
		$localattributes{'localversion'} = $localversion;
		writeUserDB ($rootpath.'/'.$username.'/dc/'.$guid.'/'.$machineGuid.'/'.$attributesDBname, %localattributes);
		}
	
	#loadObject is _our_ last phase; notxml does it 3 times
	loadObject($responsexml, $responsetransactionobject, $rootpath.'/'.$username.'/dc/'.$guid);
	$responsetransaction->appendChild($responsetransactionobject);
	&addSuccess($responsexml, $responsetransaction);
	return $responsetransaction;
	}

sub processReset {
	carp "processing reset request";
	my ($username, $responsexml, $requesttransaction, $responsetransaction) = @_; #we get pointers to the xml-object, requesttransaction node and responsetransaction node
	my $object = getFirstChildByName ($requesttransaction, 'object');
	#my $attributelist = $object->getElementsByTagName('attribute');
	#my %attributes = getAttributes($attributelist);
	my $guid = $object->getAttributeNode('resourceguid')->getValue;
	
	my %properties = loadProperties($rootpath.'/'.$username.'/dc/'.$guid);
	my %attributes = loadAttributes($rootpath.'/'.$username.'/dc/'.$guid);
	
	$attributes{"f1version"}="-2";
	$attributes{"version"}="-2";
	$attributes{"baseversion"}="-2";
	$attributes{"storageconsumed"}="0";
	$attributes{"adds"}="0";
	$attributes{"updates"}="0";
	$attributes{"deletes"}="0";
	$attributes{"moves"}="0";
	$attributes{"renames"}="0";
	$attributes{"lastmoddate"} = time2str();
	
	recurseDelete($rootpath.'/'.$username.'/dc/'.$guid);
	my $guiddirok = recursiveMKdir($rootpath, $username.'/dc/'.$guid);
	writeUserDB ($rootpath.'/'.$username.'/dc/'.$guid.'/'.$infoDBname, %properties);
	writeUserDB ($rootpath.'/'.$username.'/dc/'.$guid.'/'.$attributesDBname, %attributes);

	# create object node
	my $responsetransactionobject = $responsexml->createElement('object');
	&setObjectAttributes($responsetransactionobject, %properties);
	$responsetransaction->appendChild($responsetransactionobject);
	&addSuccess($responsexml, $responsetransaction);
	return $responsetransaction;
	}

#doesn't do anything yet, except return failure to client
sub processUpdate {
	carp "processing update request";
	my ($username, $responsexml, $requesttransaction, $responsetransaction) = @_; #we get pointers to the xml-object, requesttransaction node and responsetransaction node
	my $object = getFirstChildByName ($requesttransaction, 'object');
	my $attributelist = $object->getElementsByTagName('attribute');
	my %attributes = getAttributes($attributelist);

	my $ok = 'true';
	# test if $object->getAttributeNode('resourceguid') exists, then ->getValue
	#my %savedAttributes = loadAttributes($rootpath.'/'.$username.'/device/'.$object->getAttributeNode('resourceguid')->getValue);

	# compare %attributes with %savedAtrributes; when equal return success; else return failure
	
	#for now, let's say:
	$ok = 'false';
	if ($ok eq 'true') {
		&addSuccess($responsexml, $responsetransaction);
		}
	else {
		addFailure($responsexml, $responsetransaction, "47","47 Device named was not found in users PIN (Could not find specified device.)");
		}
	return $responsetransaction;
	}

sub makeObject {
	my ($path, $entityid, $entitytype, $entityname, $description, $guid) = @_;
	if ($guid eq "") {
		$guid = getNewGUID();
		}
	if (!(-d $path.'/'.$guid))  { # the -d bit means check if there is a directory called ...
		my $guiddirok = recursiveMKdir($path, $guid);
	}
	my $resourceid = getNewResourceid();
	
	my %info = ();
	$info{"resourceguid"} = $guid;
	if (!($entityid eq "")) {
		$info{"entityid"} = $entityid;
	}
	if (!($entitytype eq "")) {
		$info{"entitytype"} = $entitytype;
	}
	$info{"entityname"} = $entityname;
	$info{"resourceid"} = $resourceid;

	my %attributes = ();
	$attributes{"resourceguid"} = $guid;
	if (!($entityid eq "")) {
		$attributes{"entityid"} = $entityid;
	}
	$attributes{"resourceid"} = $resourceid;	
	$attributes{"f1version"}="-2";
	$attributes{"version"}="-2";
	$attributes{"baseversion"}="-2";
	$attributes{"storageconsumed"}="0";
	$attributes{"name"} = $entityname;
	$attributes{"adds"}="0";
	$attributes{"updates"}="0";
	$attributes{"deletes"}="0";
	$attributes{"moves"}="0";
	$attributes{"renames"}="0";
	if (!($description eq "")) {
		$attributes{"description"} = $description;
	}
	$attributes{"lastmoddate"} = time2str();

	if ($entityname eq "ICAL")
	{
		$info{"entityid"} = "1";
		$info{"entitytype"} = "10";
		delete $attributes{"resourceid"};
		$attributes{"description"} = "Calendar";
		$attributes{"f1version"} = "0";
		$attributes{"version"} = "0";
		$attributes{"baseversion"} = "0";
	}
	if ($entityname eq "BKMK")
	{
		$info{"entityid"} = "6";
		$info{"entitytype"} = "10";
		delete $attributes{"resourceid"};
		$attributes{"description"} = "Bookmarks";
		$attributes{"f1version"} = "0";
		$attributes{"version"} = "0";
		$attributes{"baseversion"} = "0";
	}
	if ($entityname eq "CONT")
	{
		$info{"entityid"} = "2";
		$info{"entitytype"} = "10";
		delete $attributes{"resourceid"};
		$attributes{"description"} = "Contacts";
		$attributes{"f1version"} = "0";
		$attributes{"version"} = "0";
		$attributes{"baseversion"} = "0";
	}
	writeUserDB ($path.'/'.$guid.'/'.$infoDBname, %info);
	writeUserDB ($path.'/'.$guid.'/'.$attributesDBname, %attributes);
}

sub recurseDelete {
	my $dir = shift;
	local *DIR;

	opendir DIR, $dir or die "opendir $dir: $!";
	my $found = 0;
	while ($_ = readdir DIR) {
	        next if /^\.{1,2}$/;
	        my $path = "$dir/$_";
		unlink $path if -f $path;
		recurseDelete($path) if -d $path;
	}
	closedir DIR;
	rmdir $dir or print "error - $!";
}

# usage: $string = simpleDateFormat( [$time_t] ); 
# omit parameter for current time/date
# returns string yyyy MM dd, HH:mm:ss z
sub simpleDateFormat { 
	my $tm = gmtime(shift || time);
	return(sprintf("%04d %02d %02d, %02d:%02d:%02d GMT", $tm->year+1900, $tm->mon+1, $tm->mday, $tm->hour, $tm->min, $tm->sec)); 
} 
## return name/value pairs from xml into an associative array	
sub getAttributes {
	my $attributelist = shift;
	my %attributes = ();
	my $n = $attributelist->getLength();
	for (my $j = 0; $j < $n; $j++)
		{
			my $attributename = $attributelist->[$j]->getAttributeNode('name')->getValue;
			my $attributevalue = $attributelist->[$j]->getAttributeNode('value')->getValue;
			$attributes{$attributename}= $attributevalue;
		}
	return %attributes;
	}

sub getFirstChildByName
  { my( $node, $tag)= @_;
    return $node->getElementsByTagName($tag)->[0];
  }

sub addObjectAttributes
	{ my ($responsexml, $node, %attributes) = @_;
	while ((my $key, my $value) = each %attributes) {
		&addObjectAttribute($responsexml, $node, $key, $value);
		}
	} 
sub addObjectAttribute
 	{ my ($responsexml, $node, $name, $value) = @_;
 	my $newattribute = $responsexml->createElement('attribute');
 	$newattribute->setAttribute('name', $name);
 	$newattribute->setAttribute('value', $value);
 	$node->appendChild($newattribute);
 	}
 
sub setObjectAttributes
	{ my ($node, %attributes) = @_;
	while ((my $key, my $value) = each %attributes) {
		$node->setAttribute($key, $value);
		}
	}

sub loadObject
	{my ($responsexml, $node, $path) = @_;
	my %properties = loadProperties($path);
	&setObjectAttributes($node, %properties);
	my %attributes =loadAttributes($path);
	&addObjectAttributes($responsexml, $node, %attributes);
	}

sub loadProperties
	{my $path = shift;
	my %properties = ();
	%properties = readUserDB($path.'/'.$infoDBname, %properties);
	return %properties;
	}
sub loadAttributes
	{my $path = shift;
	my %attributes = ();
	%attributes = readUserDB($path.'/'.$attributesDBname, %attributes);
	return %attributes;
	}
	
# should return the user specific thingies
sub getUserCredentials
	{
	my $username = shift; # we get an associative array %attributes of user credentials
	#carp "getUserCredentials usercredentials:";


	
	# read user specific thingies from xml file (in $home/$username); and get them in an array
	my %properties = ();
	my $userfolder = $rootpath.'/'.$username;
	if (!(-d $userfolder))  {
		my $userfolderok = recursiveMKdir($rootpath, $username);
	}
	my $userinfo = $userfolder.'/'.$infoDBname;

	if (!(-f $userinfo)) { # the info for user does not exist
		#create it!
		#carp "user info doesnt exist; creating $userinfo";
		$properties{'entityid'}= '100';
		$properties{'entitytype'}= '7';
		$properties{'entityname'}= '.mac';
		$properties{'resourceid'}= getNewResourceid();
		$properties{'resourceguid'}= getNewGUID();
		writeUserDB($userinfo, %properties);
		}
	else # read the data
		{
		#carp "user info exists; reading $userinfo";
		%properties = readUserDB($userinfo, %properties);
		}
	
	return %properties;
	}

sub addSuccess
	{ my ($responsexml, $node) = @_;
	my $resultnode = $responsexml->createElement('result');
	&addObjectAttribute($responsexml, $resultnode, 'resultcode', '0');
	&addObjectAttribute($responsexml, $resultnode, 'resulttext', 'success');
	$node->appendChild($resultnode);
	}

sub addFailure
	{ my ($responsexml, $node, $errorCode, $errorMsg) = @_;
	my $resultnode = $responsexml->createElement('result');
	&addObjectAttribute($responsexml, $resultnode, 'resultcode', $errorCode);
	&addObjectAttribute($responsexml, $resultnode, 'resulttext', $errorMsg);
	&addObjectAttribute($responsexml, $resultnode, 'hostname', 'sync-mgmt666');
	&addObjectAttribute($responsexml, $resultnode, 'timestamp', simpleDateFormat());
	$node->appendChild($resultnode);
	}

sub addUsertoken
	{ my ($user, $token) = @_;
	my  %database;
	my ($key, $value);
	tie %database, 'DB_File', $userTokenDB
		or die "Can't initialize database: $!\n";
	
	# now first lets see if this user already has a token; if so - delete it
	# GAH! we still can't
	#while (($key, $value) = each %database ) {
    #	if ($user eq $database{$key}) {
    #		delete $database{$key};
    #		}
	#	}
	# now we can safely insert a new token/user pair; the user will only have 1 token
	$database{$token} = $user;
	### Close the Berkeley DB
	untie %database;
	}

sub addLocktoken
	{ my ($guid, $token) = @_;
	my  %database;
	my ($key, $value);
	tie %database, 'DB_File', $lockTokenDB
		or die "Can't initialize database: $!\n";
	
	# now first lets see if this user already has a token; if so - delete it
	#while (($key, $value) = each %database ) {
    #	if ($guid eq $database{$key}) {
    #		delete $database{$key};
    #		}
	#	}
	# now we can safely insert a new token/user pair; the user will only have 1 token
	$database{$token} = $guid;
	### Close the Berkeley DB
	untie %database;
	}

sub removeLocktoken
	{ my $token = shift;
	my  %database;
	tie %database, 'DB_File', $lockTokenDB
		or die "Can't initialize database: $!\n";
	delete $database{$token};
	### Close the Berkeley DB
	untie %database;
	}

sub getGuidFromLockToken
	{ 
	my $token = shift;
	my $guid;
	my  %database;
	tie %database, 'DB_File', $lockTokenDB
		or die "Can't initialize database: $!\n";
	if ($database{$token}) {
		$guid = $database{$token};
		}
	### Close the Berkeley DB
	untie %database;
	return $guid;
	}

sub getUserFromToken
	{ 
	my $token = shift;
	my $user;
	my  %database;
	tie %database, 'DB_File', $userTokenDB
		or die "Can't initialize database: $!\n";
	if ($database{$token}) {
		$user = $database{$token};
		}
	### Close the Berkeley DB
	untie %database;
	return $user;
	}

sub writeUserDB
	{ my ($dbpath, %attributes) = @_;
	my  %database;
	my ($key, $value);
	tie %database, 'DB_File', $dbpath
		or warn "Can't initialize database: $dbpath; $!\n";# don't die; just warn
	
	while (($key, $value) = each %attributes ) {
		$value = Encode::encode("utf-8" , $value);# encode them utf first; then print
		$database{$key} = $value;
		}
	### Close the Berkeley DB
	untie %database;
	}

sub readUserDB
	{ my ($dbpath, %attributes) = @_;
	my  %database;
	my ($key, $value);
	tie %database, 'DB_File', $dbpath
		or warn "Can't initialize database: $dbpath; $!\n";# don't die; just warn
	
	while (($key, $value) = each %database ) {
		#carp "key: $key value: $value"; # print them first; then decode utf
		$value = Encode::decode("utf-8" , $value);
		$attributes{$key} = $value;
		}
	### Close the Berkeley DB
	untie %database;
	return %attributes
	}

sub getNewToken {
    # get a random UUID and format it as a string
	# my $uuid = APR::UUID->new->format;
	my $uuid = APR::UUID->new->format;
	my $token = encode_base64($uuid);
	return (substr $token, 0, 40).time();
}

sub getNewGUID {
	return APR::UUID->new->format;
}

sub getNewResourceid {
	return time();
}
sub updateMachineSyncDates
	{ my ($username, $machineGuid) = @_;
	my %attributes =loadAttributes($rootpath.'/'.$username.'/device/'.$machineGuid);
	$attributes{'inservice'} = '1';
	if (!(exists $attributes{"firstsyncdate"})) {
		$attributes{"firstsyncdate"} = simpleDateFormat();
		}
	$attributes{"lastsyncdate"} = simpleDateFormat();
	writeUserDB ($rootpath.'/'.$username.'/device/'.$machineGuid.'/'.$attributesDBname, %attributes);
	}

# recursiveMKdir should split up $restpath in an array (by /) and loop testing 'growing' paths
sub recursiveMKdir
	{ my ($rootpath, $addpath) = @_;
	my $slash = '/';
	my $adddir;
	# carp "trying to glue rootpath: $rootpath and $addpath";
	
	# taking off trailing slash
	if (rindex($addpath, $slash) == ((length $addpath)-1)){
		$addpath = substr $addpath, 0, ((length $addpath)-1);
		}
	# setup a loop checking for / and recursively test creating subdirs	
	until (length $addpath == 0) {
		# taking off leading slash
		if (index($addpath, $slash) == 0) {
			$addpath = substr $addpath, 1, length $addpath;
			}
		my $slashpos = index($addpath, $slash);
		if ($slashpos != -1) {
			$adddir = substr $addpath, 0, $slashpos;
			my $leftoverpath = substr $addpath, $slashpos + 1, length $addpath;
			}
		else
			{
			$adddir = $addpath;
			}
		# carp "creating dir $rootpath.$slash.$adddir";
		if (!(-d $rootpath.$slash.$adddir))  {
			mkdir ($rootpath.$slash.$adddir, 0777) || die "sorry system is unable to create output directory $rootpath.$slash.$addpath";
			}
		$addpath = substr $addpath, length $adddir, length $addpath;
		$rootpath = $rootpath.$slash.$adddir;
		}
	}

sub findSubDirs {
   my $dir = shift;
   my $dh = DirHandle->new($dir)   or die "can't opendir $dir: $!";
   return sort                     # sort pathnames
          grep {    -d     }       # choose only directories
          map  { "$dir/$_" }       # create full paths
          grep {  !/^\./   }       # filter out dot files
          $dh->read();             # read all entries
}
1;