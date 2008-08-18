#------------------------------------
package DotMac::WebObjects::Comments::wa;

use strict;
use warnings;

#use CGI::Carp; # for neat logging to the error log
use Apache2::Access ();
use Apache2::Request;
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

use HTTPD::UserAdmin(); # move this to common with auth subs

$DotMac::WebObjects::Comments::wa::VERSION = '0.1';

sub handler {
	my $r = shift;

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
                $r->log->error("Cannot start session, try checking session store permissions. Error from eval: $@");
                return Apache2::Const::SERVER_ERROR;
        }

	if( $r->uri ne '/WebObjects/Comments.woa/wa/comment' && !defined($session{lastmethod}) ){
		$r->log->error("Comments.Woa/wa: Unauthorized, denying access");
		return Apache2::Const::HTTP_UNAUTHORIZED;
	}

        my $returncode;
	if( $r->uri eq "/WebObjects/Comments.woa/wa/comment" ){
                $wosid = Apache2::Cookie->new($r,
                                              -name => 'wosid',
                                              -value => $session{_session_id},
                                              -path => '/WebObjects/Comments.woa'
                    );
                $r->log->debug("Made wosid cookie: $wosid");
                $woinst = Apache2::Cookie->new($r,
                                               -name => 'woinst',
                                               -value => int(rand(100)),
                                               -path => '/WebObjects/Comments.woa'
                    );
                $r->log->debug("Made woinst cookie: $woinst");

                $session{lastmethod} = 'comment';

                $r->log->info('Executing /WebObjects/Comments.woa/wa/comment, returning comment submission form');
                $returncode = comment($r, $jar, \%session);
        } elsif( $r->uri eq "/WebObjects/Comments.woa/wa/postComment" ){
                $session{lastmethod} = 'postComment';

                my $req = Apache2::Request->new($r);

#                if( $jar->cookies('cvurl')->value ne $session{userURL} or
#                    $jar->cookies('cvsa')->value ne $session{name} or
#                    $req->param('postURL') ne $session{postURL} ){
#                        $r->log->error("cvurl cookie != session userURL or cvsa cookie != session name or form postURL != session postURL, I won't trust this");
#                        return Apache2::Const::HTTP_UNAUTHORIZED;
#                }

                $r->log->info('Executing /WebObjects/Comments.woa/wa/postComment');
                $returncode = postComment($r, $req, \%session);
        } else {
                $session{lastmethod} = 'unknown';

                $r->log->error('Comments.woa/wa called with unknown uri: '.$r->uri);
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
