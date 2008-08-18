#------------------------------------
package DotMac::WebObjects::Wscomments;

use strict;
use warnings;

use CGI::Carp; # for neat logging to the error log
use Apache2::Access ();
use Apache2::RequestUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::SubRequest ();#Perl API for Apache subrequests
use Apache2::Const -compile => qw(OK HTTP_UNAUTHORIZED);
use Apache::Session::File;
use DotMac::CommonCode;

use XML::LibXML;
use APR::UUID;

use HTTPD::UserAdmin(); # move this to common with auth subs

$DotMac::WebObjects::Infowoa::wa::VERSION = '0.9';

sub handler {
	my $r = shift;
	my $answer;
	my $content;

	my $buf;
	while ($r->read($buf, $r->header_in('Content-Length'))) {
		$content .= $buf;
	}

	# Setup parser and find what method is being called

	my $parser = XML::LibXML->new();
	my $dom = $parser->parse_string($content);
	my $rootnode = $dom->documentElement;

	my $method = $rootnode->findvalue('/methodCall/methodName');

	$r->log->info("WSComments: method=$method");
	$r->log->debug("WSComments: Request: ".$r->as_string());
	$r->log->debug("WSComments: Content: ".$content);

	# Get session ID and find out if user has authenticated

        #TODO: replace these regexps with Apache2::Cookie
	my $cookies = $r->header_in('Cookie');
	$cookies =~ /wosid=([\d\w]+)/;
	my $wosid = $1;
	$cookies =~ /woinst=(\d+)/;
	my $woinst = $1;

	my %session;
	tie %session, 'Apache::Session::File', $wosid, {
		Directory => $r->dir_config('dotMacPrivatePath') . '/sessions',
		LockDirectory => $r->dir_config('dotMacPrivatePath') . '/sessionlocks'
	};

	if( $method ne 'comment.authenticate' && !defined($session{user}) ){
		$r->log->error("WSComments: Unauthorized, denying access");
                $r->log->debug("WSComments: wosid=$wosid woinst=$woinst");
		return Apache2::Const::HTTP_UNAUTHORIZED;
	}

	#
	# XMLRPC Methods
	#

	# comment.authenticate
	# Parameters: username, password
	# Returns: Generic XMLRPC success or HTTP_UNAUTHORIZED
	#
	# Authenticates user and sets up a session which is then tracked by cookie
	if( $method eq 'comment.authenticate' ){
		my $username = $rootnode->findvalue('/methodCall/params/param[1]/value/string');
		my $password = $rootnode->findvalue('/methodCall/params/param[2]/value/string');

		my $dmdb = DotMac::DotMacDB->new();
		if( $dmdb->authen_user($username, $password) ){
			$answer = &successResponse();
			$session{user} = $username;
                        $wosid = $session{_session_id};
                        $woinst = int(rand(100));

			$r->log->info("WSComments: comment.authenticate: Successfully logged in as $username");
		} else {
			$r->log->error("WSComments: comment.authenticate: Invalid credentials supplied, denying access.");
			return Apache2::Const::HTTP_UNAUTHORIZED;
		}
	}

	# comment.setCommentProperties
	# Parameters: properties, path, metalocktoken
	# Returns: Generic XMLRPC success
	# Sets properties for path. metalocktoken is currently ignored
	elsif( $method eq 'comment.setCommentProperties' ){
		my $parameters = $rootnode->find('/methodCall/params/param[1]/value');
		$parameters = $parameters->shift(); # Drag the node out of the single-node nodelist

		my $path = $rootnode->findvalue('/methodCall/params/param[2]/value');
		$path =~ s/^\s*(.*)\s*$/$1/m;

		&setCommentProperties($session{user}, $parameters, $path);

		$answer = &successResponse();
	}

	# comment.commentProperties
	# Parameters: path
	# Returns: Properties for path
	# Returns properties set with comment.setCommentProperties
	elsif( $method eq 'comment.commentProperties' ){
		my $path = $rootnode->findvalue('/methodCall/params/param/value/string');
		$answer = &getCommentProperties($session{user}, $path);
	}

	# comment.setCommentPropertiesForResources
	# Parameters: properties, path, metalocktoken
	# Returns: XML with empty struct
	elsif( $method eq 'comment.setCommentPropertiesForResources' ){
		my $parameters = $rootnode->find('/methodCall/params/param[1]/value');
		$parameters = $parameters->shift(); # Drag the node out of the single-node nodelist

		my @paths = $rootnode->find('/methodCall/params/param[2]/value/array/data/value/string')->get_nodelist();

		foreach my $path (@paths) {
			$path = $path->textContent();
#			$path =~ s/^\s*(.*)\s*$/$1/;
			&setCommentProperties($session{user}, $parameters, $path);
		}

		$answer = &emptyStructResponse();
	}

	# comment.indexComments
	# Parameters:
	# Returns: Generic XMLRPC success
	# I don't know what this is meant for, but it is currently a no-op
	elsif( $method eq 'comment.indexComments' ){
		$answer = &successResponse();
	}

	# comment.changeTagForComments
	# Parameters: User-agent, username
	# Returns: Integer
	# Increments the "tag", a sequence number used for various other methods
	elsif( $method eq 'comment.changeTagForComments' ){
		$answer = &changeTag($session{user});
	}

	# comment.commentIdentifiersSinceChangeTag
	# Parameters: tag, paths
	# Returns: Comment id's
	# Finds new comments since tag
	elsif( $method eq 'comment.commentIdentifiersSinceChangeTag' ){
		my $tag = $rootnode->findvalue('/methodCall/params/param[1]/value/string');

		my @paths = $rootnode->find('/methodCall/params/param[2]/value/array/data/value/string')->get_nodelist();
		foreach(@paths) { $_ = $_->textContent(); }# s/^\s*(.*)\s*$/$1/ }

		$answer = &commentsSinceChangeTag($session{user}, $tag, @paths);
	}

	# comment.commentsWithIdentifiers
	# Parameters: Comment id's, path
	# Returns: Comment
	# Fetches comments for a path with given id's
	elsif( $method eq 'comment.commentsWithIdentifiers' ){
		my @ids = $rootnode->find('/methodCall/params/param[1]/value/array/data/value/string')->get_nodelist();
		foreach(@ids) { $_ = $_->textContent(); }
		my $path = $rootnode->findvalue('/methodCall/params/param[2]/value/string');

		$answer = &getCommentsWithIdentifiers($session{user}, \@ids, $path);
        }

	# comment.publishComment
	# Parameters: Comment, path, unknown param (empty struct)
	# Returns: Generic XMLRPC success
	# Inserts or replaces a comment
	elsif( $method eq 'comment.publishComment' ){
		my($comment) = $rootnode->findnodes('/methodCall/params/param[1]/value/struct');
		my $path = $rootnode->findvalue('/methodCall/params/param[2]/value/struct');

		&writeComment($session{user}, $path, $comment);

		$answer = &successResponse();
        }

	# comment.removeCommentsWithIdentifiers
	# Parameters: Comment id's, path, unknown param (empty struct)
	# Returns: Generic XMLRPC success
	# Deletes comments
	elsif( $method eq 'comment.removeCommentsWithIdentifiers' ){
		my @ids= $rootnode->find('/methodCall/params/param[1]/value/array/data/value/string')->get_nodelist();
		foreach(@ids) { $_ = $_->textContent(); }
		my $path = $rootnode->findvalue('/methodCall/params/param[2]/value/string');

		foreach my $comment (@ids) {
			&deleteComment($session{user}, $path, $comment);
		}

		$answer = &successResponse();
	}

	# comment.terminateSession
	# Parameters: none
	# Returns: Generic XMLRPC success
	# Terminates session, and makes sure cookies are no longer sent
	elsif( $method eq 'comment.terminateSession' ){
		tied(%session)->delete();
		$wosid=undef;
		$woinst=undef;

		$answer = &successResponse();
	}

	# For unknown methods we blindly say it's fine
	else {
		$answer = &successResponse();
	}

	#
	# Send response
	#

	$r->headers_out->add('Content-Type' => "text/xml; charset=utf-8");
        $r->headers_out->add('set-cookie' => "wosid=$wosid; version=\"1\"; path=/WebObjects/WSComments.woa") if $wosid;
	$r->headers_out->add('set-cookie' => "woinst=$woinst; version=\"1\"; path=/WebObjects/WSComments.woa") if $woinst;

	$r->print( $answer->toString() );
	
	return Apache2::Const::OK;
}

