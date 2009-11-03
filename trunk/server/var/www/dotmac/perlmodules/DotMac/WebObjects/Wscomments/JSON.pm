#------------------------------------
package DotMac::WebObjects::Wscomments::JSON;

use strict;
use warnings;

use CGI::Carp; # for neat logging to the error log
use Apache2::Access ();
use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();#Perl API for Apache subrequests
use Apache2::Const -compile => qw(OK);
use Apache::Session::File;
use DotMac::CommonCode;

use XML::LibXML;
use JSON;
use File::Spec;
use File::Basename;
use DateTime;

use HTTPD::UserAdmin(); # move this to common with auth subs

use DotMac::WebObjects::Wscomments;

$DotMac::WebObjects::Wscomments::JSON::VERSION = '0.1';

sub handler {
	my $r = shift;

my $path_info = $r->path_info;
my $fullfilename = $r->filename();
my $uri = $r->uri();
my $location = $r->location();
warn("Kicking in uri [$uri] fullfilename [$fullfilename] path info [$path_info] location [$location]");
	$uri =~ s|/(\w+)\.js||; # Remove the (apache-rewritten) query-part of the url
	my $method = $1;

	#WORKAROUND: there's something wrong with the web.mac.com url's, they have to contain a couple extra steps. Remove this when it's fixed
	$uri =~ s|/Web/Sites||;

	my $dirname = (fileparse($uri))[1];
	my $filename = (fileparse($uri))[0];

	#FIXME: This is a bit ugly, decide if the DB should store the file path or the publically accessible path
	my @uriparts = File::Spec->splitdir($dirname);
	shift(@uriparts); # Remove the root dir
	my $user = shift(@uriparts);
	unshift(@uriparts, 'Web', 'Sites');
	# uriparts is now Web/Sites/$rest_of_path_except_filename
	$uri = File::Spec->catfile('', $user, @uriparts, $filename);
	$dirname = File::Spec->catdir('', $user, @uriparts);

	$r->log->info("user = $user\nuriparts = ".File::Spec->catfile(@uriparts)."\nfilename=$filename\ndirname=$dirname");

	# Get the data
	$r->log->info("Fetching properties for first path above $dirname");
	my $dirproperties = DotMac::WebObjects::Wscomments::getCommentPropertiesAbove($user, $dirname);
	$r->log->info("dirproperties: ".$dirproperties->toString());
	$r->log->info("Fetching properties for resource $uri");
	my $resourceproperties = DotMac::WebObjects::Wscomments::getCommentProperties($user, $uri);
	$r->log->info("resourceproperties: ".$resourceproperties->toString());
	$r->log->info("Fetching comments for $uri");
	my $comments = DotMac::WebObjects::Wscomments::getCommentsForPath($user, $uri);
	$r->log->info("comments: ".$comments->toString());

	# Get the relevant parts and output JSON
	my $data;
	if( $method eq 'summary' ){
		$data = generateSummaryData($filename, $dirproperties, $resourceproperties, $comments);
	} elsif( $method eq 'entry' ){
		$data = generateEntryData($dirproperties, $resourceproperties, $comments);
	} else {
		die "DotMac::WebObjects::Wscomments::JSON called with illegal method $method";
	}

	# Return response
	#$r->headers_out->add('Content-Type' => "textxml"); # Eeeew. Dear god please tell me I won't have to return something so blatantly wrong!
	$r->headers_out->add('Cache-Control' => "max-age=60, must-revalidate");

	$r->print($data);

	return Apache2::Const::OK;
}

sub generateSummaryData( $$$$ ){
	my $filename = shift;
	my $dirproperties = shift;
	my $resourceproperties = shift;
	my $comments = shift;

	my $data;

	$data .= "entryURLs['$filename'].comments = " . ( $dirproperties->findvalue('/methodResponse/params/param/value/struct/member[name="userInfoConfig"]/value/struct/member[name="commentingHasBeenEnabled"]/value/string') =~ /yes|true|1/i ? 'true' : 'false' ) . ";\n";
	my @comments = $comments->findnodes('/methodResponse/params/param/value/array/data/value');
	$data .= "entryURLs['$filename'].count = " . ($#comments < 0 ? 0 : $#comments) . ";\n";

	return $data;
}

sub generateEntryData( $$$ ){
	my $dirproperties = shift;
	my $resourceproperties = shift;
	my $comments = shift;

	my %data;

	$data{commentsEnabled} = $dirproperties->findvalue('/methodResponse/params/param/value/struct/member[name="userInfoConfig"]/value/struct/member[name="commentingHasBeenEnabled"]/value/string');
	if( $data{commentsEnabled} =~ /yes|true|1/i ){
		$data{commentsEnabled} = 'true';
	} else {
		$data{commentsEnabled} = 'false';
	}

	#TODO: I have no idea what this field is
	$data{status} = 0;

	$data{items} = [];
	foreach my $comment ( $comments->findnodes('/methodResponse/params/param/value/array/data/value') ){
		my %commentdata;
		foreach my $param ( $comment->findnodes('struct/member') ){
			my $paramname = $comment->findvalue('name')->textContent();
			my $paramvalue = $comment->findvalue('value')->textContent();

			# Convert date/time fields to human-readable format, using the format and timezone from the properties
			if( $paramname =~ /Date/ ){
				my $dateformat = $resourceproperties->findvalue('/methodResponse/params/param/value/struct/member[name="dateFormat"]/value')->textContent();
				my $timezone = $resourceproperties->findvalue('/methodResponse/params/param/value/struct/member[name="timezone"]/value')->textContent();
				$paramvalue = DateTime->from_epoch(epoch => $paramvalue, time_zone => $timezone)->strftime($dateformat);
			}

			$commentdata{$paramname} = $paramvalue;
		}

		push(@{$data{items}}, \%commentdata);
	}

	my $json = new JSON(); # Note: don't add pretty-printing, it breaks the js.
	my $data = $json->objToJson(\%data);
	$data = "data($data);";
	return $data;
}

1;
