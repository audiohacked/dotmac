#file:DotMac/DMFixupHandler.pm
#--------------------------------
package DotMac::DMFixupHandler;

use strict;
use warnings;

use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::Log;

use Apache2::Const -compile => qw(OK HTTP_CREATED HTTP_NO_CONTENT HTTP_BAD_REQUEST DONE :log);
use APR::Const    -compile => qw(:error SUCCESS);
use CGI::Carp;
use DotMac::CommonCode;
use DotMac::DMXWebdavMethods;
use Data::Dumper;

#my %exts = (
#  cgi => ['perl-script',     \&cgi_handler],
#  pl  => ['modperl',         \&pl_handler ],
#  tt  => ['perl-script',     \&tt_handler ],
#  txt => ['default-handler', undef        ],
#);

sub handler
	{
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;

	
	my $rmethod = $r->method;
	my $user = $r->user;
	my $userAgent = $r->headers_in->{'User-Agent'} || '';
	chomp($userAgent);
	my $ifHeader = $r->headers_in->{'If'} || '';
	$logging&&$rlog->info(join(':',"DMFixupHandler", $r->get_server_name(), $r->get_server_port(),$userAgent,$rmethod,$r->main&&"Subrequest",$ifHeader,$r->uri,$r->user, $r->headers_in->{'X-Webdav-Method'}));

	$logging =~ m/Headers/&&$rlog->info($r->as_string());
	if (($rmethod eq "PUT") | ($rmethod eq "MKCOL")  | ($rmethod eq "MOVE") | ($rmethod eq "POST") | ($rmethod eq "LOCK") | ($rmethod eq "DELETE") | ($rmethod eq "UNLOCK")){
		

		if ($userAgent =~ m/^DotMacKit(.*)SyncServices$/) {
			$logging =~ m/Sections/&&$rlog->info("In the DotMacKit SyncServices Section");
			my $ifheaderUri;
			my $clientsfolder = "/$user/Library/Application Support/SyncServices/Clients";# PUT
			my $schemasfolder = "/$user/Library/Application Support/SyncServices/Schemas";# MKCOL
			if (($rmethod eq "PUT") && ($r->uri =~ m/^$clientsfolder(.*).client$/)) {
				$logging =~ m/Sections/&&$rlog->info("Put and SyncServices/Clients Section");
				$r->headers_in->{'If'} = "<$clientsfolder> $ifHeader";
				}
			# LOCK /walinsky/Library/Application%20Support/SyncServices/Schemas/com.apple.Bookmarks/
			# PUT /walinsky/Library/Application%20Support/SyncServices/Schemas/com.apple.Bookmarks/CB18B05E-248E-4117-8C05-AF6AF61E429100001.temp
			# UNLOCK /walinsky/Library/Application%20Support/SyncServices/Schemas/com.apple.Bookmarks/
			elsif (($rmethod eq "PUT") && ($r->uri =~ m/^$schemasfolder\/(.*)\//)) {
				$logging =~ m/Sections/&&$rlog->info("In the PUT and SyncServices/Schemas Section");
				my $childfolder = $1;
				$r->headers_in->{'If'} = "<$schemasfolder/$childfolder> $ifHeader";
				}
			# (<opaquelocktoken:a3e612de-bcc3-49bd-9dcc-4369bc1c17b1>)(<opaquelocktoken:a3e612de-bcc3-49bd-9dcc-4369bc1c17b1>)
			elsif (($rmethod eq "MOVE") && ($r->uri =~ m/^$schemasfolder\/(.*)\//)) {
				$logging =~ m/Sections/&&$rlog->info("In the MOVE and SyncServices/Schemas Section");
				my $childfolder = $1;
				my $rUri = $r->uri;
				my $rDest = $r->headers_in->{'Destination'};
				$logging =~ m/Sections/&&$rlog->info("Destination header: $rDest");
				# when moving, 2 exactly the same locktokens are specified
				# LOCK /walinsky/Library/Application%20Support/SyncServices/Schemas/com.apple.Contacts/
				# PUT /walinsky/Library/Application%20Support/SyncServices/Schemas/com.apple.Contacts/CB18B05E-248E-4117-8C05-AF6AF61E429100001.temp
				# MOVE /walinsky/Library/Application%20Support/SyncServices/Schemas/com.apple.Contacts/CB18B05E-248E-4117-8C05-AF6AF61E429100001.temp HTTP/1.1" 502 (Bad Gateway)
				if ($ifHeader =~ m/^\(<(.*?)>\)\(<(.*?)>\)/) {
					$r->headers_in->{'If'} = "<$schemasfolder/$childfolder> (<$2>)";
					$r->headers_in->{'Destination'} =~ s{^http://idisk.mac.com}{https://idisk.mac.com}s; # we don't want a  HTTP/1.1" 502 (Bad Gateway)
					}
				
				}
			elsif (($rmethod eq "MKCOL") && ($r->uri =~ m/^$schemasfolder/)) {
				if ($ifHeader) {
					$r->headers_in->{'If'} = "<$schemasfolder> $ifHeader";
					$logging =~ m/Locks/&&$rlog->info("If header originally $ifHeader, now ".$r->headers_in->{'If'});
					}
				}
			
			#carp $r->headers_in->{'If'};
			}
		elsif ($userAgent =~m/^DotMacKit(.*).syncinfo/)
			{
			if (($rmethod eq "PUT") && ($r->uri =~ m/^\/$user\/Library\/Keychains\/.syncinfo\/(.*).plist$/))
				{
				$logging =~ m/Sections/&&$rlog->info("UserAgent: DotMacKit .syncinfo and method PUT");
				$r->headers_in->{'If'} = "</$user/Library/Keychains/.syncinfo> $ifHeader";
				$logging =~ m/Locks/&&$rlog->info("If header originally $ifHeader, now ",$r->headers_in->{'If'});
				}
			}
		elsif ($userAgent =~m/^PubSub-DotMacKit-Client/)
			{
			if (($rmethod eq "PUT") && ($r->uri =~ m/^\/$user\/Library\/Application Support\/PubSub\/(.*).chunx$/))
				{
				$r->headers_in->{'If-None-Match'} = "";
				}
			}
		elsif ($userAgent =~m/^DotMacKit-like, File-Sync-Direct/)
			{
#			carp $r->as_string();
			# LOCK /walinsky/.FileSync
			my $dotFilesyncFolder = "/$user/.FileSync";
			if (($rmethod eq "MOVE") && ($r->headers_in->{'If'}) && ($r->headers_in->{'If'} !~ m/<.*> \(<.*>\)/)) { # =~ m/^http:\/\/idisk.mac.com$dotFilesyncFolder/)) {
				$r->headers_in->{'If'} = "<$dotFilesyncFolder> $ifHeader";
				$logging =~ m/Locks/&&$rlog->info("If header originally $ifHeader, now ".$r->headers_in->{'If'});
				}
			elsif (($rmethod eq "LOCK") && ($r->headers_in->{'If-Match'})) { # ugly! - should also test for locking $dotFilesyncFolder itself - we get requests for lock (refresh) on exact match
				$r->headers_in->{'If-Match'} = "*";
				}
			elsif (($rmethod eq "LOCK") && ($r->headers_in->{'If'}) && ($r->uri =~ m/$dotFilesyncFolder/)) { 
				$r->headers_in->{'If'} = "<$dotFilesyncFolder> $ifHeader";
				$logging=~ m/Sections/&&$rlog->info("Match Lock + .filesync + if header");
				$logging =~ m/Locks/&&$rlog->info("If header originally $ifHeader, now ".$r->headers_in->{'If'});
				
				}				
			elsif (($rmethod eq "PUT") && ($r->uri =~ m/^$dotFilesyncFolder/)) {
				$r->headers_in->{'If'} = "<$dotFilesyncFolder> $ifHeader";
				$logging =~ m/Locks/&&$rlog->info("If header originally $ifHeader, now ".$r->headers_in->{'If'});
				}
			elsif (($rmethod eq "DELETE") && ($r->headers_in->{'If'})) {
				my $rUri = $r->uri;
				$r->headers_in->{'If'} = "<$rUri> $ifHeader";
				$logging =~ m/Locks/&&$rlog->info("If header originally $ifHeader, now ".$r->headers_in->{'If'});
				}
			elsif ($rmethod eq "MKCOL") {
				my $rUri = $r->uri;
				$rUri =~ s|/\Z(?!\n)|| unless $rUri eq "/"; # strip possible trailing slash
				if ($ifHeader) {
					$r->headers_in->{'If'} = "<$rUri> $ifHeader";
					$logging =~ m/Locks/&&$rlog->info("If header originally $ifHeader, now ".$r->headers_in->{'If'});
					}
			}
			elsif ($rmethod eq "POST") {
				# *sigh*
				# X-Webdav-Method: DMMKPATH
				# X-Webdav-Method: DMPUTFROM
				my $XWebdavMethod = $r->header_in('X-Webdav-Method');
				my $buf;
				my $content;
				my $content_length = $r->header_in('Content-Length');
				if ($content_length > 0)
					{
					while ($r->read($buf, $content_length)) {
						$content .= $buf;
						}
					$logging =~ m/Body/&&$rlog->info("Content from POST: $content");
					}
				if (($XWebdavMethod) && ($XWebdavMethod eq 'DMMKPATH'))
					{
#					carp "setting perlresponsehandler to DMMKPATH_handler";
					$r->handler('perl-script');
					$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::dmmkpath);
				} elsif (($XWebdavMethod) && ($XWebdavMethod eq 'DMPUTFROM')) {
					carp "setting perlresponsehandler to DMPUTFROM_handler";
					$r->handler('perl-script');
					$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::dmputfrom);
				}
				}
			}
		elsif ($userAgent =~m/^DotMacKit-like, Mirror-Agent-Direct/)
			{
			if ($rmethod eq "MOVE")	# dotmac first lock target file; then locks,puts,unlocks tmp file; and then MOVEs the temp file to the locked target file
									# the specified locktoken should be include the url for the target file
				{
				my $destFile = $r->headers_in->{'Destination'};
				$r->headers_in->{'If'} = "<$destFile> $ifHeader";
				$logging =~ m/Locks/&&$rlog->info("If header originally $ifHeader, now ".$r->headers_in->{'If'});
				}
			}
		elsif ($userAgent =~m/^DotMacKit(.*)Lite(.*)iWeb/) # iWeb Publishing #DotMacKit-E-3Lite46 (10.4.9; iweb) iWeb-local-build-20071223
			{
			if ($rmethod eq "POST") {
				# *sigh*
				# X-Webdav-Method: DMMKPATH
				# X-Webdav-Method: DMPUTFROM
				carp $r->as_string();
				my $XWebdavMethod = $r->header_in('X-Webdav-Method');
				if ($XWebdavMethod)
					{
					if ($XWebdavMethod eq 'ACL')
						{
						#my $buf;
						#my $content;
						#my $content_length = $r->header_in('Content-Length');
						#if ($content_length > 0)
						#	{
						#	while ($r->read($buf, $content_length)) {
						#		$content .= $buf;
						#		}
						#	carp $content;
						#	}
						carp "setting perlresponsehandler to ACL_handler";
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::acl);
						}
					elsif ($XWebdavMethod eq 'DMMKPATHS')
						{
						carp "setting perlresponsehandler to DMMKPATHS_handler";
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::dmmkpaths);
						}
					elsif ($XWebdavMethod eq 'DMOVERLAY')
						{
						carp $r->as_string();
						#carp "setting perlresponsehandler to DMOVERLAY_handler";
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::dmoverlay);
						}
					elsif ($XWebdavMethod eq 'DMPATCHPATHS') {
						$rlog->info("Matched DMPATCHPATHS");
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::dmpatchpaths);
					}
					elsif ($XWebdavMethod eq 'SETREDIRECT')
						{
						my $buf;
						my $content;
						my $content_length = $r->header_in('Content-Length');
						if ($content_length > 0)
							{
							while ($r->read($buf, $content_length)) {
								$content .= $buf;
								}
							$logging =~ m/Body/&&$rlog->info("Content from POST: $content");			
							}
						carp "setting perlresponsehandler to SETREDIRECT_handler";
						#$r->handler('perl-script');
						#$r->set_handlers(PerlResponseHandler => \&acl_handler);
						}
					}
				}
			elsif ($rmethod eq "MOVE") {
				my $sitesfolder = "/$user/Web/Sites";
				$r->headers_in->{'If'} = "<$sitesfolder> $ifHeader";
			}
				
			elsif ($rmethod eq "PUT") {
				carp $r->as_string();
				my $sitesfolder = "/$user/Web/Sites";
				# LOCK /walinsky/Web/Sites
				$r->headers_in->{'If'} = "<$sitesfolder> $ifHeader";
				}
			}
		
		elsif ($userAgent =~m/^DotMacKit(.*)Lite(.*)iPho/) # iWeb Publishing #DotMacKit-E-3Lite46 (10.4.9; iweb) iWeb-local-build-20071223
			{
			$logging =~ m/Sections/&&$rlog->info("Matched DotMacKit iPho");
			if ($rmethod eq "POST") {
				# *sigh*
				# X-Webdav-Method: DMMKPATH
				# X-Webdav-Method: DMPUTFROM
				carp $r->as_string();
				my $XWebdavMethod = $r->header_in('X-Webdav-Method');
				if ($XWebdavMethod)
					{
					if ($XWebdavMethod eq 'ACL')
						{
						#my $buf;
						#my $content;
						#my $content_length = $r->header_in('Content-Length');
						#if ($content_length > 0)
						#	{
						#	while ($r->read($buf, $content_length)) {
						#		$content .= $buf;
						#		}
						#	carp $content;
						#	}
						carp "setting perlresponsehandler to ACL_handler";
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::acl);
						}
					elsif ($XWebdavMethod eq 'DMMKPATHS')
						{
						carp "setting perlresponsehandler to DMMKPATHS_handler";
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::dmmkpaths);
						}
					elsif (($XWebdavMethod) && ($XWebdavMethod eq 'DMMKPATH')) {
	#					carp "setting perlresponsehandler to DMMKPATH_handler";
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::dmmkpath);
					}
					elsif ($XWebdavMethod eq 'DMOVERLAY')
						{
						carp $r->as_string();
						#carp "setting perlresponsehandler to DMOVERLAY_handler";
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::dmoverlay);
						}
					elsif ($XWebdavMethod eq 'SETREDIRECT')
						{
						my $buf;
						my $content;
						my $content_length = $r->header_in('Content-Length');
						if ($content_length > 0)
							{
							while ($r->read($buf, $content_length)) {
								$content .= $buf;
								}
							$logging =~ m/Body/&&$rlog->info("Content from POST: $content");
							}
						carp "setting perlresponsehandler to SETREDIRECT_handler";
						#$r->handler('perl-script');
						#$r->set_handlers(PerlResponseHandler => \&acl_handler);
						}
					elsif ($XWebdavMethod eq 'DMPATCHPATHS') {
						$rlog->info("Matched DMPATCHPATHS");
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::dmpatchpaths);
					}
					else {
						my $buf;
						my $content;
						my $content_length = $r->header_in('Content-Length');
						$rlog->info("Unmatched X-Webdav-Method: $XWebdavMethod");
						if ($content_length > 0)
							{
							while ($r->read($buf, $content_length)) {
								$content .= $buf;
								}
							$logging =~ m/Body/&&$rlog->info("Content from POST: $content");
							}
						}
					}
				}
				
				
			elsif ($rmethod eq "PUT") {
				carp $r->as_string();
				my $sitesfolder = "/$user/Web/Sites";
				# LOCK /walinsky/Web/Sites
				$r->headers_in->{'If'} = "<$sitesfolder> $ifHeader";
				}
			}
		}