sub successResponse() {
	my $answer = XML::LibXML::Document->new();

	my $rootElem = $answer->createElement('methodResponse');
	$answer->setDocumentElement($rootElem);

	my $params = $rootElem->appendChild( $answer->createElement('params') );
	my $param = $params->appendChild( $answer->createElement('param') );
	my $value = $param->appendChild( $answer->createElement('value') );
	my $boolean = $value->appendChild( $answer->createElement('boolean') );
	$boolean->appendChild( XML::LibXML::Text->new('1') );

	return $answer;
}

sub emptyStructResponse() {
	my $answer = XML::LibXML::Document->new();
	my $rootElem = $answer->createElement('methodResponse');
	$answer->setDocumentElement($rootElem);

	my $params = $rootElem->appendChild( $answer->createElement('params') );
	my $param = $params->appendChild( $answer->createElement('param') );
	my $value = $param->appendChild( $answer->createElement('value') );
	my $struct = $value->appendChild( $answer->createElement('struct') );

	return $answer;
}

sub setCommentProperties( $$$ ) {
	my $user = shift;
	my $parameters = shift;
	my $path = shift;

	my $dmdb = DotMac::DotMacDB->new();

	# Insert tag element
	my($struct) = $parameters->findnodes('./struct');
	my $member = $struct->appendChild( $parameters->ownerDocument->createElement('member') );
	my $name = $member->appendChild( $parameters->ownerDocument->createElement('name') );
	$name->appendChild( XML::LibXML::Text->new('tag') );
	my $value = $member->appendChild( $parameters->ownerDocument->createElement('value') );

	my $tag = $dmdb->fetch_comment_tag($user);
	$value->appendChild( XML::LibXML::Text->new($tag) );

	$dmdb->write_comment_properties($user, $path, $parameters->toString());

	return;
}

