#file:DotMac/WebObjects/Infowoa/wa.pm
#------------------------------------
package DotMac::WebObjects::Infowoa::wa;

use strict;
use warnings;

use CGI::Carp; # for neat logging to the error log
use Apache2::Access ();
use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();#Perl API for Apache subrequests
use Apache2::Const -compile => qw(OK);
use DotMac::CommonCode;
use DotMac::DotMacDB;

use Data::Dumper; # just for testing

use XML::DOM;

use HTTPD::UserAdmin(); # move this to common with auth subs

$DotMac::WebObjects::Infowoa::wa::VERSION = '0.1';

sub handler {
	my $r = shift;
	my $answer;
	carp "WebObjects/Info.woa/wa";
	#carp $r->as_string();
	#carp $r->location();
	#carp $r->document_root();
	# my $user = $r->user;
	#carp $r->method;
	#carp $r->uri;
	
	if ($r->uri eq "/WebObjects/Info.woa/wa/DynamicUI/dotMacPreferencesPaneMessage")
		{
		carp 'executing dotMacPreferencesPaneMessage';
		$answer = dotMacPreferencesPaneMessage($r);
		}
	elsif ($r->uri eq "/WebObjects/Info.woa/wa/Query/retrieveDiskConfiguration")
		{
		carp 'executing retrieveDiskConfiguration';
		$answer = retrieveDiskConfiguration($r);
		}
	elsif ($r->uri eq "/WebObjects/Info.woa/wa/Query/accountInfo")
		{
		carp 'executing QUERYaccountInfo';
		$answer = QUERYaccountInfo($r);
		}
	elsif ($r->uri eq '/WebObjects/Info.woa/wa/XMLRPC/accountInfo')
		{
		carp 'executing XMLRPCaccountinfo';
		$answer = XMLRPCaccountinfo($r);
		}
	elsif ($r->uri eq '/WebObjects/Info.woa/wa/Query/configureDisk')
		{
		carp 'executing configureDisk';
		$answer = configureDisk($r);
		}
	else
		{
		carp "Hi; I'm wa.pm, and I got called with a uri I don't know: ". $r->uri;
		}
	
	my $contentLength = length($answer);
	$r->content_type("text/html");
	$r->header_out('cache-control', 'private');
	$r->header_out('cache-control', 'no-cache');;
	$r->header_out('cache-control', 'no-store');
	$r->header_out('cache-control', 'must-revalidate');
	$r->header_out('cache-control', 'max-age=0');
	$r->header_out('cache-control', 'post-check=0');
	$r->header_out('cache-control', 'pre-check=0');
	#print "expires: Tue, 13 Nov 2007 17:53:06 GMT\n";
	$r->header_out('pragma', 'no-cache');
	$r->header_out('content-length', $contentLength);
	#print "Cneonction: close\n";
	
	#carp "$answer";
	$r->print ($answer);
	return Apache2::Const::OK;
	}

sub retrieveDiskConfiguration {
	my $r = shift;
	my $content;
	my $answer;
	my $username = "";
	my $password = "";
	my $dotmacversion = "";
	if ($r->method eq 'POST')
		{
		my $buf;
		while ($r->read($buf, $r->header_in('Content-Length'))) {
			$content .= $buf;
			}
		}
	#carp $content;
	my(@name_value_array) = split(/;/, $content);
	foreach my $name_value_pair (@name_value_array) {
		chomp ($name_value_pair);
		my($name, $value) = split(/ = /, $name_value_pair);
		if ($name =~ m/username/){ $username = $value; }
		elsif ($name =~ m/password/){ $password = $value; }
		elsif ($name =~ m/version/){ $dotmacversion = $value; }
		}
		$username =~ s/^\"|\"$//g;
		$password =~ s/^\"|\"$//g;

	#carp "username $username, version $dotmacversion";
	# if (DotMac::CommonCode::authen_user($r, $username, $password))
	my $home_dir = $r->dir_config('dotMaciDiskPath') . "/$username";
	my $dmdb = DotMac::DotMacDB->new();
	my $userquota = $dmdb->get_user_quota($username);
	$userquota *= 1024;#we set quota in 1k blocks
	my $quotaUsedBytes = `du -sk $home_dir`; chop($quotaUsedBytes);# query for usage in KiloBytes
	$quotaUsedBytes =~ s/^(\d+)(.*)/$1/;
	$quotaUsedBytes *= 1024;#we get quota used in 1k blocks
	#carp $quotaUsedBytes;
	$r->send_http_header('text/plain');
	$answer = "{
payload = {
	guestReadEnabled = Y;
	guestWriteEnabled = N;
	hasGeneralPassword = N;
	iDiskQuotaInBytes = $userquota;
	iDiskUsedBytes = $quotaUsedBytes;
	relativePath = Public;
};
statusCode = success;
}";
	return $answer;
	}

