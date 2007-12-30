#file:DotMac/CommonCode.pm
#----------------------

## Copyright (C) 2007 Walinsky
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.

package DotMac::CommonCode;
$DotMac::CommonCode::VERSION = '0.1';
use strict;
use warnings;

use CGI::Carp;
use DB_File;
use Encode;
use File::Copy;
use File::Spec;
use XML::DOM;
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Log;
use Apache2::SubRequest ();
use DotMac::NullOutputFilter;
use DotMac::PostingInputFilter;
use Data::Dumper;

sub readUserDB
	{ my ($dbpath, %attributes) = @_;
	my  %database;
	my ($key, $value);
	tie %database, 'DB_File', $dbpath
		or warn "Can't initialize database: $dbpath; $!\n";# don't die; just warn
	
	while (($key, $value) = each %database ) {
		$value = Encode::decode("utf-8" , $value);
		$attributes{$key} = $value;
		}
	### Close the Berkeley DB
	untie %database;
	return %attributes
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

sub recursiveMKdir
	{ my ($rootpath, $addpath) = @_;
	# TODO: move to File::Path;
	# mkpath(['/foo/bar/baz', 'blurfl/quux'], 1, 0711);
	my $slash = '/';
	my $adddir;
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
		if (!(-d $rootpath.$slash.$adddir))  {
			mkdir ($rootpath.$slash.$adddir, 0777) || die "sorry system is unable to create output directory $rootpath.$slash.$addpath";
			}
		$addpath = substr $addpath, length $adddir, length $addpath;
		$rootpath = $rootpath.$slash.$adddir;
		}
	}

sub recursiveMKCOL
	{
	my ($r,$uri) = @_;
	$uri=$r->uri if $uri eq "";
	my $logging = $r->dir_config('LoggingTypes');
	my $lcv1; ### The outer loop which will be the path element we are currently working with
	my $lcv2; ### The inner loop which will be all of the elements up until the current one
	my @arr=split("/",$uri); 
	shift @arr if $arr[0] eq ""; ### Drop the initial element off, which should normally be ""
	my $resulturi; ### The temp URI we are working with 
	my @outarr; ### the array of arrays we return back (contains result code and path
	my ($subreq,$rc);
	for($lcv1=0; $lcv1 < scalar @arr; $lcv1++){
		my @tmparr=();
		for ($lcv2=0; $lcv2 <= $lcv1; $lcv2++) {
			push(@tmparr,$arr[$lcv2]);
			}
			$resulturi="/".join("/",@tmparr);
			$subreq = $r->lookup_method_uri("MKCOL", $resulturi);
			$subreq->headers_out->{'X-Webdav-Method'}="";
			$subreq->add_output_filter(\&DotMac::NullOutputFilter::handler);
			$logging=~m/SubreqDebug/&&$r->log->info("recursiveMKCOL request: ". Dumper($subreq));
			$rc=$subreq->run;
			$logging=~m/SubreqDebug/&&$r->log->info("Subreq call with $resulturi returned $rc");
			$rc = 200 if ($rc == 405); ### Convert the return code to HTTP OK if the create fails for a directory
			$rc = 201 if ($rc == 0); ### Convert the return code to HTTP CREATED if the create suceeds.
			push(@outarr,([$rc,$resulturi]));
		}
		$logging=~m/SubreqDebug/&&$r->log->info(Dumper(\@outarr));
		
	return @outarr;
	}

sub dmpatchpaths_response {
	my ($r, @resparr) = @_;
	my $innerarr;
	$r->print("<?xml version=\"1.0\" encoding=\"utf-8\" ?>
<INS:response-status-set xmlns:INS=\"http://idisk.mac.com/_namespace/set/\">\n");
	foreach $innerarr (@resparr) {
		my $xmlout=$innerarr->[1];
		$xmlout=~s/\<\?xml version="1.0" encoding="utf-8"\?\>//g;
		$r->print($xmlout);
		}
	$r->print("</INS:response-status-set>\n");

	}
