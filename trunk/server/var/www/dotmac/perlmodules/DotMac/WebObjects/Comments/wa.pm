#------------------------------------
package DotMac::WebObjects::Comments::wa;

use strict;
use warnings;

#use CGI::Carp; # for neat logging to the error log
use Apache2::Access ();
#use Apache2::Request;
use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Cookie;
use Apache::Session::File;
use Apache2::SubRequest ();#Perl API for Apache subrequests
use Apache2::Const -compile => qw(OK SERVER_ERROR HTTP_BAD_REQUEST HTTP_UNAUTHORIZED);
use DotMac::CommonCode;
use DotMac::WebObjects::Wscomments;
use XML::LibXML;
use JSON;
use Imager;

use HTTPD::UserAdmin(); # move this to common with auth subs

#$DotMac::WebObjects::Comments::wa::VERSION = '0.1';

sub handler {
	my $r = shift;
	my $logging = $r->dir_config('LoggingTypes');
	# Get session ID and find out if user has authenticated

        my $jar = Apache2::Cookie::Jar->new($r);

        my $wosid = $jar->cookies('wosid');
        my $woinst = $jar->cookies('woinst');

	my %session;
        eval {
                tie %session, 'Apache::Session::File', ($wosid ? $wosid->value : undef), {
                        Directory => $r->dir_config('dotMacPrivatePath') . '/sessions',
                        LockDirectory => $r->dir_config('dotMacPrivatePath') . '/sessionlocks'
                };
        };
        if( $@ ){
                $logging =~ m/Comments/&&$r->log->error("Cannot start session, try checking session store permissions. Error from eval: $@");
                return Apache2::Const::SERVER_ERROR;
        }

	if( ($r->uri eq '/WebObjects/Comments.woa/wa/comment') || ($r->uri eq '/WebObjects/Comments.woa/wa/getInfoForTellAFriend') ){
		$wosid = Apache2::Cookie->new($r,
									  -name => 'wosid',
									  -value => $session{_session_id},
									  -path => '/WebObjects/Comments.woa'
			);
		$logging =~ m/Comments/&&$r->log->info("Made wosid cookie: $wosid");
		$woinst = Apache2::Cookie->new($r,
									   -name => 'woinst',
									   -value => int(rand(100)),
									   -path => '/WebObjects/Comments.woa'
			);
		$logging =~ m/Comments/&&$r->log->info("Made woinst cookie: $woinst");
	}
	else {
		if (!defined($session{lastmethod})) {
			$logging =~ m/Comments/&&$r->log->error("Comments.Woa/wa: Unauthorized, denying access");
			return Apache2::Const::HTTP_UNAUTHORIZED
		}
	}
	my ($answer, $returncode);
	if ( $r->uri eq "/WebObjects/Comments.woa/wa/comment" ){
			$session{lastmethod} = 'comment';

			$logging =~ m/Comments/&&$r->log->info('Executing /WebObjects/Comments.woa/wa/comment, returning comment submission form');
			$returncode = comment($r, $jar, \%session);
        } 
	elsif ( $r->uri eq "/WebObjects/Comments.woa/wa/postComment" ) {
		$session{lastmethod} = 'postComment';
# TODO
# Can't we just do this with pnotes ???
# I'd rather not install (yet) another perl module
		my $req = Apache2::Request->new($r);

#                if( $jar->cookies('cvurl')->value ne $session{userURL} or
#                    $jar->cookies('cvsa')->value ne $session{name} or
#                    $req->param('postURL') ne $session{postURL} ){
#                        $r->log->error("cvurl cookie != session userURL or cvsa cookie != session name or form postURL != session postURL, I won't trust this");
#                        return Apache2::Const::HTTP_UNAUTHORIZED;
#                }

		$logging =~ m/Comments/&&$r->log->info('Executing /WebObjects/Comments.woa/wa/postComment');
		$returncode = postComment($r, $req, \%session);
	}
	#/WebObjects/Comments.woa/wa/getInfoForTellAFriend
	elsif ($r->uri eq '/WebObjects/Comments.woa/wa/getInfoForTellAFriend') {
		$logging =~ m/Gallery/&&$r->log->info("matched getInfoForTellAFriend");
		$session{lastmethod} = 'getInfoForTellAFriend';
		($answer, $returncode) = getInfoForTellAFriend($r, $jar, \%session);
		
		$r->content_type("text/json; charset=utf-8");
		$r->header_out('pragma', 'no-cache');
		##ntcoent-length	234 -- wooHOO  how about that ?!?!
		##Content-Encoding	gzip
		$r->header_out('Connection', 'keep-alive');
		$r->header_out('Vary', 'Accept-Encoding');
		$r->header_out('X-UA-Compatible', 'IE=Edge');
		$r->print($answer);
	}
	elsif ($r->uri eq '/WebObjects/Comments.woa/wa/newImageVerification') {
		$logging =~ m/Gallery/&&$r->log->info("matched newImageVerification");
		$session{lastmethod} = 'newImageVerification';
		($answer, $returncode) = newImageVerification($r, $jar, \%session);
		##Content-Length	4279
		##Content-Type	image/jpeg
		##Expires	Tue, 06 Oct 2009 20:33:50 GMT
		##Cache-Control	private, no-cache, no-store, must-revalidate, max-age=0
		##Server	Apache/1.3.33 (Darwin)
		##Pragma	no-cache
		##Date	Tue, 06 Oct 2009 20:33:50 GMT
		##Connection	keep-alive
		##X-UA-Compatible	IE=Edge
		$r->content_type("image/jpeg");
		$r->header_out('Cache-Control', 'private, no-cache, no-store, must-revalidate, max-age=0');
		$r->header_out('pragma', 'no-cache');
		##ntcoent-length	234 -- wooHOO  how about that ?!?!
		##Content-Encoding	gzip
		$r->header_out('Connection', 'keep-alive');
		$r->header_out('X-UA-Compatible', 'IE=Edge');
		$r->print($answer);		
	}
	elsif ($r->uri eq '/WebObjects/Comments.woa/wa/MessageDirectAction/sendMessageFromJSON') {
		$logging =~ m/Gallery/&&$r->log->info("matched MessageDirectAction/sendMessageFromJSON");

		$session{lastmethod} = 'sendMessageFromJSON';
		($answer, $returncode) = sendMessageFromJSON($r, $jar, \%session);
		$r->print($answer);
		# $returncode = Apache2::Const::OK;
	}
	else {
		$session{lastmethod} = 'unknown';

		$logging =~ m/Sections/&&$r->log->error('Comments.woa/wa called with unknown uri: '.$r->uri);
		return Apache2::Const::HTTP_BAD_REQUEST;
	}

	$wosid->bake($r);
	$woinst->bake($r);

	return $returncode;
}