sub dotMacPreferencesPaneMessage {
	my $r = shift;
	my $content;
	#my $foo = $r->dir_config('foo'); ( PerlSetVar	dotMacUserDB)
	
	if ($r->method eq 'POST')
		{
		my $buf;
		while ($r->read($buf, $r->header_in('Content-Length'))) {
			$content .= $buf;
			}
		}
	carp $content;
	my $username = "";
	my $password = "";
	my $service = "";
	my $systemVersion = "";
	my $dotmacversion = "";
	my $answer;
	my(@name_value_array) = split(/;/, $content);
	foreach my $name_value_pair (@name_value_array) {
		chomp ($name_value_pair);
		my($name, $value) = split(/ = /, $name_value_pair);
		if ($name =~ m/username/){ $username = $value; }
		elsif ($name =~ m/password/){ $password = $value; }
		elsif ($name =~ m/service/){ $service = $value; }
		elsif ($name =~ m/systemVersion/){ $systemVersion = $value; }
		elsif ($name =~ m/version/){ $dotmacversion = $value; }
		}
		$username =~ s/^\"|\"$//g;
		$password =~ s/^\"|\"$//g;
		my $dmdb = DotMac::DotMacDB->new();

	if ($dmdb->authen_user($username, $password))
		{
		warn "user $username is ok to me";
		if ($dotmacversion eq '1')
			{
			$answer = 	"{
messageHTML = \"<html><head></head><body><b>Thanks $username for being a member</b><br>Your account will expire when our server dies, but you'll be probably dead by then.<br>Need additional email or iDisk space? Feel free to buy me some harddisks.<br><br>\n<div style='position:absolute; left:0px; bottom:0px;'><IMG src='http://www.walinsky.com/dotwalinskysmall.png' alt='dotwalinsky' width='50' height='61' /></div><div style='position:absolute; right:0px; bottom:0px;'><input type=submit style='font-size:18px' value='Donate&nbsp;' onclick='document.location.href=\\\"https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=walinskydotcom%40hotmail%2ecom&item_name=walinskydotcom&item_number=dotmac&no_shipping=0&no_note=1&tax=0&currency_code=EUR&lc=US&bn=PP%2dDonationsBF&charset=UTF%2d8\\\"'></div></body></html>\"; 
service = dotMacPreferencesPaneMessage; 
servicesAvailable = (iDisk, iSync, Backup, iChatEncryption, Email, WebHosting); 
statusCode = success; 
version = 1; 
}";
			}
		else # Leopard version# = 2
			{
			my $iDiskStorageInMB = $dmdb->get_user_quota($username);
			$iDiskStorageInMB /= 1024;#we set quota in 1k blocks and  report them in MB
			my $messageHTML = "<html><head><title></title></head><body><table cellspacing='0' cellpadding='0' border='0'><tr><td><table cellspacing='0' cellpadding='0' border='0'><tr><td>Account Type:</td><td width='8'></td><td><b>Regular</b></td></tr><tr><td height='8' colspan='3'></td></tr><tr><td>Member Since:</td><td width='8'></td><td><b>%@</b></td></tr><tr><td height='8' colspan='3'></td></tr><tr><td>Mail Storage:</td><td width='8'></td><td><b>%@</b></td></tr><tr><td height='8' colspan='3'></td></tr><tr><td>iDisk Storage:</td><td width='8'></td><td><b>%@</b></td></tr></table></td><td width='20'></td></tr><tr><td height='16' colspan='2'></td></tr><tr><td>Your account will expire when our server dies, but you'll be probably dead by then.</td><td width='20'></td></tr><tr><td height='16' colspan='2'></td></tr><tr><td><input type=submit style='font-size:18px' value='&nbsp;Account Details&nbsp;' onclick='document.location.href=\\\"https://www.mac.com/WebObjects/Account.woa\\\"'></td><td width='20'></td></tr><tr><td height='10' colspan='2'></td></tr><tr><td>To change your password and manage your billing information, view your account details.</td><td width='20'></td></tr><tr><td><input type=submit style='font-size:18px' value='&nbsp;Donate&nbsp;' onclick='document.location.href=\\\"https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=walinskydotcom\@hotmail.com&item_name=walinskydotcom&item_number=dotmac&no_shipping=0&no_note=1&tax=0&currency_code=EUR&lc=US&bn=PP%2dDonationsBF&charset=UTF%2d8\\\"'></td><td width='20'></td></tr></table><div style='position:absolute; right:0px; bottom:0px;'><IMG src='http://www.walinsky.com/dotwalinskysmall.png' alt='dotwalinsky' width='50' height='61' /></div></body></html>";
			$answer = 	qq±{
canBuyMore = N; 
createDateString = "2007-10-05"; 
iDiskStorageInMB = $iDiskStorageInMB; 
mailStorageInMB = 0; 
messageHTML = "$messageHTML"; 
publicFolder = "http://idisk.mac.com/$username-Public"; 
service = dotMacPreferencesPaneMessageVersion2; 
servicesAvailable = (iDisk, iSync, SharingCertificate, Email, WebHosting, BTMM); 
statusCode = success; 
substitutionOrder = (createDateString, mailStorageInMB, iDiskStorageInMB); 
upgradeURL = "http://www.mac.com/"; 
version = 2; 
}±;
			}
		}
	else
		{
		$answer = "{
forgottenPasswordURL = \"http://www.walinsky.com/dotmac/\"; 
statusCode = authorizationFailed; 
}";
		}
	return $answer;
	}

