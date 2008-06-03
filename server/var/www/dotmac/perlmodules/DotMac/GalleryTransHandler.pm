package DotMac::GalleryTransHandler;

use strict;
use warnings;

use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(:methods DECLINED);

use DotMac::Gallery;
use DotMac::CachingProxy;
use DotMac::DMXWebdavMethods;

$DotMac::GalleryTransHandler::VERSION = '0.1';

sub handler {
    my $r = shift;
    if ($r->method eq 'GET') {
		return TransHandler($r);
	}
	else {
		return Apache2::Const::DECLINED;
	}
}

sub TransHandler {
    my $r = shift;
    
    my $logging = $r->dir_config('LoggingTypes');
	my $rlog = $r->log;
    
    # warn $r->hostname;

    my $uri = $r->uri;
    my @dotMacUsers = $r->dir_config->get('dotMacUsers');
    my $found = 0;

	foreach my $username (@dotMacUsers) {
		#$logging =~ m/Sections/&&$rlog->info("matching $username against $uri");
		if($uri =~m{^/$username(.*)}) {
			if ($1 !~m{^/Web/Sites/_gallery}) {
				$uri = "/$username/Web/Sites/_gallery$1";
				$r->uri($uri);
			}
			$found = 'localuser';
			#$logging =~ m/Sections/&&$rlog->info("found $found, bailing out");
			last;
		}
		elsif($uri =~m{^/xhr/$username(.*)}) {
			if ($1 !~m{^/Web/Sites/_gallery}) {
				$uri = "/$username/Web/Sites/_gallery$1";
				$r->uri($uri);
			}
			$found = 'localtruthget';
			#$logging =~ m/Sections/&&$rlog->info("found $found, bailing out");
			last;
		}
	}
	
	$r->filename($uri); # we have no further trans handlers - we need to set $r->filename ourselves
	
    if ($found) {
    	# we matched against one of our users - let's serve things
		my $document_root = $r->document_root;
		my $dirtest = "$document_root$uri";
		if (-d $dirtest) { # we set our perlhandler on directories - files will be served by Apache
			if (!($uri=~ m,/$,)) {  # add a trailing slash if its not on there
				$uri = $uri . "/";
				$r->header_out('Content-Location',$uri);
			}
			
			if ($found eq 'localuser') {
				$r->handler('perl-script');
				$r->set_handlers(PerlResponseHandler => \&DotMac::Gallery::handler);
			}
			elsif ($found eq 'localtruthget') {
				$r->handler('perl-script');
				$r->set_handlers(PerlResponseHandler => \&DotMac::Gallery::truthgetHandler);
			}
		}
	}
    else {
# actually we should check if we're called by hostname 'gallery.mac.com'
# if not - we should prolly just throw a 404 (we don't want to be anyone's proxy)
    	# set up a proxy to apple servers
    	$r->hostname('gallery.mac.com');
# we should first set up pnotes
# we can have the CachingProxy really cache things, when we tell it what to
    	
		$r->handler('perl-script');
		$r->set_handlers(PerlResponseHandler => \&DotMac::CachingProxy::handler);
    }

    return Apache2::Const::OK; # signal that the *Uri Translation Phase* is done and no further handlers are called in this phase.
}
1;
