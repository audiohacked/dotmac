# Installing dotMac on Mac OS X 10.5 (Leopard) #

## Abstract: ##
These instructions describe the procedure for configuring a stock install of **Mac OS X 10.5.2** for use as a **dotMac** server. This will allow the use of **iDisk** and **iSync** across multiple Macs. The server machine can also be a client machine. The dotMac files will be installed in **/Library/Webserver/**, and **/etc/apache2/other/**. Configuring a machine to serve _both_ dotMac and other services simultaneously is beyond the scope of this document. **Back to My Mac** support is not available at this time.

## Disclaimer: ##
The information given in this document is, to the best of the authors' knowledge, accurate, but no warranty is expressed or implied. It is the user's responsibility to determine the suitability of these procedures for use on their own system. These procedures have not been thoroughly tested on all possible configurations. The authors disclaim all liability with respect to the use of this document and the procedures contained herein. Nothing contained in this document shall be construed as a recommendation to violate and law, policy or regulation. The dotMac project is under active development and these procedures may quickly become outdated. **PROCEED AT YOUR OWN RISK.**

## Revision history: ##
| **Date**     | **Contributor** | **Changes** |
|:-------------|:----------------|:------------|
| 2008-03-31 | DKNewsham     | Corrected typo in `curl` command |
| 2008-03-03 | DKNewsham     | Converted to wiki format |
| 2008-02-29 | DKNewsham     | Corrected commands for backup and for permissions (Thanks, walinsky) |
| 2008-02-28 | DKNewsham     | Simplified install by using the provided httpd-ssl.conf and dotmac.conf files for Leopard using /Library/WebServer/dotmac as path |
| 2008-02-25 | DKNewsham     | Initial draft of document based on theGuide written by walinsky |

## Before you begin: ##

You will need the following things before you can set up a dotMac server on Mac OS X.
  * Mac OS X 10.5.2 (It is possible to adapt these instructions to other versions, but it is beyond the scope of this document.)
  * A static IP address (It should be possible to use a dynamic IP, but it is beyond the scope of this document.)
  * Administrator access (You will need to using the `sudo` command.)
  * [XCode](http://developer.apple.com/tools/xcode/) (Freely available from Apple, but requires free registration.
  * Firewall configured correctly for ports 80 and 443.
  * Internet connection
  * A couple of hours

Selected key words are shown in **bold** font and terminal commands are shown in `code` font. Syntax highlighting is automatically applied by the wiki and should be ignored. The terminal commands should not be used without scrutiny. If you are unsure of what a command will do, look it up first. Working with `sudo` is dangerous.

## Procedures: ##

### Start ###
Log into Mac OS X as a user with administrator privileges.

Start Terminal.app (/Applications/Utilities/Terminal.app) or your favorite terminal.

### Create backups of all files that will be modified ###
As always, one should **create backups** of all files that will be modified in case something goes wrong. In this case, the Apace modules mod\_dav.so and mod\_dav\_fs.so will be replaced. It would also be wise to make sure you have a recent backup of the entire system.
```
	$ sudo cp /usr/libexec/apache2/mod_dav.so /usr/libexec/apache2/mod_dav.so.default
	$ sudo cp /usr/libexec/apache2/mod_dav_fs.so /usr/libexec/apache2/mod_dav_fs.so.default
```

### Download dotMac ###
Use SubVersion to download the newest version of dotMac to your home directory. The dotMac source includes the Perl modules that handle .mac emulation as well as necessary patches for Apache modules.
```
	$ svn checkout http://dotmac.googlecode.com/svn/trunk/ ~/dotmac
```

### Patch, build and install Apache modules ###
In this document we will use Apache 2.2.6 (the version that ships with Leopard), but later versions should work as well. Use the cURL tool to download the appropriate version of Apache from the Apache.org archive server to your home folder then unpack it.
```
	$ cd ~
	~ $ curl -O http://archive.apache.org/dist/httpd/httpd-2.2.6.tar.gz
	~ $ gnutar -xzf httpd-2.2.6.tar.gz
```

Apply the quota patch provided with dotMac to enable iDisk quota support. (The patches are built against different versions of Apache, so we will need to skip the highest level of the tree.)
```
	$ cd ~/httpd-2.2.6
	~/http-2.2.6 $ patch -p1 < ~/dotmac/Patches/Apache/quota.patch.txt
	~/http-2.2.6 $ patch -p1 < ~/dotmac/Patches/Apache/ampquotefix.patch
```

Configure and build the patched Apache modules. The gcc compiler is bundled with XCode. (Leopard, does not build binaries for ppc64 or x86\_64 by default, even on those architectures. If you are using a G4 or i386 processor, you can omit the CFLAGS argument, but it won't hurt to build for all architectures.)
```
	$ cd ~/httpd-2.2.6
	~/http-2.2.6 $ ./configure CFLAGS='-arch x86_64 -arch i386 -arch ppc -arch ppc64' --enable-modules=most --enable-mods-shared=all
	~/http-2.2.6 $ make
```

Install the patched versions of mod\_dav.so and mod\_dav\_fs.so by replacing the originals.
```
	$ sudo cp ~/httpd-2.2.6/modules/dav/main/.libs/mod_dav.so /usr/libexec/apache2/mod_dav.so
	$ sudo cp ~/httpd-2.2.6/modules/dav/fs/.libs/mod_dav_fs.so /usr/libexec/apache2/mod_dav_fs.so
```

### Install Perl module dependencies ###
The dotMac modules depends on several Perl modules that are not included by default. One can use CPAN to automate the installation of Perl modules. For simplicity, this will be done from a privileged shell.
```
	$ sudo -s
	# cpan
```
If you haven't run `cpan` before, you may be prompted for interactive setup. Answer _no_ for automatic setup.
```
	cpan> install HTTPD::UserAdmin
	cpan> install MD5
	cpan> install XML::DOM
```
You will be prompted to queue dependencies for the XML::DOM package. Answer _yes_.
```
	cpan> install HTTP::DAV
```
If you are using a G4 or i386 processor, install XML::LibXML then exit CPAN and the privileged shell as follows.
```
	cpan> install XML::LibXML
	cpan> q
	# exit
```
If you are using a G5 or Xeon processor, Leopard's `make` environment will not build for the ppc64 or x86\_64 architectures by default. Therefore, you will have to manually edit the Makefile for the XML::LibXML module as follows.
```
	cpan> get XML::LibXML
	cpan> look XML::LibXML
	# perl Makefile.PL
	# nano Makefile 
```
Using the find function (ctrl-w) search for **FLAG** and make sure all instances of **-arch i386 -arch ppc** are accompanied by **-arch ppc64** and **-arch x86\_64** (~ 3 locations). Save (ctrl-o) and exit (ctrl-x). You can now install the module, quit CPAN and exit the privileged shell.
```
	# make install
	# exit
	cpan> q
	# exit
```

### Install the dotMac tree and Perl modules ###
The dotMac files downloaded earlier need to be copied to their expected paths.
```
	$ sudo cp -r ~/dotmac/server/var/www/dotmac /Library/WebServer/dotmac 
	$ sudo mkdir /Library/WebServer/dotmac/userxml/testuser
```

DotMac needs to own all of the files in /Library/WebServer/dotmac but not in /Library/WebServer/dotmac/private with the exception of /Library/WebServer/dotmac/private/iDiskUsers.
```
	$ sudo chown -R www:www /Library/WebServer/dotmac
	$ sudo chmod -R 755 /Library/WebServer/dotmac
	$ sudo chown -R root:wheel /Library/WebServer/dotmac/private
	$ sudo chown www:www /Library/WebServer/dotmac/private/iDiskUsers
```

### Set admin password ###
The default password for the dotMac administrator account needs to be changed to something secure. Modify the authentication digest using the following command followed by the new admin password when prompted.
```
	$ sudo htdigest /Library/WebServer/dotmac/private/iDiskAdmins idisk.mac.com admin
```

### Copy and modify configuration files ###
Copy the dotMac configuration files and change their permissions so that they will be automatically loaded by Apache.
```
	$ sudo cp ~/dotmac/extras/platform_specific/Leopard/dotmac.conf /etc/apache2/other/dotmac.conf
	$ sudo chown www:www /etc/apache2/other/dotmac.conf
	$ sudo cp ~/dotmac/extras/platform_specific/Leopard/httpd-ssl.conf /etc/apache2/other/httpd-ssl.conf
	$ sudo chown www:www /etc/apache2/other/httpd-ssl.conf
```

Modify /etc/apache2/other/dotmac.conf using nano or your favorite command line editor.
```
	$ sudo nano /etc/apache2/other/dotmac.conf
```
Modify the line `my $dotMacIPAddress = '###.###.###.###';` so that ###.###.###.### is your server's IP address then save (ctrl-o) and exit (ctrl-x).

### Starting the dotMac server ###
For good measure, restart your machine. Test that Apache is now configured correctly using `apachectl`. You should see no errors. If you do, consult the [[LeopardInstallationGuide#Troubleshooting|troubleshooting]] section.
```
	$ sudo apachectl configtest
```
Start Console.app (/Applications/Utilities/Console.app) and check **LOG FILES** > **/var/log** > **apache2** to monitor the progress of the Apache server. Start the Apache server by using the **System Preferences**' **Sharing** preference pane to start **Web Sharing**. You should see no warnings in Console.app. If you do, consult the [[LeopardInstallationGuide#Troubleshooting|troubleshooting]] section.

