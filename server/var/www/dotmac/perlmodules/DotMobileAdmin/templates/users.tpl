

<table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom:5px;">
  <tr>
    <td width="40%"><h3>dotMobile.us Users:</h3></td>
    <td width="60%" align="right"><form name="su" method="post" action="">
        Username: <input type="text" name="uid" value="[% params.uid %]" /> <input type="submit" value="Search" name="find" /> [% IF cgiparam.uid != "" %]<input type="button" value="Clear" onclick="document.location='?m=users';" />[% END %]
    </form></td>
  </tr>
</table>
<div style="overflow:auto; height:255px; border:1px solid gray; padding:1px; background:#FFF;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0">
    	<tr>
        	<td height="25" bgcolor="#CCCCCC">&nbsp;<strong>Username</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Real Name</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Added On</strong></td>
        	<td bgcolor="#CCCCCC"><strong>iDisk Storage</stroiidng></td>
        	<td bgcolor="#CCCCCC"><strong>Email Storage</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Admin</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Active</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Skeleton</strong></td>
        </tr>
        <tr><td colspan="8" bgcolor="#999" height="1"><img width="1" height="1" /></td></tr>
		[% FOREACH user = users %]
		[% PERL %] 
		my $dbadmin = $stash->get('dbadmin');
		$stash->set(hash=>$dbadmin->fetch_user_info($stash->get('user'),$stash->get('realm')));
		if (-d $stash->get('idiskPath')."/".$stash->get('user')){
			$stash->set('useridisk'=>1);
		} else {
			$stash->set('useridisk'=>0);
		}
		[% END %]
		<tr onmouseover="this.style.backgroundColor='#FFFFCC';" onmouseout="this.style.backgroundColor='';" bgcolor="[% IF params.uid == hash.username %]#D3DDEE [% END %]" style="cursor:pointer;" onclick="document.location='?m=users&uid=[% hash.username %]'">
		  <td height="22">&nbsp;[% hash.username %]</td>
          <td><a href="mailto:[% hash.email_addr %]">[% hash.firstname %] [% hash.lastname %]</a></td>
          <td>[% hash.created %]</td>
          <td>[% PERL %] print DotMobileAdmin::main::getiDiskUsage($stash->get('user'),$stash->get('idiskPath')) [% END %] of <strong>[% PERL %] print DotMobileAdmin::main::humanFileSize($stash->get('hash.idisk_quota_limit'))  [% END %]</strong></td>
          <td>[% humanFileSize(hash.email*1024) %]</td>
          <td>[% IF hash.is_admin == 1 %]<font color="green">Yes</font> [% ELSE %]<font color="red">No</font>[% END %]</td>
          <td>[% IF hash.is_idisk == 1 %]<font color="green">Yes</font> [% ELSE %]<font color="red">No</font>[% END %]</td>

          <td>[% IF useridisk == 1 %]<font color="green">Yes</font>[% ELSE %]<font color="red">No</font>[% END %]</td>
        </tr>
        <tr><td colspan="8" bgcolor="#999" height="1"><img width="1" height="1" /></td></tr>

		[% END %]
    </table>    
</div>
	
[% PERL %] 
my $dbadmin = $stash->get('dbadmin');
my $params = $stash->get('params');
$stash->set(hash=>$dbadmin->fetch_user_info($params->{'uid'},$stash->get('realm')));

[% END %]
<font color="blue"><strong>[% $message %]</strong></font>
[% IF $error %]
<font color="red">&nbsp;<strong>Error: </strong>[% $error %]</font>
[% END %]