sub comment( $$$ ){
        my $r = shift;
        my $jar = shift;
        my $session = shift;

        # Find the URL the comment is posted against, then extract dotmac user

        $r->args() =~ /url=(.*)/;
        my $url = DotMac::CommonCode::URLDecode($1);
        $session->{postURL} = $url;

        $url =~ m|^/([^/]+)/|;
        $session->{dotmacUser} = $1;

        # TODO: check if this is actually a valid user and path, and if it's enabled for comments

        my $username = $jar->cookies('commentusername') ? $jar->cookies('commentusername')->value : '';
        my $userURL = $jar->cookies('commentUserURL') ? $jar->cookies('commentUserURL')->value : '';

        my $secretquestion = 'Are you human?'; #FIXME: make dynamic
        $session->{secretanswer} = 'yes';

	#$r->headers_out->add('Content-Type' => "text/html; charset=utf-8");
        $r->content_type('text/html;charset=UTF-8');

        while( $_ = <DATA> ){
                s/%URL%/$url/;
                s/%commentusername%/$username/;
                s/%commentUserURL%/$userURL/;
                s/%secretquestion%/$secretquestion/;
                $r->print($_);
        }

        return Apache2::Const::OK;
}

sub postComment( $$$ ){
        my $r = shift;
        my $req = shift;
        my $session = shift;

        my $commentMessage = $req->param('commentMessage');
        my $username = $req->param('username');
        my $userURL = $req->param('userURL');
        my $secret = $req->param('secret');

        if( $secret !~ /^\s*$session->{secretanswer}\s*$/i ){
                return Apache2::Const::HTTP_UNAUTHORIZED;
        }

        my $document = XML::LibXML::Document->createDocument('1.0', 'UTF-8');
        my $documentelem = $document->createElement('rootElem'); # Bogus root element
        $document->setDocumentElement($documentelem);
        my $comment = $documentelem->appendChild($document->createElement('struct'));

        my $createDate = $comment->appendChild($document->createElement('member'));
        $createDate->appendChild($document->createElement('name'))->appendChild(XML::LibXML::Text->new('createDate'));
        $createDate->appendChild($document->createElement('value'))->appendChild(XML::LibXML::Text->new( time() ));

        #TODO: this might be supposed to be set when moderated comments are approved or something
        my $publishedDate = $comment->appendChild($document->createElement('member'));
        $publishedDate->appendChild($document->createElement('name'))->appendChild(XML::LibXML::Text->new('publishedDate'));
        $publishedDate->appendChild($document->createElement('value'))->appendChild(XML::LibXML::Text->new( time() ));

        my $modifyDate = $comment->appendChild($document->createElement('member'));
        $modifyDate->appendChild($document->createElement('name'))->appendChild(XML::LibXML::Text->new('modifyDate'));
        $modifyDate->appendChild($document->createElement('value'))->appendChild(XML::LibXML::Text->new( time() ));

        my $authorID = $comment->appendChild($document->createElement('member'));
        $authorID->appendChild($document->createElement('name'))->appendChild(XML::LibXML::Text->new('authorID'));
        $authorID->appendChild($document->createElement('value'))->appendChild(XML::LibXML::Text->new( $username ));

        my $authorURL = $comment->appendChild($document->createElement('member'));
        $authorURL->appendChild($document->createElement('name'))->appendChild(XML::LibXML::Text->new('authorURL'));
        $authorURL->appendChild($document->createElement('value'))->appendChild(XML::LibXML::Text->new( $userURL ));

        my $body = $comment->appendChild($document->createElement('member'));
        $body->appendChild($document->createElement('name'))->appendChild(XML::LibXML::Text->new('body'));
        $body->appendChild($document->createElement('value'))->appendChild(XML::LibXML::Text->new( $commentMessage ));

        DotMac::WebObjects::Wscomments::writeComment($session->{user}, $session->{url}, $comment);
}