### Configure client machine(s) hosts file(s) ###
You will need to trick each client's .mac system into connecting to your new server instead of Apple's .mac server. (This step assumes that the server has a static IP address.) On each client machine, you will need to edit the hosts file so that it looks for your server instead of checking a DNS server to get the real .mac server's address. Open the /etc/hosts file using nano or your favorite command line editor.
```
	$ sudo nano /etc/hosts
```
Add the following lines at the end of the file substituting your server's IP address for ###.###.###.###.
```
###.###.###.### www.mac.com syncmgmt.mac.com idisk.mac.com configuration.apple.com lcs.mac.com certinfo.mac.com delta.mac.com notify.mac.com publish.mac.com homepage.mac.com

###.###.###.### www.mac.com. syncmgmt.mac.com. idisk.mac.com. configuration.apple.com. lcs.mac.com. certinfo.mac.com. delta.mac.com. notify.mac.com. publish.mac.com. homepage.mac.com.
```
Save (ctrl-o) and exit (ctrl-x). You should not need to restart your machine to make this change take effect, but you may need to flush your system's lookup cache using the following command.
```
	$ sudo dscacheutil -flushcache
```

### Create client account(s) ###
For each user, you will need to manually create their directories then use the iDiskAdmin web admin interface to set up their password and quota.