sub dmpatchpaths_request {
	my ($r, $inXML) = @_;
	my $logging = $r->dir_config('LoggingTypes');
	my $xp = new XML::DOM::Parser(ErrorContext => 2);
	my $requestxml = $xp->parse($inXML);
	my $requestrootnode = $requestxml->getElementsByTagName('x0:request-instructions-set')->[0];
	my $rootattributes = $requestrootnode->getAttributes;
	my $rootattributescount = $requestrootnode->getAttributes->getLength;
	my %nshash;
	my @retarr;
	for (my $i = 0; $i < $rootattributescount; $i++) {
		$nshash{$rootattributes->item($i)->getName()}=$rootattributes->item($i)->getValue();
	}

	my $requestxml_root = $requestxml->getDocumentElement;
	my $requestInstructions = $requestrootnode->getElementsByTagName('x0:request-instructions'); # gather all 'transaction' child nodes
	my $requestInstructionsCount = $requestInstructions->getLength();
	my $resulturi;
	$r->log->info("In dmpatchpaths");
	
	
	for (my $j = 0; $j < $requestInstructionsCount; $j++){
		my $action = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:action')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
		my $href = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:href')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
		my $successcodes = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:success-codes')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
    	my $subreq;
    	#print ("action: $action, href: $href, success-codes: $successcodes\n");
		if ($action eq 'PROPPATCH')
        {
        	my $propblock = XMLDOMgetFirstChildByName($requestInstructions->[$j],'x1:propertyupdate')->cloneNode(1);
			my $newXML = XML::DOM::Document->new();
			my $decl=new XML::DOM::XMLDecl;
			$decl->setVersion("1.0");
			$newXML->setXMLDecl($decl);
			$propblock->setOwnerDocument($newXML);
			foreach my $key (keys %nshash) {
				$propblock->setAttribute($key,$nshash{$key});
			}
			$newXML->appendChild($propblock);
			$logging =~ m/Sections/&&$r->log->info("Found a PROPPATCH buried in DMPATCHPATHS, uri: ".$href);	
			push(@retarr,subrequest($r, "PROPPATCH", $href, $newXML->toString()));
			}
     }
	return @retarr;

}

sub subrequest {
	my ($r, $method, $href, $xml) = @_;
	my $subreq;
	my $rc;
	my $logging = $r->dir_config('LoggingTypes');
	$subreq = $r->lookup_method_uri($method, $href);
	$subreq->add_output_filter(\&DotMac::NullOutputFilter::CaptureOutputFilter);			
	$subreq->add_input_filter(\&DotMac::PostingInputFilter::handler);
	$subreq->headers_in->{'X-Webdav-Method'}="";
	$subreq->pnotes('postdata',$xml);
	$rc=$subreq->run();
	$logging =~ m/SubreqDebug/&&$r->log->info("Captured Data dm: ".$subreq->pnotes('returndata'));
	return ([$rc,$subreq->pnotes('returndata')]);
}

sub dmmkpath_request
	{ my ( $r, $inXML) = @_;
	my $xp = new XML::DOM::Parser(ErrorContext => 2);
	my $requestxml = $xp->parse($inXML);
	my $requestrootnode = $requestxml->getElementsByTagName('x0:request-instructions-set')->[0];
	my $requestxml_root = $requestxml->getDocumentElement;
	my $requestInstructions = $requestrootnode->getElementsByTagName('x0:request-instructions'); # gather all 'transaction' child nodes
	my $requestInstructionsCount = $requestInstructions->getLength();
	#carp ("I have $requestInstructionsCount instructions \n");
	my @outarr;

	# our node looks like:
	# <x0:request-instructions>
	# <x0:action>DMMKPATH</x0:action>
	# <x0:href>/sjorsdeberekorst1/Web/.Temporary%20Web%20Resources/5657C625-B34F-4173-8717-9B11DEE57A81/Site/sjorsdeberekorst1_dot_com/sjorsdeberekorst1_dot_com_files</x0:href>
	# <x0:success-codes>207</x0:success-codes>
	# </x0:request-instructions>
	for (my $j = 0; $j < $requestInstructionsCount; $j++)
			{
				my $action = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:action')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				my $href = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:href')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				my $successcodes = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:success-codes')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				#print ("action: $action, href: $href, success-codes: $successcodes\n");
				
				if ($action eq 'DMMKPATH')
					{
						push(@outarr,recursiveMKCOL($r,$href));

					}
		
			}
		return (@outarr);
	}