sub getCommentProperties( $$ ) {
	my $user = shift;
	my $path = shift;

	my $answer = XML::LibXML::Document->new();
	my $rootElem = $answer->createElement('methodResponse');
	$answer->setDocumentElement($rootElem);

	# Check if we have stored comment properties
	# TODO: find out if some value in commentProperties would also mean not enabled
	my $dmdb = DotMac::DotMacDB->new();
	if( my $properties = $dmdb->fetch_comment_properties($user, $path) ){
		$properties = XML::LibXML->new()->parse_balanced_chunk($properties);

		my $params = $rootElem->appendChild( $answer->createElement('params') );
		my $param = $params->appendChild( $answer->createElement('param') );

		$answer->adoptNode($properties);
		$param->appendChild($properties);
	} else {
		my $fault = $rootElem->appendChild( $answer->createElement('fault') );
		my $value = $fault->appendChild( $answer->createElement('value') );
		my $struct = $value->appendChild( $answer->createElement('struct') );
		
		my $stringMember = $struct->appendChild( $answer->createElement('member') );
		my $stringName = $stringMember->appendChild( $answer->createElement('name') );
		$stringName->appendChild( XML::LibXML::Text->new('faultString') );
		my $stringValue = $stringMember->appendChild( $answer->createElement('value') );
		$stringValue->appendChild( XML::LibXML::Text->new("org.apache.xmlrpc.XmlRpcException: Resource at path [$path] is not enabled for commenting.") );
		
		my $codeMember = $struct->appendChild( $answer->createElement('member') );
		my $codeName = $codeMember->appendChild( $answer->createElement('name') );
		$codeName->appendChild( XML::LibXML::Text->new('faultCode') );
		my $codeValue = $codeMember->appendChild( $answer->createElement('value') );
		my $codeValueInt = $codeValue->appendChild( $answer->createElement('int') );
		$codeValueInt->appendChild( XML::LibXML::Text->new('1408') );		
	}

	return $answer;
}

sub getCommentPropertiesAbove( $$ ) {
	my $user = shift;
	my $path = shift;

	my $dmdb = DotMac::DotMacDB->new();
        $path = $dmdb->find_nearest_path_with_properties($user, $path);
        warn "getCommentPropertiesAbove: path = $path\n";
        return getCommentProperties($user, $path);
}

