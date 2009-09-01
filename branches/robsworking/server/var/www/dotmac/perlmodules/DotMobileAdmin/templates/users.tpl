[-
use DotMac::CommonCode;
use DotMac::DotMacDB;
$dbadmin = DotMac::DotMacDB->new();
$realm = $req_rec->dir_config('dotMacRealm');
@onceusers = $dbadmin->list_users($realm);
@idisksizes = qw/1048576 2097152 5242880 10485760 15728640 20971520/;
@mailsizes = qw/1048576 2097152 5242880 10485760 15728640 20971520/;
foreach $onceuser (@onceusers){
	$usagehash{$onceuser}=getiDiskUsage($onceuser);
}

sub getiDiskUsage
{
   $user = shift;
   if(-d $idiskPath."/".$user){
		$command = "/usr/bin/du -sh ".$idiskPath."/".$user;
        $usage = `$command`;
   		$usage =~ /(^[0-9KMGkmg.]+).*/;
   		$val = $1;
		return($val);
   }
   else{
           return('N/A');   
   }
}

sub CGIparamToHash
{
	my @arr = CGI::param();
	foreach $key (@arr){
		$paramHash{$key} = CGI::param($key);
	}
	return \%paramHash;
}

#print Dumper(CGIparamToHash());

@users = $dbadmin->list_users($realm);
$idiskPath=$req_rec->dir_config('dotMaciDiskPath');


sub humanFileSize
{
    my $size = shift;

    if ($size > 1099511627776)  #   TiB: 1024 GiB
    {
        return sprintf("%.2f TiB", $size / 1099511627776);
    }
    elsif ($size > 1073741824)  #   GiB: 1024 MiB
    {
        return sprintf("%.2f GiB", $size / 1073741824);
    }
    elsif ($size > 1048576)       #   MiB: 1024 KiB
    {
        return sprintf("%.2f MiB", $size / 1048576);
    }
    elsif ($size > 1024)            #   KiB: 1024 B
    {
        return sprintf("%.2f KiB", $size / 1024);
    }
    else                                    #   bytes
    {
        return sprintf("%.2f bytes", $size);
    }
}


if (CGI::param('saveUser') eq 'Save User') {

	$dbadmin->update_user_info(CGIparamToHash(),$realm);

}


-]

[+ $blah +]


<table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin-bottom:5px;">
  <tr>
    <td width="40%"><h3>MobileMe Users:</h3></td>
    <td width="60%" align="right"><form name="su" method="post" action="">
        Username: <input type="text" name="uid" value="[+ CGI::param("uid") +]" /> <input type="submit" value="Search" name="find" /> [$ IF CGI::param('uid') ne "" $]<input type="button" value="Clear" onclick="document.location='?m=users';" />[$ endif $]
    </form></td>
  </tr>
</table>
<div style="overflow:auto; height:255px; border:1px solid gray; padding:1px; background:#FFF;">
    <table width="100%" border="0" cellspacing="0" cellpadding="0">
    	<tr>
        	<td height="25" bgcolor="#CCCCCC">&nbsp;<strong>Username</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Real Name</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Added On</strong></td>
        	<td bgcolor="#CCCCCC"><strong>iDisk Storage</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Email Storage</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Admin</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Active</strong></td>
        	<td bgcolor="#CCCCCC"><strong>Skeleton</strong></td>
        </tr>
        <tr><td colspan="8" bgcolor="#999" height="1"><img width="1" height="1" /></td></tr>
		[$ foreach $user (@users) $]
		[- $hash=$dbadmin->fetch_user_info($user,$realm) -]
	
		<tr onmouseover="this.style.backgroundColor='#FFFFCC';" onmouseout="this.style.backgroundColor='';" bgcolor="[$ if CGI::param('uid') eq $hash->{'username'} $]#D3DDEE [$ endif $]" style="cursor:pointer;" onclick="document.location='?m=users&uid=[+ $hash->{'username'} +]'">
		
	<!--	<?=$u['id'].($_REQUEST['who'] ? '&who='.$_REQUEST['who'] : '');?>';">-->
		  <td height="22">&nbsp;[+ $hash->{'username'} +]</td>
          <td><a href="mailto:[+ $hash->{'email_addr'} +]">[+ $hash->{'firstname'} +] [+ $hash->{'lastname'} +]</a></td>
          <td>[+ $hash->{'created'} +]</td>
          <td>[+ getiDiskUsage($hash->{'username'}) +] of <strong>[+ humanFileSize($hash->{'idisk_quota_limit'}) +]</strong></td>
          <td>[+ humanFileSize($hash->{'email'}*1024) +]</td>
          <td>[$ if $hash->{'is_admin'} eq 1 $]<font color="green">Yes</font> [$ else $]<font color="red">No</font>[$ endif $]</td>
          <td>[$ if $hash->{'is_idisk'} eq 1 $]<font color="green">Yes</font> [$ else $]<font color="red">No</font>[$ endif $]</td>
          <td>[$ if -d $idiskPath."/".$hash->{'username'} eq 1 $]<font color="green">Yes</font>[$ else $]<font color="red">No</font>[$ endif $]</td>
            </tr>
        <tr><td colspan="8" bgcolor="#999" height="1"><img width="1" height="1" /></td></tr>

		[$ endforeach $]
    </table>    
