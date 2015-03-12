#User contributed OS specific notes.

# Introduction #

Any OS specific notes we get are put here.

We don't verify these - we just list them.

# Mac OS 10.5 (Leopard) #
You'll find complete setup instructions for Leopard at the [LeopardInstallationGuide Wiki page](http://code.google.com/p/dotmac/wiki/LeopardInstallationGuide).
# Ubuntu/Debian #

A transcript of .bash\_history on a clean debian net install (this is not entirely complete):
```
apt-get update

apt-get install dpkg-dev file gcc g++ libc6-dev make patch perl autoconf dh-make devscripts fakeroot gnupg g77 gpc xutils lintian linda pbuilder debian-policy developers-reference sudo wget libxml2-dev

cd /home/dotmac
apt-get source apache2
apt-get build-dep apache2
ls -al
cd apache2-2.2.3/
wget http://dotmac.googlecode.com/svn/trunk/Patches/Apache/quota.patch.txt
patch -p1 < quota.patch.txt

nano debian/changelog

debuild -us -uc

cd ..
ls -al

dpkg -i apache2.2-common_2.2.3-4+moddavquota_i386.deb apache2-doc_2.2.3-4+moddavquota_all.deb apache2-prefork-dev_2.2.3-4+moddavquota_i386.deb apache2-utils_2.2.3-4+moddavquota_i386.deb 

apt-get install libapache2-mod-perl2
perl -MCPAN -e 'install HTTPD::UserAdmin'
perl -MCPAN -e 'install MD5'
perl -MCPAN -e 'install XML::DOM'
perl -MCPAN -e 'install HTTP::DAV'
perl -MCPAN -e 'install XML::LibXML'

a2enmod dav
a2enmod ssl
a2enmod auth_digest
a2enmod vhost_alias

nano /etc/apache2/conf.d/dotmac.conf
nano ports.conf
/etc/init.d/apache2 restart
```


You can pin the patched packages using:
```
echo "apache2-prefork-dev hold" | dpkg --set-selections
echo "apache2.2-common hold" | dpkg --set-selections
```
# Gentoo #

install the perl prerequisites with:
```
emerge HTTPD-User-Manage MD5 XML-DOM HTTP-DAV XML-LibXML
```
At least add
```
dav dav_fs auth auth_digest authn_file
```
to APACHE2\_MODULES in /etc/make.conf
Also the .conf went to /etc/apache2/vhosts.d/

# FreeBSD #

```
cd /usr/ports/www/apache22
make fetch
make extract
cd work/httpd-2.2.6
patch -p1 < /path/to/Patches/Apache/quota.patch.txt
patch -p1 < /path/to/Patches/Apache/ampquotefix.patch
cd ../..
make
make deinstall
make reinstall
```
Edit /usr/local/etc/apache22/httpd.conf and /usr/local/etc/apache22/extra/.conf to fit your needs.

# Additional FreeBSD #

also need the mod\_perl2 port:
```
cd /usr/ports/www/mod_perl2; make install
```
Ports incantations for perl modules:
```
cd /usr/ports/textproc/p5-XML-DOM; make install
cd /usr/ports/security/p5-MD5; make install
cd /usr/ports/www/p5-HTTP-DAV; make install
cd /usr/ports/textproc/p5-XML-LibXML; make install
cd /usr/ports/www/p5-HTTPD-User-Manage ; make install
```
To eliminate an apache warning, I had to:
```
mkdir /var/www/dotmac/userxml/testuser
```
and then for each user I created, I had to do that.

