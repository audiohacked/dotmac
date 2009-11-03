
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
<title>dotMobile.us :: WebAdmin</title>
<link href="/idiskAdminres/styles.css" rel="stylesheet" type="text/css" />
</head>
<body>
<div id="container">
	<div id="header">
	  <a href="/" title="WebAdmin Home"><img src="/idiskAdminres/dm.png" id="logo" border="0" /></a>WebAdmin
	  <div id="info"> 
		Logged as: <strong>[% remote_user %]</strong> ( Digest )<br />
		Apache Last Restart: <strong> [% lastrestart %]<strong>
		
	  </div>
	</div>
	<!-- CONTENT START -->
	<div id="body">
		<table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-top:25px;">
		  <tr>
			<td width="220" valign="top">
			<div id="nav">
				<ul>
					<div>MobileMe Manager</div>
					<li><a href="?m=users"[$ if $m eq 'users' $] class="active" [$ endif $]> &raquo; List Users</a></li>
					<li><a href="?m=adduser"[$ if $m eq 'adduser' $] class="active" [$ endif $] > &raquo; Add User</a></li>
					<li><a href="?m=stats"[$ if $m eq 'stats' $]  class="active" [$ endif $]> &raquo; Statistics</a></li>
					<li><a href="?m=server"[$ if $m eq 'server' $] class="active" [$ endif $]> &raquo; Server Admin</a></li>
				</ul>
			</div>
			</td>

			<td valign="top" style="padding-top:15px;">[% INCLUDE "$subtemplate" %]</td>
			<td width="30">&nbsp;</td>
		  </tr>
		</table>
	</div>
	<!-- CONTENT END -->
[% INCLUDE footer.tpl %]