</div>
	
[- 
$hash="";
if (CGI::param(uid)) {
	$hash=$dbadmin->fetch_user_info(CGI::param(uid),$realm);
	} 
-]
[$ if $hash $]<br />
<form name="adduser" method="post">
  <?=($error ? '<font color="red">&nbsp;<strong>Error</strong>: '.$error.'</font>' : '');?>
  <table border="0" cellspacing="2" cellpadding="2">
    <tr>
      <td>Username:</td>
      <td>&nbsp;</td>
      <td colspan="3">E-mail Address:</td>
    </tr>
    <tr>
      <td><input type="text" name="username" id="username" style="width:200px;" value="[+ $hash->{'username'} +]" tabindex="1" /></td>
      <td>&nbsp;</td>
      <td colspan="3"><input type="text" name="email_addr" id="email" value="[+ $hash->{'email_addr'} +]" style="width:200px;" tabindex="5"  /></td>
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
     [$ foreach $idisksize (@idisksizes) $] 
     <option value="[+ $idisksize +]" [$ if $hash->{'idisk_quota_limit'} eq $idisksize $]  selected [$endif$] > [+ humanFileSize($idisksize) +] </option>
	 [$ endforeach $]
      </select></td>
    </tr>
    <tr>
      <td>First Name:</td>
      <td>&nbsp;</td>
      <td colspan="3">E-mail Storage:</td>
    </tr>
    <tr>
      <td><input type="text" name="firstname" id="firstname" style="width:200px;" value="[+ $hash->{'firstname'} +]" tabindex="3"  /></td>
      <td>&nbsp;</td>
      <td colspan="3"><select name="mail" id="mail_quota_limit" style="width:205px;" tabindex="7" >
	     [$ foreach $mailsize (@mailsizes) $] 
	     <option value="[+ $mailsize +]" [$ if $hash->{'idisk_quota_limit'} eq $mailsize $]  selected [$endif$] > [+ humanFileSize($mailsize) +] </option>
		 [$ endforeach $]
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
      <td><input type="text" name="lastname" id="lastname" value="[+ $hash->{'lastname'} +]" style="width:200px;" tabindex="4"  /></td>
      <td>&nbsp;</td>
      <td><select name="is_idisk" id="is_idisk" style="width:90px;" tabindex="8" >
        <option value="1">Yes</option>
        <option value="0"[$ if $hash->{'is_idisk'} eq 0 $] selected [$ endif $]>>No</option>
      </select></td>
      <td>&nbsp;</td>
      <td align="right"><select name="is_admin" id="is_admin" style="width:90px;" tabindex="9" >
        <option value="0">No</option>
        <option value="1"[$ if $hash->{'is_admin'} eq 1 $] selected [$ endif $]>Yes</option>
      </select></td>
    </tr>
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
            <td><input type="button" name="Button" id="button" value="Delete User" onclick="if(confirm('Delete user?')){document.location='?m=users&duid=[+ $hash->{'username'} +]'+(this.form.delSkel.checked ? '&dskel=1' : '');}" /></td>
            <td>&nbsp;</td>
            <td><input type="checkbox" id="delSkel" name="delSkel" value="1" /></td>
            <td><label for="delSkel">Delete User's iDisk Folder</label></td>
          </tr>
      </table></td>
    </tr>
  </table>
  <input type="hidden" name="userOriginal" value="[+ $hash->{'username'} +]" />
  <input type="hidden" name="user" value="[+ $hash->{'username'} +]" />
  <input type="hidden" name="m" value="users" />
</form>

[$ endif $]