sub changeTag( $ ){
	my $user = shift;

	my $dmdb = DotMac::DotMacDB->new();
	my $tag = $dmdb->increase_comment_tag($user);

	my $answer = XML::LibXML::Document->new();
	my $rootElem = $answer->createElement('methodResponse');
	$answer->setDocumentElement($rootElem);

	my $params = $rootElem->appendChild( $answer->createElement('params') );
	my $param = $params->appendChild( $answer->createElement('param') );
	my $value = $param->appendChild( $answer->createElement('value') );
	$value->appendChild( XML::LibXML::Text->new($tag) );

	return $answer;
}

sub commentsSinceChangeTag ( $$@ ){
	my $user = shift;
	my $tag = shift;
	my $iDiskPath = shift;
	my @paths = @_;

	my $answer = XML::LibXML::Document->new();
	my $rootElem = $answer->createElement('methodResponse');
	$answer->setDocumentElement($rootElem);

	my $params = $rootElem->appendChild( $answer->createElement('params') );
	my $param = $params->appendChild( $answer->createElement('param') );
	my $paramValue = $param->appendChild( $answer->createElement('value') );
	my $struct = $paramValue->appendChild( $answer->createElement('struct') );

	foreach my $path (@paths) {
		my $member = $struct->appendChild( $answer->createElement('member') );
		my $name = $member->appendChild( $answer->createElement('name') );
		$name->appendChild( XML::LibXML::Text->new($path) );
		my $memberValue = $member->appendChild( $answer->createElement('value') );
		my $array = $memberValue->appendChild( $answer->createElement('array') );
		my $data = $array->appendChild( $answer->createElement('data') );

		my $dmdb = DotMac::DotMacDB->new();
		my @comments = $dmdb->list_comments_since_tag($user, $path, $tag);

		foreach my $commentID ( @comments ){
			my $commentValue = $data->appendChild( $answer->createElement('value') );
			my $commentStruct = $commentValue->appendChild( $answer->createElement('struct') );
			my $commentMember = $commentStruct->appendChild( $answer->createElement('member') );
			my $commentMemberName = $commentMember->appendChild( $answer->createElement('name') );
			$commentMemberName->appendChild( XML::LibXML::Text->new($commentID) );
			my $commentMemberValue = $data->appendChild( $answer->createElement('value') );
			my $commentMemberValueArray = $data->appendChild( $answer->createElement('array') );
			my $commentMemberValueArrayData = $data->appendChild( $answer->createElement('data') );
		}
	}

	return $answer;
}

sub getCommentsForPath( $$ ){
	my $user = shift;
	my $path = shift;

	my $dmdb = DotMac::DotMacDB->new();
	my @commentIDs = $dmdb->list_comments_for_path($user, $path);

	return getCommentsWithIdentifiers($user, \@commentIDs, $path);
}

sub getCommentsWithIdentifiers( $$$ ){
        my $user = shift;
	my @ids = @{ shift() };
	my $path = shift;

	my $answer = XML::LibXML::Document->new();
	my $rootElem = $answer->createElement('methodResponse');
	$answer->setDocumentElement($rootElem);

	my $params = $rootElem->appendChild( $answer->createElement('params') );
	my $param = $params->appendChild( $answer->createElement('param') );
	my $paramValue = $param->appendChild( $answer->createElement('value') );
	my $array = $paramValue->appendChild( $answer->createElement('array') );
	my $data = $array->appendChild( $answer->createElement('data') );

        my $dmdb = DotMac::DotMacDB->new();
        foreach my $id ( @ids ){
                my $value = $data->appendChild( $answer->createElement('value') );
                my $comment = $dmdb->fetch_comment($user, $path, $id);
                $comment = XML::LibXML->new()->parse_balanced_chunk($comment);
                $answer->adoptNode($comment);
                $value->appendChild($comment);
        }

	return $answer;
}

sub writeComment( $$$ ){
	my $user = shift;
	my $path = shift;
	my $comment = shift;

	my $dmdb = DotMac::DotMacDB->new();

	my $commentID = $comment->findvalue('member[name = "commentID"]/value/string');
        if( ! $commentID ){
                $commentID = APR::UUID->new->format;
        }
                
	my $tag = $dmdb->fetch_comment_tag($user);

	$dmdb->write_comment($user, $path, $commentID, $tag, $comment);

	return;
}

sub deleteComment( $$$ ){
	my $user = shift;
	my $path = shift;
	my $commentID = shift;

	my $dmdb = DotMac::DotMacDB->new();
	$dmdb->delete_comment($user, $path, $commentID);

	return;
}

1;