sub returnHTTPCodesText {
	my ($val) = @_;
	if ($val == 201) {
		return "HTTP/1.1 201 Created";
	} elsif ($val == 200) {
		return "HTTP/1.1 200 Ok";
	} elsif ($val == 405) {
		return "HTTP/1.1 405 Method Not Allowed";
	} else {
		return "HTTP/1.1 $val UNKNOWN";
	}
}

sub dmmkpath_response
	{
	my (@arr)  = @_;
	my $innerarr;
	my $responsexml = XML::DOM::Document->new();
	my $decl=new XML::DOM::XMLDecl;
	$decl->setVersion("1.0");
	$decl->setEncoding("UTF-8");
	$responsexml->setXMLDecl($decl);
	my $responserootnode = $responsexml->createElement('INS:response-status-set'); # this is the root node
	$responserootnode->setAttribute('xmlns:INS', 'http://idisk.mac.com/_namespace/set/');

	foreach $innerarr (@arr) {
		my $responsemultistatus = $responsexml->createElement('multistatus');
		$responsemultistatus->setAttribute('xmlns', 'DAV:');
		my $responsemultistatusresponse = $responsexml->createElement('response');
		$responsemultistatusresponse->setAttribute('xmlns', 'DAV:');
		my $hrefelement = $responsexml->createElement('href');
		my $hreftextnode = $responsexml->createTextNode($innerarr->[1]);
		$hrefelement->appendChild($hreftextnode);
		$responsemultistatusresponse->appendChild($hrefelement);

		my $statuselement = $responsexml->createElement('status');

		my $statustextnode;
		my $msg=returnHTTPCodesText($innerarr->[0]);
		$statustextnode = $responsexml->createTextNode($msg);
		$statuselement->appendChild($statustextnode);
		$responsemultistatusresponse->appendChild($statuselement);
		$responsemultistatus->appendChild($responsemultistatusresponse); # append the 'multistatus' childnode;
		$responserootnode->appendChild($responsemultistatus);
		}
		$responsexml->appendChild($responserootnode);
	return ($responsexml->toString());
	}


sub movefile 
	{ 
	my ($rootpath, $source, $dest) = @_;
	my $sourcepath="$rootpath/$source";
	my $destpath="$rootpath/$dest";
	move($sourcepath, $destpath) || die "Sorry system is unable to move flie $sourcepath to $destpath";
	}
	
sub check_for_dir_backref {
	my ($line) = @_;
	if ($line =~ m/\/\.\./) {
		return 1;
	} else { 
		return 0;
	}
}
sub authen_user{
	my ($r, $user, $sent_pw) = @_;
	if ($r->dir_config('dotMacDBType') eq 'file')
		{
		return authen_user_file($r, $user, $sent_pw);
		}
	elsif ($r->dir_config('dotMacDBType') eq 'SQL')
		{
		
		}
    }
sub URLDecode {
    my $theURL = $_[0];
    $theURL =~ tr/+/ /;
    $theURL =~ s/%([a-fA-F0-9]{2,2})/chr(hex($1))/eg;
    $theURL =~ s/<!--(.|\n)*-->//g;
    return File::Spec->canonpath($theURL);
}
sub authen_user_file{
	my ($r, $username, $password) = @_;
	carp $r->dir_config('dotMacUserDB');
	my @htfile = (	DBType => 'Text',
				DB     => $r->dir_config('dotMacUserDB'),
				Server => 'apache',
				Encrypt => 'MD5');
	my $user = new HTTPD::UserAdmin @htfile;
	# grab realm:hashedpassword from digest database
	my $info = $user->password($username);
	my($realm, $checksum) = split(":", $info);
	# generate realm:hashedpassword from supplied password
	my $digestpassword =$user->encrypt("$username:$realm:$password");
	if ($info eq $digestpassword) {
		return 1;
		}
	else {
		return 0;
		}
  
    }