Copy the iDisk folder skeleton to **USERNAME**'s new iDisk folder.
```
	$ sudo cp -r /Library/WebServer/dotmac/skel /Library/WebServer/dotmac/idisk/USERNAME
	$ sudo chown -R www:www /Library/WebServer/dotmac/idisk/USERNAME
```

Using Safari, log into http://configuration.apple.com/idiskAdmin with the admin password you set earlier and create a new user with **USERNAME** and assign it a quota.

Restart the server.
```
	$ sudo apachectl graceful
```

### Configure client certificate ###
The dotMac server will return a certificate that must be trusted before .mac will connect. This certificate must be manually added to the list of trusted certificates for each client.

Using Finder, connect (cmd-k) to https://idisk.mac.com/USERNAME

You will be prompted to confirm a certificate. Select **Show Certificate** and drag the certificate icon to the desktop to create a dot.mac.com.cer file.

Open **Keychain Access.app** (/Applications/Utilities/Keychain Access.app) and select the **login** keychain (if necessary, click the **Show Keychains** button at the bottom-left). Drag the certificate from the desktop to the pane with the other certificates then select **Always Trust** when prompted.

### Configure client(s) .mac prefereces ###
Open the **System Preferences**' **.mac** preference pane and enter the client's user name and password.

Restart the dotMac server.

### Finish ###
You should now have a fully working dotMac server with iDisk and iSync support.