sub XMLRPCaccountinfo {
	my $r = shift;
	my ($content, $answer);
	#my $foo = $r->dir_config('foo'); ( PerlSetVar	dotMacUserDB)

	if ($r->method eq 'POST')
		{
		my $buf;
		while ($r->read($buf, $r->header_in('Content-Length'))) {
			$content .= $buf;
			}
		}
	#carp $content;
	
	# instantiate parser
	my $xp = new XML::DOM::Parser();
	# parse and create tree
	my $doc = $xp->parse($content);
	
	# get root node
	my $root = $doc->getDocumentElement();
	my $strings = $root->getElementsByTagName("string");
	my $n = $strings->getLength;
	
	# we could authen user; but I see no reason why, now
	
	for (my $i = 0; $i < $n; $i++)
		{
		my $string = $strings->item ($i)->getFirstChild()->getData;
		if ($string eq "servicesAvailable") {
			$answer = "<?xml version='1.0'?><methodResponse><params><param><value><struct><member><name>servicesAvailable</name>
<value><array><value><string>iDisk</string></value><value><string>iSync</string></value><value><string>Email</string></value>
<value><string>WebHosting</string></value><value><string>Backup</string></value><value><string>BTMM</string></value></array></value></member></struct></value></param></params></methodResponse>";
			}
		elsif ($string eq "daysLeftUntilExpiration") {
			$answer = "<?xml version='1.0'?>
<methodResponse><params><param><value><struct>
<member><name>daysLeftUntilExpiration</name><value><int>365</int></value></member>
</struct></value></param></params></methodResponse>";
			}
		}
	return $answer;
	}