#	elsif (($rmethod eq "PROPFIND") && ($userAgent =~m/^DotMacKit/))
#		{
#			my $buf;
#			my $content;
#			my $content_length = $r->header_in('Content-Length');
#			while ($r->read($buf, $content_length)) {
#				$content .= $buf;
#				}
#			carp $content;
#		}
	elsif ($rmethod eq "GET") {

			if (($r->headers_in->{'Host'} eq 'publish.mac.com') && ($userAgent =~ m/^DotMacKit/))
				{
				if($r->args())
					{
					my @args = split '&', $r->args();
					my %params;
					foreach my $a (@args) {
						(my $att,my $val) = split '=', $a;
						$params{$att} = $val ;
						}
					if ($params{'webdav-method'} eq 'TRUTHGET')
						{
#						carp $r->as_string();
						$r->handler('perl-script');
						$r->set_handlers(PerlResponseHandler => \&DotMac::DMXWebdavMethods::truthget);
						}
					}
				}
		}
	
	#carp $rmethod;
	#carp $r->as_string();
	
	#if (($rmethod eq "LOCK") || ($rmethod eq "PUT") || ($rmethod eq "PROPFIND") || ($rmethod eq "PROPPATCH") || ($rmethod eq "MKCOL") || ($rmethod eq "UNLOCK")) {
	#	carp $r->as_string();
	#	if (($rmethod eq "PROPFIND") || ($rmethod eq "PROPPATCH"))
	#		{
	#		my $buf;
	#		my $content;
	#		my $content_length = $r->header_in('Content-Length');
	#		while ($r->read($buf, $content_length)) {
	#			$content .= $buf;
	#		}
	#		carp $content;
	#		}
	#	}
	return Apache2::Const::OK;
	}

1;
