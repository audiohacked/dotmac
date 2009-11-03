
<br />
<form name="adduser" method="post">
	<font color="blue"><strong>[% message %]</strong></font>
	[% IF error %]
	<font color="red">&nbsp;<strong>Error: </strong>[% error %]</font>
	[% END %]
  <table border="0" cellspacing="2" cellpadding="2">
    <tr>
      <td>Username:</td>
      <td>&nbsp;</td>
      <td colspan="3">E-mail Address:</td>
    </tr>
    <tr>
      <td><input type="text" name="username" id="username" style="width:200px;" value="[% hash.username %]" tabindex="1" active=false /></td>
      <td>&nbsp;</td>
      <td colspan="3"><input type="text" name="email_addr" id="email" value="[% hash.email_addr %]" style="width:200px;" tabindex="5"  /></td>
    </tr>
    <tr>
      <td>Password:</td>
      <td>&nbsp;</td>
      <td colspan="3">iDisk Storage:</td>
    </tr>
    <tr>
      <td><input type="password" name="passwd" id="passwd" style="width:200px;" value="[% hash.passwd %]"tabindex="2"  /></td>
      <td>&nbsp;</td>
      <td colspan="3"><select name="idisk_quota_limit" id="idisk_quota_limit" style="width:205px;" tabindex="6" >
     [% FOREACH idisksize IN idisksizes %] 
     <option value="[% idisksize %]" [% IF hash.idisk_quota_limit == idisksize %]  selected [% END %] >  [% PERL %] print DotMobileAdmin::main::humanFileSize($stash->get('idisksize'))  [% END %] </option>
	 [% END %]
      </select></td>
    </tr>
    <tr>
      <td>First Name:</td>
      <td>&nbsp;</td>
      <td colspan="3">E-mail Storage:</td>
    </tr>
    <tr>
      <td><input type="text" name="firstname" id="firstname" style="width:200px;" value="[% hash.firstname %]" tabindex="3"  /></td>
      <td>&nbsp;</td>
      <td colspan="3"><select name="mail" id="mail_quota_limit" style="width:205px;" tabindex="7" >
	 [% mailsizes %]
	     [% FOREACH mailsize = mailsizes %] 
	     <option value="[% mailsize %]" [% IF hash.idisk_quota_limit == mailsize %]  selected [% END %] > [% PERL %] print DotMobileAdmin::main::humanFileSize($stash->get('mailsize'))  [% END %]</option>
		 [% END %]
      </select></td>
    </tr>
    <tr>
      <td>Last Name:</td>
      <td>&nbsp;</td>
      <td>iDisk Access:</td>
      <td>&nbsp;</td>
      <td align="right">Admin Access:</td>
    </tr>
    <tr>
      <td><input type="text" name="lastname" id="lastname" value="[% hash.lastname %]" style="width:200px;" tabindex="4"  /></td>
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
      <td height="40" colspan="5"><input type="submit" name="createUser" id="createUser" value="Create User" tabindex="10"  />
      <input type="button" name="reset" id="reset" onclick="document.location='?m=users';" value="Cancel" tabindex="11"  /></td>
    </tr>
    <tr>
      <td colspan="5"><hr /></td>
    </tr>
  </table>
  <input type="hidden" name="m" value="adduser" />
</form>