I would reccomend explicit suggestions on what chown commands to run.
I did:
```
chown -R www:www /var/www/dotmac
chown -R root:wheel /var/www/dotmac/private
chown -R www:www /var/www/dotmac/private/iDiskAdmins
```
I also had to create /usr/local/logs:
```
mkdir /usr/local/logs
```
I had to add the following to my apache:
```
<Directory "/var/www/dotmac">
       Options Indexes FollowSymlinks
       AllowOverride All
       Order allow,deny
       Allow from all
</Directory>
```
I also made a wildcard **.mac.com self-signed certificate:
```
openssl genrsa -out ssl.key/dotmac.key 1024
openssl req -new -key ssl.key/dotmac.key -out ssl.csr/dotmac.csr
Common Name: *.mac.com
```
I also had to be sure to include extra/httpd-dav.conf
(and edit it)**

Also the directory within which DavLockDB lives must be owned by the web server.



# Ubuntu Gutsy Gibbon Server Installation #

These instructions are Ubuntu Gutsy specific. They may, or may not, work on other versions.

Install Ubuntu Feisty server. Choose ONLY Open-SSH server on services selections during the installation. (I did NOT install LAMP (Linux Apache MySQL PHP).

sudo bash
Edit your apt sources.list, remove the CDROM entry(s) at the top, then update your installation.
```
vi /etc/apt/sources.list

apt-get update
apt-get upgrade
```
(Optional) I prefer vim. If you prefer nano, just replace "vi" with "nano" for the editing commands below.
```
sudo apt-get install vim
```
Configure the server with a static IP address:

Follow these instructions: http://www.howtogeek.com/howto/ubuntu/change-ubuntu-server-from-dhcp-to-a-static-ip-address/http://www.howtogeek.com/howto/ubuntu/change-ubuntu-server-from-dhcp-to-a-static-ip-address/

Install the required additional packages:
```
apt-get install dpkg-dev file gcc g++ libc6-dev make patch perl autoconf dh-make devscripts fakeroot gnupg g77 gpc xutils lintian linda pbuilder debian-policy developers-reference libxml-dev
```
Create a directory where you would like to build apache and the modules. I used ~/tmp.
```
mkdir tmp
cd tmp/
```
Get the apache2 source and build dependancies:
```
apt-get source apache2
apt-get build-dep apache2
```
NOTE: As of 1-8.2008, Apache 2-2.2.4 is the current version in Gutsty.

cd apache2-2.2.4/
Get the apache quota patch from the dotmac site and apply it:
```
wget http://dotmac.googlecode.com/svn/trunk/Patches/Apache/quota.patch.txt
patch -p1 < quota.patch.txt
```
Review the changelog.
```
vi debian/changelog 
```
Build the apache2 packages from the patched source (this could take awhile, depending on your system):
```
debuild -us -uc
```
Now install the compiled packages:
```
cd ..
ls -al
dpkg -i apache2.2-common_2.2.4-3build1_i386.deb apache2-doc_2.2.4-3build1_all.deb apache2-prefork-dev_2.2.4-3build1_i386.deb apache2-utils_2.2.4-3build1_i386.deb 
```
Install the apache perl modules:
```
apt-get install libapache2-mod-perl2
perl -MCPAN -e 'install HTTPD::UserAdmin'
perl -MCPAN -e 'install MD5'
perl -MCPAN -e 'install XML::DOM'
perl -MCPAN -e 'install HTTP::DAV'
perl -MCPAN -e 'install XML::LibXML'

a2enmod dav
a2enmod ssl
a2enmod auth_digest
a2enmod vhost_alias
```
Enable the dav\_fs modules for apache:
```
ln -s /etc/apache2/mods-available/dav_fs.load /etc/apache2/mods-enabled/dav_fs.load
ln -s /etc/apache2/mods-available/dav_lock.load /etc/apache2/mods-enabled/dav_lock.load
ln -s /etc/apache2/mods-available/dav_fs.conf /etc/apache2/mods-enabled/dav_fs.conf
```
You should have four modules linked (one was already done):
```
ls -al /etc/apache2/mods-enabled/dav* 
```
Make the directory for the iDisk log default location (as of current svn 1.8.2008)
```
mkdir /etc/apache2/logs
```
Install an apache control package:
```
apt-get install apache2-mpm-itk
```
Restart apache2:

/etc/init.d/apache2 force-reload
or

/etc/init.d/apache2 restart
Install subversion (svn):
```
apt-get install subversion
```
Change dir to the work / build directory created above:
```
cd ~/tmp
```
Retrieve the latest code from svn:
```
svn checkout http://dotmac.googlecode.com/svn/trunk/ dotmac-read-only
```
Return to the installation Guide in the wiki for the rest. I will add more as I configure my server.

# Fedora/FC6 #
install the fedora-logos RPM from FC8, and follow the guide for Fedora/FC8

# Fedora/FC8 #

A transcript of .bash\_history on a clean Fedora 8 install:
```
yum install perl perl-CPAN
rpm -Uvh http://download.fedora.redhat.com/pub/fedora/linux/releases/8/Everything/source/SRPMS/httpd-2.2.6-3.src.rpm
cd /usr/src/redhat/SPECS/
cp httpd.spec httpd.spec.orig
http://dotmac.googlecode.com/svn/trunk/extras/platform_specific/fedora/FC8/httpd-2.2.6-3.spec
mv httpd-2.2.6-3.spec httpd.spec
cd ../SOURCES/
wget http://dotmac.googlecode.com/svn/trunk/Patches/Apache/ampquotefix.patch
mv ampquotefix.patch httpd-2.2.6-ampquotefix.patch
wget http://dotmac.googlecode.com/svn/trunk/Patches/Apache/quota.patch.txt
mv quota.patch.txt httpd-2.2.6-quota.patch
cd ..
rpmbuild -ba SPECS/httpd.spec 
cd RPMS/i386
rpm -Uvh httpd-2.2.6-3.i386.rpm httpd-manual-2.2.6-3.i386.rpm httpd-tools-2.2.6-3.i386.rpm mod_ssl-2.2.6-3.i386.rpm 
yum install  mod_perl 
perl -MCPAN -e 'install HTTPD::UserAdmin'
perl -MCPAN -e 'install MD5'
perl -MCPAN -e 'install XML::DOM'
perl -MCPAN -e 'install HTTP::DAV'
perl -MCPAN -e 'install Test::More'
perl -MCPAN -e 'install XML::LibXML'
cd /etc/httpd/conf.d/
wget http://dotmac.googlecode.com/svn/trunk/Configuration/Apache/dotmac.conf
```
fetch the 'dotmac' folder - and copy it to /var/www/(dotmac)
```
chown -R apache:apache /var/www/dotmac
cd /var/www/dotmac/private
chown root:root *
chown apache:apache iDiskUsers
```
edit the line: my $dotMacIPAddress = '###.###.###.###'; to reflect your server's ip-address
```
vim /etc/httpd/conf.d/dotmac.conf
```
change the admin password for idiskAdmin
```
htdigest /var/www/dotmac/private/iDiskAdmins idisk.mac.com admin
```

```
apachectl restart
```
Apache will throw a warning about a non-existent (testuser) userdb; never mind: once you've used idiskAdmin, the db will be created automatically


# Notes #
## Apache 2.0.x ##
With Apache 2.0.x, a change to dotmac.conf is necessary. Replace the following lines:
```
 AuthDigestProvider file
 AuthUserFile /var/www/dotmac/private/iDiskUsers
```
With
```
AuthDigestFile /var/www/dotmac/private/iDiskUsers
```

## Multi-homed machines ##
On a multi-homed machine you'll probably want to designate a ip address to your dotmac solution.
This means you'll need to move from name based virtual hosts to ip-based virtual hosts.
To achieve this you'll need to:
  * remove/change the `NameVirtualHost *:80`
  * edit the dotmac.conf file, change all the `*:80` to `$dotMacIPAddress:80`
# Additions #

If you find anything incomplete/incorrect - use the comments here; we'll try and edit the page accordingly.