Clean up by removing the dotMac and Apache source files. Alternatively, you may wish to save copies of the patched mod\_dav.so and mod\_dav\_fs.so modules in case an Apple update overwrites them later.
```
	$ rm -r ~/httpd-2.2.6
	$ sudo rm -r ~/dotmac
```

## Troubleshooting ##
If you are having issues, try running `sudo apachectl configtest` to find issues with your Apache configuration and modules. Also, check the Apache logs in Console.app. Some issues that the author encountered are listed below. Additional help is available at the [dotMac website](http://code.google.com/p/dotmac/).

**Symptom:**
Error trying to start/test Apache server because of DAVSATMaxAreaSize.

org.apache.httpd[90519](90519.md) $parms->add\_config() has failed: Invalid command 'DAVSATMaxAreaSize', perhaps misspelled or defined by a module not included in the server configuration at /System/Library/Perl/Extras/5.8.8/darwin-thread-multi-2level/Apache2/PerlSections.pm line 203.\n

**Problem:**
The installed Apache DAV module(s) (mod\_dav.so and/or mod\_dav\_fs.so) are not patched to include support for DAVSATMaxAreaSize. This can result from an incomplete installation or an Apple update to the Apache server.

**Solution:**
Re-patch, re-build and re-install mod\_dav.so and mod\_dav\_fs.so as directed above.


---


**Symptom:**
Error trying to start/test Apache server because of missing image.

> Can't load '/Library/Perl/5.8.8/darwin-thread-multi-2level/auto/XML/LibXML/LibXML.bundle' for module XML::LibXML: dlopen(/Library/Perl/5.8.8/dacd rwin-thread-multi-2level/auto/XML/LibXML/LibXML.bundle, 1): no suitable image found. Did find:\n\t/Library/Perl/5.8.8/darwin-thread-multi-2level/auto/XML/LibXML/LibXML.bundle: no matching architecture in universal wrapper at /System/Library/Perl/5.8.8/darwin-thread-multi-2level/DynaLoader.pm line 230&quot;

**Problem:**
A module you built (mod\_dav.so, mod\_dav\_fs.so or XML::LibXML) was not built for your architecture. You can confirm this using the following command (substitute the appropriate path and file name).
```
$ file /usr/libexec/apache2/mod_dav.so
```

**Solution:**
Be sure that the appropriate compiler flags are being given to override the incorrect default behavior. The default only included i386 and ppc7400 (G4).


---


**Symptom:**
Console Message
> UserAdmin.pm: Can't initialize database: /var/www/dotmac/userxml/testuser/user.dat; Permission denied

**Problem:**
/var/www/dotmac/userxml/testuser/user.dat has incorrect permissions.

**Solution:**
Ensure that the owner is www:www.


---


**Symptom:**
Console shows following error.
> 2/26/08 12:27:12 AM com.apple.launchd[1](1.md) (org.apache.httpd) Unknown key: SHAuthorizationRight

**Problem:**
This seems to be an issue with Apple's launchd overloading.

**Solution:**
Ignore.


---


**Symptom:**
Finder error when connecting to iDisk:
> You iDisk is not available because connecting to the iDisk server failed. An unexpected error occurred (error code -5016).
idiskErrorLog shows:
> [Feb 26 22:03:44 2008](Tue.md) [error](error.md) [128.118.199.95](client.md) access to /Library/Webserver/dotmac/idisk/USERNAME/ failed, reason: SSL connection required.

**Problem:**
Unable to create SSL session. Possibly due to a missing certificate or password.

**Solution:**
Try using Finder to connect (cmd-k) to the server https://idisk.mac.com/USERNAME.


---


**Symptom:**
Error in error\_log:
> [Feb 26 20:29:00 2008](Tue.md) -e: Can't initialize database: /Library/Webserver/dotmac/userxml/testuser/user.dat; Permission denied

**Problem:**
The user.dat file is owned by root:www.

**Solution:**
Change the owner to www:www


---


**Symptom:**
Unable to create new user with iDiskAdmin.

**Problem:**
Permissions for /Library/WebServer/dotmac/private/ are incorrect.

**Solution:**
Make sure that /Library/WebServer/dotmac/private/iDiskUsers is owned by www:www. Alternatively, temporarily set the entire folder as owned by www:www.