[% IF hash %]<br />
<form name="adduser" method="post">

  <table border="0" cellspacing="2" cellpadding="2">
    <tr>
      <td>Username:</td>
      <td>&nbsp;</td>
      <td colspan="3">E-mail Address:</td>
    </tr>
    <tr>
      <td><input type="text" name="username" id="username" style="width:200px;" value="[% hash.username %]" tabindex="1" /></td>
      <td>&nbsp;</td>
      <td colspan="3"><input type="text" name="email_addr" id="email" value="[% hash.email_addr %]" style="width:200px;" tabindex="5"  /></td>
    </tr>
    <tr>
      <td>Password:</td>
      <td>&nbsp;</td>
      <td colspan="3">iDisk Storage:</td>
    </tr>
    <tr>
      <td><input type="password" name="passwd" id="passwd" style="width:200px;" tabindex="2"  /></td>
      <td>&nbsp;</td>
      <td colspan="3"><select name="idisk_quota_limit" id="idisk_quota_limit" style="width:205px;" tabindex="6" >
     [% FOREACH idisksize = idisksizes %] 
     <option value="[% idisksize %]" [% IF hash.idisk_quota_limit == idisksize %]  selected [%END%] > [% PERL %] print DotMobileAdmin::main::humanFileSize($stash->get('idisksize'))  [% END %] </option>
	 [% END %]
      </select></td>
    </tr>
    <tr>
      <td>VerIFy Password:</td>
      <td>&nbsp;</td>
      <td colspan="3">E-mail Storage:</td>
    </tr>
    <tr>
      <td><input type="password" name="passwdver" id="passwdver" style="width:200px;" tabindex="2"  /></td>
      <td>&nbsp;</td>
      <td colspan="3"><select name="mail" id="mail_quota_limit" style="width:205px;" tabindex="7" >
	     [% FOREACH mailsize = mailsizes %] 
	     <option value="[% mailsize %]" [% IF hash.idisk_quota_limit == mailsize %]  selected [%END%] > [% PERL %] print DotMobileAdmin::main::humanFileSize($stash->get('mailsize'))  [% END %] </option>
		 [% END %]
      </select></td>
    </tr>
    <tr>
      <td>First Name:</td>
      <td>&nbsp;</td>
      <td>iDisk Access:</td>
      <td>&nbsp;</td>
      <td align="right">Admin Access:</td>
    </tr>
    <tr>
      <td><input type="text" name="firstname" id="firstname" style="width:200px;" value="[% hash.firstname %]" tabindex="3"  /></td>
      <td>&nbsp;</td>
      <td><select name="is_idisk" id="is_idisk" style="width:90px;" tabindex="8" >
        <option value="1">Yes</option>
        <option value="0"[% IF hash.is_idisk == 0 %] selected [% END %]>>No</option>
      </select></td>
      <td>&nbsp;</td>
      <td align="right"><select name="is_admin" id="is_admin" style="width:90px;" tabindex="9" >
        <option value="0">No</option>
        <option value="1"[% IF hash.is_admin == 1 %] selected [% END %]>Yes</option>
      </select></td>
    </tr>
  <tr>
      <td>Last Name:</td>
      <td>&nbsp;</td>
      <td colspan="3">Create User Directory:</td>
    </tr>
    <td><input type="text" name="lastname" id="lastname" value="[% hash.lastname %]" style="width:200px;" tabindex="4"  /></td>
    <td>&nbsp;</td>

    <tr>
      <td height="40" colspan="5"><input type="submit" name="saveUser" id="saveUser" value="Save User" tabindex="10"  />
      <input type="button" name="reset" id="reset" onclick="document.location='?m=users';" value="Cancel" tabindex="11"  /></td>
    </tr>
    <tr>
      <td colspan="5"><hr /></td>
    </tr>
    <tr>
      <td height="40" colspan="5"><table border="0" cellspacing="0" cellpadding="0">
          <tr>
            <td><input type="button" name="Button" id="button" value="Delete User" onclick="if(confirm('Delete user?')){document.location='?m=users&duid=[% hash.username %]';}" /></td>
	<!--+(this.form.delSkel.checked ? '&dskel=1' : '')-->
            <td>&nbsp;</td>
            <td><!--><input type="checkbox" id="delSkel" name="delSkel" value="1" />--></td>
            <td><!--><label for="delSkel">Delete User's iDisk Folder</label>--></td>
          </tr>
      </table></td>
    </tr>
  </table>
  <input type="hidden" name="userOriginal" value="[% hash.username %]" />
  <input type="hidden" name="user" value="[% hash.username %]" />
  <input type="hidden" name="uid" value="[% hash.username %]" />
  <input type="hidden" name="m" value="users" />
</form>

[% END %]
