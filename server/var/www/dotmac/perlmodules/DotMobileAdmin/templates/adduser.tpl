[-
use DotMac::CommonCode;
use DotMac::DotMacDB;
$dbadmin = @param[0]->{'dbconn'};


$realm = @param[0]->{'realm'};

#@onceusers = $dbadmin->list_users($realm);
@idisksizes = qw/1048576 2097152 5242880 10485760 15728640 20971520/;
@mailsizes = qw/1048576 2097152 5242880 10485760 15728640 20971520/;


sub CGIparamToHash
{
	my @arr = CGI::param();
	foreach $key (@arr){
		$paramHash{$key} = CGI::param($key);
	}
	return \%paramHash;
}

@users = $dbadmin->list_users($realm);
$idiskPath=@param[0]->{'idiskPath'};


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

$params=CGIparamToHash();

if (CGI::param('createUser') eq 'Create User') {
	if ($dbadmin->fetch_user_info($params->{'username'},$realm)) {
		$error = "User Already Exists";
		$hash=$params;
	} else {
		$params->{'user'}= $params->{'username'};
		$dbadmin->add_user($params->{'username'},$params->{'password'},$realm);
		$dbadmin->update_user_info($params,$realm);
		if ($dbadmin->fetch_user_info($params->{'username'},$realm)){

			$message = " User $params->{'username'} created";

		}
	}
}


-]

[+ $blah +]

<br />
<form name="adduser" method="post">
	<font color="blue"><strong>[+ $message +]</strong></font>
	[$ if $error $]
	<font color="red">&nbsp;<strong>Error: </strong>[+ $error +]</font>
	[$ endif $]
  <table border="0" cellspacing="2" cellpadding="2">
    <tr>
      <td>Username:</td>
      <td>&nbsp;</td>
      <td colspan="3">E-mail Address:</td>
    </tr>
    <tr>
      <td><input type="text" name="username" id="username" style="width:200px;" value="[+ $hash->{'username'} +]" tabindex="1" active=false /></td>
      <td>&nbsp;</td>
      <td colspan="3"><input type="text" name="email_addr" id="email" value="[+ $hash->{'email_addr'} +]" style="width:200px;" tabindex="5"  /></td>
    </tr>
    <tr>
      <td>Password:</td>
      <td>&nbsp;</td>
      <td colspan="3">iDisk Storage:</td>
    </tr>
    <tr>
      <td><input type="password" name="passwd" id="passwd" style="width:200px;" value="[+ $hash->{'passwd'} +]"tabindex="2"  /></td>
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
      <td height="40" colspan="5"><input type="submit" name="createUser" id="createUser" value="Create User" tabindex="10"  />
      <input type="button" name="reset" id="reset" onclick="document.location='?m=users';" value="Cancel" tabindex="11"  /></td>
    </tr>
    <tr>
      <td colspan="5"><hr /></td>
    </tr>
  </table>
  <input type="hidden" name="m" value="adduser" />
</form>

