#file:DotMac/WebObjects/RequestRouterwoa/wa.pm
#------------------------------------
package DotMac::WebObjects::RequestRouterwoa::wa;

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

use Data::Dumper; # just for testing

use XML::DOM;

use HTTPD::UserAdmin(); # move this to common with auth subs

$DotMac::WebObjects::RequestRouterwoa::wa::VERSION = '0.1';


sub handler {
	my $r = shift;
	my $answer;
	#carp $r->as_string();
	#carp $r->location();
	#carp $r->document_root();
	# my $user = $r->user;
	#carp $r->method;
	#carp $r->uri;
	
	if ($r->uri eq "/WebObjects/RequestRouter.woa/wa/HomePagePublishing/accountInfo/")
		{
		carp 'executing dotMacPreferencesPaneMessage';
		$answer = accountInfo($r);
		}
	elsif ($r->uri eq "/WebObjects/Info.woa/wa/Query/retrieveDiskConfiguration")
		{
		carp 'Hi, I am just a placeholder - this should not happen';
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

sub accountInfo {
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
	#carp "username $username, version $dotmacversion";
	# if (DotMac::CommonCode::authen_user($r, $username, $password))
	my $home_dir = $r->dir_config('dotMaciDiskPath') . "/$username";
	my $userquota = DotMac::CommonCode::get_user_quota($r, $username);
	$userquota *= 1024;#we set quota in 1k blocks
	my $quotaUsedBytes = DotMac::CommonCode::get_user_quota_used($r, $username);# query for usage in KiloBytes
	$quotaUsedBytes *= 1024;#we get quota used in 1k blocks
	#carp $quotaUsedBytes;
	$r->send_http_header('text/plain');
	$answer = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
<key>iDiskFreeBytes</key>
<string>$quotaUsedBytes</string>
<key>sites</key>
<array>
<string>$username</string>
</array>
<key>success</key>
<string>yes</string>
</dict>
</plist>";
	return $answer;
	}


1;