sub QUERYaccountInfo {
	my $r = shift;
	my ($content, $answer);
	#my $foo = $r->dir_config('foo'); ( PerlSetVar	dotMacUserDB)

	if ($r->method eq 'POST')
		{
		my $buf;
		while ($r->read($buf, $r->header_in('Content-Length'))) {
			$content .= $buf;
			}
		}
	#carp $content;
	
	$answer = "{
    payload = {servicesAvailable = (iDisk, iSync, SharingCertificate, Email, WebHosting); }; 
    statusCode = success; 
}";
	return $answer;
	}

sub configureDisk {
	my $r = shift;
	my ($content, $answer);
	#my $foo = $r->dir_config('foo'); ( PerlSetVar	dotMacUserDB)

	if ($r->method eq 'POST')
		{
		my $buf;
		while ($r->read($buf, $r->header_in('Content-Length'))) {
			$content .= $buf;
			}
		}
	carp $content;
	my $authenticatedReadEnabled ='';
	my $authenticatedWriteEnabled = '';
	my $generalPassword = '';
	my $guestReadEnabled = '';
	my $guestWriteEnabled = '';
	my $username = '';
	my $password = '';
	my $dotmacversion = '';
	my(@name_value_array) = split(/;/, $content);
	foreach my $name_value_pair (@name_value_array) {
		chomp ($name_value_pair);
		my($name, $value) = split(/ = /, $name_value_pair);
		if    ($name =~ m/authenticatedReadEnabled/) { $authenticatedReadEnabled = $value; }
		elsif ($name =~ m/authenticatedWriteEnabled/){ $authenticatedWriteEnabled = $value; }
		elsif ($name =~ m/generalPassword/){ $generalPassword = $value; }
		elsif ($name =~ m/guestReadEnabled/){ $guestReadEnabled = $value; }
		elsif ($name =~ m/guestWriteEnabled/){ $guestWriteEnabled = $value; }
		elsif ($name =~ m/username/){ $username = $value; }
		elsif ($name =~ m/password/){ $password = $value; }
		elsif ($name =~ m/version/){ $dotmacversion = $value; }
		}
		#carp $authenticatedWriteEnabled;
		#carp $guestReadEnabled;
		#carp $generalPassword;
	
	if ($guestReadEnabled eq '1') {
		if ($guestWriteEnabled eq '1') {
			$answer = "{
    payload = {
        guestReadEnabled = Y; 
        guestWriteEnabled = Y; 
        hasGeneralPassword = N; 
        relativePath = Public; 
    }; 
    statusCode = success; 
}";
		} elsif ($guestWriteEnabled eq '0') {
			$answer = "{
    payload = {
        guestReadEnabled = Y; 
        guestWriteEnabled = N; 
        hasGeneralPassword = N; 
        relativePath = Public; 
    }; 
    statusCode = success; 
}";			
		}
	} elsif ($guestReadEnabled eq '0') {
		if ($authenticatedWriteEnabled eq '1') {
			# this for when public password gets set
			$answer = '{
    payload = {
        authenticatedReadEnabled = Y; 
        authenticatedWriteEnabled = Y; 
        guestReadEnabled = N; 
        guestWriteEnabled = N; 
        hasGeneralPassword = Y; 
        relativePath = Public; 
    }; 
    statusCode = success; 
}';
		} elsif ($authenticatedWriteEnabled eq '0') {
			$answer = '{
    payload = {
        authenticatedReadEnabled = Y; 
        authenticatedWriteEnabled = N; 
        guestReadEnabled = N; 
        guestWriteEnabled = N; 
        hasGeneralPassword = Y; 
        relativePath = Public; 
    }; 
    statusCode = success; 
}';
		}
	}
	return $answer;
}
1;
