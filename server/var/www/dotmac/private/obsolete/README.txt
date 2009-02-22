If your Apache version < 2.2.8 you won't be able to get db auth working from dotmac.conf.

You'll need to perform the following steps to get things working:

Locate the following auth settings in your dotmac.conf:

	AuthType Digest
	AuthName $dotMacRealm
	AuthDigestProvider dbd
	AuthUserFile $dotMacUserDB
	AuthDBDUserRealmQuery "SELECT passwd FROM auth WHERE username = %s AND realm = %s"
	AuthDBDUserPWQuery "select passwd from auth where username=%s"

and replace them with:

	AuthType Digest
	AuthName $dotMacRealm
	AuthDigestProvider file
	AuthUserFile $dotMacUserDB


You'll need to place the files (genAdminAccount.pl, genhtdigests.pl, iDiskAdmins and iDiskUsers) 
from this folder in ../private.

Replace idiskUserAdmin.pm in /var/www/dotmac/perlmodules with the one from this folder.

Run genAdminAccount.pl from within the private folder; this will setup your admin user;
from here on you should be able to use idiskAdmin from the web interface for creating users.
After creating a user, you'll need to tick the 'sync' buttons for syncing the db with the htdigest
files.