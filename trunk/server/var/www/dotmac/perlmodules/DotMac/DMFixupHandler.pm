#file:DotMac/DMFixupHandler.pm
#--------------------------------
package DotMac::DMFixupHandler;

use strict;
use warnings;

use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => 'OK';
use CGI::Carp;
use DotMac::CommonCode;

#my %exts = (
#  cgi => ['perl-script',     \&cgi_handler],
#  pl  => ['modperl',         \&pl_handler ],
#  tt  => ['perl-script',     \&tt_handler ],
#  txt => ['default-handler', undef        ],
#);

sub handler
	{
	my $r = shift;
	carp join ':', $r->get_server_name, $r->get_server_port;
	my $rmethod = $r->method;
	my $user = $r->user;
	if (($rmethod eq "PUT") | ($rmethod eq "MKCOL")  | ($rmethod eq "MOVE") | ($rmethod eq "POST") | ($rmethod eq "LOCK")){
		if ($rmethod eq "MOVE") {
			carp $r->as_string();
			}
		my $ifHeader = $r->headers_in->{'If'} || '';
		my $userAgent = $r->headers_in->{'User-Agent'} || '';
		chomp($userAgent);
		carp "user agent:$userAgent";
		if ($userAgent =~ m/^DotMacKit(.*)SyncServices$/) {
			#carp "I DID MATCH $userAgent !!!";
			#carp $r->finfo->fname;
			#carp $r->finfo->name;
			#carp $r->filename();
			#carp $r->path_info; #will be ""
			#carp $r->uri;
			#carp $ifHeader;
			my $ifheaderUri;
			my $clientsfolder = "/$user/Library/Application Support/SyncServices/Clients";# PUT
			my $schemasfolder = "/$user/Library/Application Support/SyncServices/Schemas";# MKCOL
			if (($rmethod eq "PUT") && ($r->uri =~ m/^$clientsfolder(.*).client$/)) {
				$r->headers_in->{'If'} = "<$clientsfolder> $ifHeader";
				}
			# LOCK /walinsky/Library/Application%20Support/SyncServices/Schemas/com.apple.Bookmarks/
			# PUT /walinsky/Library/Application%20Support/SyncServices/Schemas/com.apple.Bookmarks/CB18B05E-248E-4117-8C05-AF6AF61E429100001.temp
			# UNLOCK /walinsky/Library/Application%20Support/SyncServices/Schemas/com.apple.Bookmarks/
			elsif (($rmethod eq "PUT") && ($r->uri =~ m/^$schemasfolder\/(.*)\//)) {
				my $childfolder = $1;
				$r->headers_in->{'If'} = "<$schemasfolder/$childfolder> $ifHeader";
				}
			# (<opaquelocktoken:a3e612de-bcc3-49bd-9dcc-4369bc1c17b1>)(<opaquelocktoken:a3e612de-bcc3-49bd-9dcc-4369bc1c17b1>)
			elsif (($rmethod eq "MOVE") && ($r->uri =~ m/^$schemasfolder\/(.*)\//)) {
				carp $r->as_string();
				my $childfolder = $1;
				my $rUri = $r->uri;
				my $rDest = $r->headers_in->{'Destination'};
				
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
				$r->headers_in->{'If'} = "<$schemasfolder> $ifHeader";
				}
			
			#carp $r->headers_in->{'If'};
			}
		elsif ($userAgent =~m/^DotMacKit-like, File-Sync-Direct/)
			{
			carp $r->as_string();
			# LOCK /walinsky/.FileSync
			my $dotFilesyncFolder = "/$user/.FileSync";
			if (($rmethod eq "MOVE") && ($r->headers_in->{'Destination'} =~ m/^http:\/\/idisk.mac.com$dotFilesyncFolder/)) {
				$r->headers_in->{'If'} = "<$dotFilesyncFolder> $ifHeader";
				carp "match!";
				carp $r->headers_in->{'If'};
				}
			elsif (($rmethod eq "LOCK") && ($r->headers_in->{'If-Match'})) { # ugly! - should also test for locking $dotFilesyncFolder itself - we get requests for lock (refresh) on exact match
				$r->headers_in->{'If-Match'} = "";
				#carp $r->headers_in->{'If'};
				}
			elsif (($rmethod eq "PUT") && ($r->uri =~ m/^$dotFilesyncFolder/)) {
				$r->headers_in->{'If'} = "<$dotFilesyncFolder> $ifHeader";
				#carp $r->headers_in->{'If'};
				}
			elsif ($rmethod eq "MKCOL") {
				my $rUri = $r->uri;
				$rUri =~ s|/\Z(?!\n)|| unless $rUri eq "/"; # strip possible trailing slash
				$r->headers_in->{'If'} = "<$rUri> $ifHeader";
				carp $r->headers_in->{'If'};
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
					carp $content;
					}
				if (($XWebdavMethod) && ($XWebdavMethod eq 'DMMKPATH'))
					{
					carp "setting perlresponsehandler to DMMKPATH_handler";
					$r->handler('perl-script');
					$r->set_handlers(PerlResponseHandler => \&dmmkpath_handler);
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
				}
			}
		}
	#elsif ($rmethod eq "GET") {
	#		carp $r->uri;
	#		carp $r->filename();
	#		carp $r->path_info;
	#	}
	
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

  sub dmmkpath_handler { content_handler($_[0], 'DMMKPATH') }
 
  sub content_handler {
      my ($r, $type) = @_;
  		carp "DMMKPATH_handler $type!";
		my $dotMaciDiskPath = $r->dir_config('dotMaciDiskPath');
		DotMac::CommonCode::recursiveMKdir($dotMaciDiskPath, $r->uri);
		$r->content_type('text/plain');
		$r->print("");
		
		return Apache2::Const::OK;
  }


1;