sub authen_user_SQL{
      my ($r, $user, $sent_pw) = @_;
      return "Not implemented yet !";
    }

sub get_user_quota{
	my ($r, $user) = @_;
	my $dotMacUserDataPath = $r->dir_config('dotMacUserDataPath');
	my $dotMacUdataDBname = $r->dir_config('dotMacUdataDBname');
#	my %userData = DotMac::CommonCode::readUserDB("$dotMacUserDataPath/$user/$dotMacUdataDBname", my %attributes);
#	return $userData{'quota'};
	return do_get_user_quota("$dotMacUserDataPath/$user/$dotMacUdataDBname");
	}

sub do_get_user_quota{
	my ($db) = @_;
	my %userData = readUserDB($db, my %attributes);
	return $userData{'quota'};
	}

sub get_user_quota_used{
	my ($r, $user) = @_;
	my $home_dir = $r->dir_config('dotMaciDiskPath') . "/$user";
	my $quotaUsedBytes = `du -sk $home_dir`; chop($quotaUsedBytes);# query for usage in KiloBytes
	$quotaUsedBytes =~ s/^(\d+)(.*)/$1/;
	return $quotaUsedBytes;
	}

sub list_users{
	my ($r) = @_;
	if ($r->dir_config('dotMacDBType') eq 'file')
		{
		return list_users_file($r);
		}
	elsif ($r->dir_config('dotMacDBType') eq 'SQL')
		{
		
		}
    }

 sub list_users_file{
	my ($r) = @_;
	my $dbFile = $r->dir_config('dotMacUserDB');
	return do_list_users_file($dbFile);
	}

 sub do_list_users_file{
	my ($dbFile) = @_;
	my @htfile = (	DBType => 'Text',
				DB     => $dbFile,
				Server => 'apache',
				Encrypt => 'MD5');
	my $userAdmin = new HTTPD::UserAdmin @htfile;
	my @users = $userAdmin->list;
	return sort @users;
	}

 sub dec2hex {
    # parameter passed to
    # the subfunction
    my $decnum = $_[0];
    # the final hex number
    
    #my $hexnum;
    #my $tempval;
    #initialize properly for not getting 'uninitialized value in concatenation (.) or string' error
    my $hexnum = '';
    my $tempval = '';
    
    while ($decnum != 0) {
		# get the remainder (modulus function)
		# by dividing by 16
		$tempval = $decnum % 16;
		# convert to the appropriate letter
		# if the value is greater than 9
		if ($tempval > 9) {
			$tempval = chr($tempval + 87); # 55 for uppercase
			}
		# 'concatenate' the number to 
		# what we have so far in what will
		# be the final variable
		$hexnum = $tempval . $hexnum ;
		# new actually divide by 16, and 
		# keep the integer value of the 
		# answer
		$decnum = int($decnum / 16); 
		# if we cant divide by 16, this is the
		# last step
		if ($decnum < 16) {
			# convert to letters again..
			if ($decnum > 9) {
				$decnum = chr($decnum + 87); # 55 for uppercase
				}
		
			# add this onto the final answer.. 
			# reset decnum variable to zero so loop
			# will exit
			$hexnum = $decnum . $hexnum; 
			$decnum = 0 
			}
		}
    return $hexnum;
    } # end sub

