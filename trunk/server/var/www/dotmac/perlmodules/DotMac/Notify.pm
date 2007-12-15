#file:DotMac/Notify.pm
#----------------------

## Copyright (C) 2007 walinsky
## This program is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the 
## Free Software Foundation; either version 2 of the License, or (at your option)
## any later version.

##DotMac::Notify provides services for notify.mac.com
package DotMac::Notify;

use strict;
use warnings;

use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK);

$DotMac::Notify::VERSION = '0.1';

use XML::DOM;
use CGI::Carp; # for neat logging to the error log
use DotMac::CommonCode;

sub handler {
	my $r = shift;
	my $answer;

	if ($r->uri eq "/notify")
		{
		carp 'executing Notify::notify';
		$answer = notify($r);
		}
	elsif ($r->uri eq "/subscribe")
		{
		carp 'executing Notify::subscribe';
		$answer = subscribe($r);
		}
	else
		{
		carp 'Notify found a new kid on the block at: '.$r->uri;
		}
	my $contentLength = length($answer);
	$r->content_type("text/xml");
	$r->header_out('content-length', $contentLength);
	$r->print ($answer);
	return Apache2::Const::OK;
	}

sub notify {
	my $r = shift;
	my ($my_data, $answer);
	my $TimeStamp = time();
	if ($r->method eq 'POST')
		{
		my $buf;
		while ($r->read($buf, $r->header_in('Content-Length'))) {
			$my_data .= $buf;
			}
		}
	carp $my_data;
	
	$TimeStamp = "0"; # really don't know what we should give - so just set it to 0 now
	$answer = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><methodResponse><params><param><value><struct><member><name>resultCode</name><value>Success</value></member><member><name>timestamp</name><value>".$TimeStamp."</value></member><member><name>resultBody</name><value><array><data></data></array></value></member></struct></value></param></params></methodResponse>";

	return $answer;
	}

sub subscribe {
	my $r = shift;
	my ($my_data, $answer);
	my $TimeStamp = time();
	if ($r->method eq 'POST')
		{
		my $buf;
		while ($r->read($buf, $r->header_in('Content-Length'))) {
			$my_data .= $buf;
			}
		}
	carp $my_data;
	
	# instantiate parser
	my $xp = new XML::DOM::Parser();
	# parse and create tree
	my $doc = $xp->parse($my_data);
	# get root node
	my $root = $doc->getDocumentElement();
	my $strings = $root->getElementsByTagName("methodName");
	my $n = $strings->getLength;
	for (my $i = 0; $i < $n; $i++)
	 {
		my $string = $strings->item ($i)->getFirstChild()->getData;
		if ($string eq "subscription.list") {
			$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><methodResponse><params><param><value><struct><member><name>resultCode</name><value>Success</value></member><member><name>timestamp</name><value>$TimeStamp</value></member><member><name>resultBody</name><value><array><data></data></array></value></member></struct></value></param></params></methodResponse>";
			}
		elsif ($string eq "subscription.add") {
			$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><methodResponse><params><param><value><struct><member><name>resultCode</name><value>Success</value></member><member><name>timestamp</name><value>$TimeStamp</value></member><member><name>resultBody</name><value><array><data><value>Success</value></data></array></value></member></struct></value></param></params></methodResponse>";
			}
		elsif ($string eq "subscription.changedtags") {
			$answer = "<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?><methodResponse><params><param><value><struct><member><name>resultCode</name><value>Success</value></member><member><name>timestamp</name><value>$TimeStamp</value></member><member><name>resultBody</name><value><array><data></data></array></value></member></struct></value></param></params></methodResponse>";
			}
		else
			{
			carp "subscribe was called with command: $string; don't know how to handle that";
			}
	 }

	return $answer;
	}

1;