sub getInfoForTellAFriend( $$$ ){
	my $r = shift;
	my $jar = shift;
	my $session = shift;
	my %params;
	if ($r->args()) {
		my @args = split '&', $r->args();
		foreach my $a (@args) {
			(my $att,my $val) = split '=', $a;
			$params{$att} = $val ;
		}
	}
	my $logging = $r->dir_config('LoggingTypes');	
	my ($answer, $returncode);
	my ($url, $decodedUrl);

	if ($params{'url'}) {
		$url = $params{'url'};
		$decodedUrl = DotMac::CommonCode::URLDecode($url);
	}
	else {
		$returncode = Apache2::Const::HTTP_BAD_REQUEST;
		return ($answer, $returncode);
	}
	my ($jscode, $solution) = randomJScode();
	my $signature = join "_", "s", someRandomLetters();
	$session->{sig_id} = $signature;
	$session->{sig_solution} = $solution;
	my %resultdata = ( status => 1 );
	$resultdata{data}{signature}{$signature} = $jscode;
	$resultdata{data}{url} = $decodedUrl;
	$resultdata{data}{captchaImageURL} = "/WebObjects/Comments.woa/wa/newImageVerification?$url";
	$answer = to_json(\%resultdata, {utf8 => 1});
	$logging =~ m/Gallery/&&$r->log->info("getInfoForTellAFriend sent: $answer");
	$returncode = Apache2::Const::OK;
	return ($answer, $returncode);
}

sub newImageVerification ($$$) {
	my $r = shift;
	my $jar = shift;
	my $session = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my ($answer, $returncode);
	my $captchaTxt = &captchaTxt();
	$session->{captchaTxt} = $captchaTxt;
	my $ttfont = $r->dir_config->get('dotMacPerlmodulesPath').'/DotMac/Fonts/MissEllen.ttf';
	my $img = Imager->new(
				xsize=>188,
				ysize=>45,
				channels=>4
				);
	my $fontcolor = Imager::Color->new("#666666");
	my $font = Imager::Font->new(
                file  => $ttfont, #path to any font file dotMacPerlmodulesPath
                color => $fontcolor,
                size  => 38) or die Imager->errstr;
	my ($left, $top, $right, $bottom) = 
    $font->align(string=>$captchaTxt,
                 x=>94, y=>22, 
                 halign=>'center', valign=>'center', 
                 image=>$img);
	$img->write(data => \$answer, type => 'jpeg') or die;
	$returncode = Apache2::Const::OK;
	return ($answer, $returncode);
}

sub sendMessageFromJSON ($$$) {
	my $r = shift;
	my $jar = shift;
	my $session = shift;
	my $logging = $r->dir_config('LoggingTypes');
	my ($answer, $returncode);
	my ($buf, $content);
	my $content_length = $r->header_in('Content-Length');
	if ($content_length > 0) {
		while ($r->read($buf, $content_length)) {
			$content .= $buf;
		}
	$logging =~ m/Gallery/&&$r->log->info("Content from POST: $content");
	}
	$content =~ s/postBody=//;
	$logging =~ m/Gallery/&&$r->log->info("session data: sig_id=" . $session->{sig_id} . " sig_solution=" . $session->{sig_solution} . " captchaTxt=" . $session->{captchaTxt} );
	my $json_scalar = JSON->new->utf8->decode($content);
	my $sig_id = $session->{sig_id};
	my $sent_captchatxt = $json_scalar->{data}->{iv} || '';
	my $sent_sig_solution = $json_scalar->{data}->{signature}->{$sig_id} || '';
	$logging =~ m/Gallery/&&$r->log->info("got data: sig_solution=" . $sent_sig_solution . " captchaTxt=" . $session->{captchaTxt} );
	if ( ($sent_sig_solution eq $session->{sig_solution}) && (lc($sent_captchatxt) eq lc($session->{captchaTxt})) ) {
		$logging =~ m/Gallery/&&$r->log->info("$sent_sig_solution matches: " . $session->{sig_solution} . " and $sent_captchatxt matches: " . $session->{captchaTxt} );
		$answer = '{"status":1}';
	}
	else {
		$logging =~ m/Gallery/&&$r->log->info("$sent_sig_solution doesn't match: " . $session->{sig_solution} . " or $sent_captchatxt doesn't match: " . $session->{captchaTxt} );
		$answer = '{"data":{"errorCode":"2"},"statusString":"image verification was not included","status":0}';
	}
	$returncode = Apache2::Const::OK;
	return ($answer, $returncode);
}