sub dmmkpaths
	{ my ( $r, $inXML) = @_;
	my $xp = new XML::DOM::Parser(ErrorContext => 2);
	my $requestxml = $xp->parse($inXML);
	my $requestrootnode = $requestxml->getElementsByTagName('x0:request-instructions-set')->[0];
	my $requestxml_root = $requestxml->getDocumentElement;
	my $requestInstructions = $requestrootnode->getElementsByTagName('x0:request-instructions'); # gather all 'transaction' child nodes
	my $requestInstructionsCount = $requestInstructions->getLength();
	carp ("I have $requestInstructionsCount instructions \n");
	
	my $ruser=$r->user;
 	my $idiskpath = $r->dir_config('dotMaciDiskPath'); #"/var/www/dotmac/iDisk";
	my $responsexml = XML::DOM::Document->new();
	my $decl=new XML::DOM::XMLDecl;
	$decl->setVersion("1.0");
	$decl->setEncoding("UTF-8");
	$responsexml->setXMLDecl($decl);
	my $responserootnode = $responsexml->createElement('INS:response-status-set'); # this is the root node
	$responserootnode->setAttribute('xmlns:INS', 'http://idisk.mac.com/_namespace/set/');
	# our node looks like:
	# <x0:request-instructions>
	# <x0:action>DMMKPATH</x0:action>
	# <x0:href>/sjorsdeberekorst1/Web/.Temporary%20Web%20Resources/5657C625-B34F-4173-8717-9B11DEE57A81/Site/sjorsdeberekorst1_dot_com/sjorsdeberekorst1_dot_com_files</x0:href>
	# <x0:success-codes>207</x0:success-codes>
	# </x0:request-instructions>
	for (my $j = 0; $j < $requestInstructionsCount; $j++)
			{
				
	#			<multistatus xmlns="DAV:">
	#			<response xmlns="DAV:">
	#			 <href>/sjorsdeberekorst1/</href>
	#			 <status>HTTP/1.1 200 OK</status>
	#			</response>
	#			</multistatus>
				my $action = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:action')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				my $href = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:href')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				
				my $fspath = URLDecode($href);
				
				my $successcodes = XMLDOMgetFirstChildByName($requestInstructions->[$j], 'x0:success-codes')->getFirstChild->toString(); # bad bad bad! whaddayathink xml namespaces are for!
				#print ("action: $action, href: $href, success-codes: $successcodes\n");
				
				#setup a new xml node
				my $responsemultistatus = $responsexml->createElement('multistatus');
				$responsemultistatus->setAttribute('xmlns', 'DAV:');
				my $responsemultistatusresponse = $responsexml->createElement('response');
				$responsemultistatusresponse->setAttribute('xmlns', 'DAV:');
				if ($action eq 'DMMKPATH')
					{
					my $hrefelement = $responsexml->createElement('href');
					my $hreftextnode = $responsexml->createTextNode($href);
					$hrefelement->appendChild($hreftextnode);
					$responsemultistatusresponse->appendChild($hrefelement);
					my $statuselement = $responsexml->createElement('status');
					my $statustextnode;
					if ((check_for_dir_backref($fspath)) || ($fspath !~ m/^\/$ruser\//)) { #either there's backref(s) in our uri, or our uri doesn't start with $ruser
						$statustextnode = $responsexml->createTextNode('HTTP/1.1 403 Forbidden');
						}
					else {
						#we really should have/check a response status from recursiveMKdir
						recursiveMKdir($idiskpath, $fspath);
						$statustextnode = $responsexml->createTextNode('HTTP/1.1 201 Created');
						}
					$statuselement->appendChild($statustextnode);
					$responsemultistatusresponse->appendChild($statuselement);
					}
				$responsemultistatus->appendChild($responsemultistatusresponse); # append the 'multistatus' childnode;
				$responserootnode->appendChild($responsemultistatus); # append the 'multistatus' childnode;
			}
	$responsexml->appendChild($responserootnode);
	return ($responsexml->toString());
	}

sub XMLDOMgetFirstChildByName
  { my( $node, $tag)= @_;
    return $node->getElementsByTagName($tag)->[0];
  }
1;