#file:DotMac/DMXWebdavMethods.pm
#--------------------------------
package DotMac::DMXWebdavMethods;

use strict;
use warnings;

use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::SubRequest ();
use Data::Dumper;
use Apache2::Const -compile => qw(OK HTTP_CREATED HTTP_NO_CONTENT HTTP_BAD_REQUEST DONE :log);
use CGI::Carp;
use DotMac::CommonCode;

sub handler
	{
	carp "DMMKPATH_handler active!";
	my $r = shift;
	my $rmethod = $r->method;
	my $user = $r->user;
	my $XWebdavMethod = $r->header_in('X-Webdav-Method');
	if ($XWebdavMethod eq 'DMMKPATH')
		{
		carp "DMMKPATH_handler DMMKPATH!";
		my $dotMaciDiskPath = $r->dir_config('dotMaciDiskPath');
		DotMac::CommonCode::recursiveMKdir($dotMaciDiskPath, $r->uri);
		$r->content_type('text/plain');
		$r->print("");
		
		return Apache2::Const::OK;
		}
	}
	
sub dmmkpath {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: dmmkpath");
	$r->print(DotMac::CommonCode::dmmkpath_response(DotMac::CommonCode::recursiveMKCOL( $r)));
	$r->content_type('text/xml');
	$r->status(207);
	return Apache2::Const::OK;
}

sub dmpatchpaths {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: dmpatchpaths");
	my $content;
	my $buf;
	my $content_length = $r->header_in('Content-Length');
	if ($content_length > 0) {
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
	}
	DotMac::CommonCode::dmpatchpaths_response($r,DotMac::CommonCode::dmpatchpaths_request( $r, $content));
	$r->content_type('text/xml');
	$r->status(207);
	return Apache2::Const::OK;
}			



sub dmputfrom { #this shouldn't be used anymore... this was transferred to the DMTransHandler
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: dmputfrom");
	my $dotMaciDiskPath = $r->dir_config('dotMaciDiskPath');
	my $XSourceHref = DotMac::CommonCode::URLDecode($r->header_in('X-Source-Href'));
	my $ruri= DotMac::CommonCode::URLDecode($r->uri);
	my $ruser=$r->user;
	if ((DotMac::CommonCode::check_for_dir_backref($ruri)) || (DotMac::CommonCode::check_for_dir_backref($XSourceHref))) {
		$rlog->error("path contained a back reference: ".DotMac::CommonCode::check_for_dir_backref($ruri)." ".DotMac::CommonCode::check_for_dir_backref($XSourceHref));
		return Apache2::Const::HTTP_BAD_REQUEST;
	}	
	if (($ruri =~ m/^\/$ruser\//) && ($XSourceHref =~ m/^\/$ruser\//)) {
		$logging =~ m/Sections/&&$rlog->info("Calling movefile $dotMaciDiskPath $XSourceHref $ruri"); 
		DotMac::CommonCode::movefile($dotMaciDiskPath, $XSourceHref, $ruri);
		#$r->content_type('text/plain');
		$r->print("");
		return Apache2::Const::HTTP_NO_CONTENT;
	} else {
		$r->print(" ");			
		$rlog->error("Directory path didn't match the user User:$ruser URI:$ruri Sourcehref:$XSourceHref");
		return Apache2::Const::HTTP_BAD_REQUEST;
	}
}
sub dmmkpaths {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: dmmkpaths");

	#DotMac::CommonCode::dmMKpaths($dotMaciDiskPath, $r->uri);
	# send multistatus header:
	# HTTP/1.1 207 Multi-Status
	my $buf;
	my $content;
	my $content_length = $r->header_in('Content-Length');
	if ($content_length > 0) {
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
		carp $content;
	}
	$r->print(DotMac::CommonCode::dmmkpath_response(DotMac::CommonCode::dmmkpath_request( $r, $content)));
	$r->content_type('text/xml;charset=utf-8');
	$r->content_type('text/xml');
	$r->status(207);
	return Apache2::Const::OK;
}

sub dmoverlay {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: dmoverlay");
	return Apache2::Const::OK;
}

sub truthget {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: truthget");
	return Apache2::Const::OK;
}
sub acl {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
	$logging =~ /Sections/&&$rlog->info("Content Handler: acl");
	my $dotMaciDiskPath = $r->dir_config('dotMaciDiskPath');

	# we might want to check if the uri starts with username ;)
	#DotMac::CommonCode::recursiveMKdir($dotMaciDiskPath, $r->uri);
	$r->content_type('text/plain');
	$r->print("");
	return Apache2::Const::OK;
}

1;