sub randomJScode {
	my ($solution, $jscode);
	my ($firstInt, $secondInt, $letters, $txtstring, $float);
	my @JScodeList = ("strJoin", "subStr", "divide", "multiply", "mathRound", "mathFloor");
	##choose a ranom function
	my $randomJScode = $JScodeList[int(rand scalar(@JScodeList))];

	if ($randomJScode eq "strJoin") {
		$firstInt = int(rand(51));
		$secondInt = int(rand(11));
		$letters = &someRandomLetters;
		$jscode = join ('', $firstInt, " + '",$letters, "' + ", $secondInt);
		$solution = join ('', $firstInt, $letters, $secondInt);
	}
	elsif ($randomJScode eq "subStr") {
		my @wordlist = ("its", "a", "beautiful", "day", "the", "sun", "is", "shining");
		$txtstring = join(" ", @wordlist[ map { rand @wordlist } ( 1 .. 2 ) ]);
		$firstInt = int(rand(length($txtstring)/2));
		$secondInt = int(rand(length($txtstring) - $firstInt))+1;
		$jscode = "'$txtstring'.substring($firstInt,$secondInt)";
		$solution = substr $txtstring, $firstInt, $secondInt;
	}
	elsif ($randomJScode eq "divide") {
		$firstInt = int(rand(50));
		$secondInt = int(rand(50)) + 1; #division by zero :')
		$jscode = join "/", $firstInt*$secondInt, $secondInt;
		$solution = $firstInt;
	}
	elsif ($randomJScode eq "multiply") {
		$firstInt = int(rand(51));
		$secondInt = int(rand(51));
		$jscode = join "*", $firstInt, $secondInt;
		$solution = $firstInt * $secondInt;
	}
	elsif ($randomJScode eq "mathRound") {
		$float = sprintf("%05f", rand()*100);
		$jscode = "Math.round($float)";
		$solution = int($float + .5);
	}
	elsif ($randomJScode eq "mathFloor") {
		$firstInt = int(rand(100));
		$secondInt = int(rand(10)) + 1; #division by zero :')
		($firstInt, $secondInt) = ($secondInt, $firstInt) if $firstInt < $secondInt;
		$jscode = join '', "Math.floor(", $firstInt, "/", $secondInt, ")";
		$solution = int($firstInt/$secondInt);
	}

	return ($jscode, $solution);

}

sub someRandomLetters {
	my @letterarray = ('a'..'z','A'..'Z');
	my $letters;
	my $length = 2 + rand(3);
	foreach (1..$length) 
	{    
		$letters .= $letterarray[int(rand scalar(@letterarray))]; 
	}
	return $letters;
}

sub captchaTxt {
	my @chararray = ('a'..'z');
	my $length = 4 + rand(3);
	my $captchaTxt;
	foreach (1..$length) 
	{    
		$captchaTxt .= $chararray[int(rand scalar(@chararray))]; 
	}
	return $captchaTxt;
}
1;

__DATA__
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Add comment</title>

    <style type="text/css">
      <!--
        label { display: block; }
      //-->
    </style>
  </head>
  <body>
    <form method="POST" action="/WebObjects/Comments.woa/wa/postComment">
      <label>Comment
        <textarea id="commentMessage" name="commentMessage" columns="110" rows="8"></textarea>
      </label>
      <label>Comment as: 
        <input id="username" maxlength="50" type="text" name="username" value="%commentusername%" />
      </label>
      <label>URL:
        <input id="userURL" maxlength="256" type="text" name="URL" value="%commentUserURL%" />
      </label>
      <label>%secretquestion%
        <input id="secret" maxlength="5" type="text" name="secret" />
      </label>
      <input type="reset" value="Cancel" onclick="window.close()" />
      <input type="submit" value="Add comment" />
    </form>
  </body>
</html>
