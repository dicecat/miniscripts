#/usr/bin/env bash

POOL_NAME="mynas"

## update rclone
# https://rclone.org/install.sh
# if install rclone in jail
# pkg -qq install curl
cd ~
curl -OL https://downloads.rclone.org/rclone-current-freebsd-amd64.zip
unzip -a rclone-current-freebsd-amd64.zip
rclone_dir=`ls -d rclone-v*`
cd "${rclone_dir}"
# bin
chown root:wheel rclone
mkdir -p /usr/local/bin
mv rclone /usr/local/bin/rclone
# man
mkdir -p /usr/local/man/man1
mv rclone.1 /usr/local/man/man1/
makewhatis
# cleanup
cd ~
rm -rf rclone-*

## transmission
JAIL_NAME="transmission"
# Change default download folder
# cannot be done in jail file /usr/local/etc/transmission/home/settings.json
iocage exec "${JAIL_NAME}" sysrc "transmission_download_dir=/media"

## emby (NOT available on FreeNAS: Kodi, Jellyfin)
JAIL_NAME="emby"
# update to latest version
# https://github.com/MediaBrowser/Emby.Releases/releases/latest
# https://github.com/MediaBrowser/iocage-amd64
# emby_ver=`wget -qO- https://api.github.com/repos/MediaBrowser/Emby.Releases/releases/latest |grep emby-server-freebsd |grep name |head -n1 |cut -f2 -d_`
sys_ver=`uname -r | cut -f1 -d\.`
emby_url=`wget -qO- https://api.github.com/repos/MediaBrowser/Emby.Releases/releases/latest |grep "emby-server-freebsd${sys_ver}" |grep browser_download_url |head -n1 |cut -f4 -d\"`
emby_del=`iocage exec ${JAIL_NAME} pkg info |grep emby |cut -f1 -d\ `
iocage exec ${JAIL_NAME} service emby-server stop
iocage exec ${JAIL_NAME} pkg remove "${emby_del}" <<< y
cat <<-EOF | xargs -L1 iocage exec "${JAIL_NAME}"
pkg add --force "${emby_url}"
EOF
# iocage exec ${JAIL_NAME} sysrc /etc/rc.conf emby_server_enable="YES"
# Click management and follow wizard;
# Set up subtitle account;
# Disable 'Transcoding';
# Disable DLNA or create new user for DLNA!

## syncthing
JAIL_NAME="syncthing"
JAIL_PATH="/mnt/${POOL_NAME}/iocage/jails/${JAIL_NAME}/root"
# https://docs.syncthing.net/users/security.html
# Disable Global Discovery or not??
# iocage exec "${JAIL_NAME}" service syncthing stop
iocage stop "${JAIL_NAME}"
syncthing_file=`wget -qO- https://api.github.com/repos/syncthing/syncthing/releases/latest | grep freebsd-amd64 | grep name | cut -f4 -d\" | cut -f1-3 -d.`
syncthing_url=`wget -qO- https://api.github.com/repos/syncthing/syncthing/releases/latest | grep freebsd-amd64 | grep browser_download_url | cut -f4 -d\"`
cd ~
curl -OL "${syncthing_url}"
tar xf "${syncthing_file}.tar.gz"
mv "${syncthing_file}/syncthing" "${JAIL_PATH}"/usr/local/bin/syncthing
rm -rf ${syncthing_file}*

## nextcloud
JAIL_NAME="nextcloud"
# shell commands to get installation info
# https://github.com/freenas/iocage-plugin-nextcloud/blob/master/post_install.sh
echo "Use the following info to set up nextcloud:"
iocage exec "${JAIL_NAME}" cat ~/PLUGIN_INFO
# Click management and follow wizard;

## edit permissions
# transmission
iocage exec transmission pw groupadd -n media -g 8675309
iocage exec transmission pw groupmod media -m transmission
# emby
iocage exec emby pw groupadd -n media -g 8675309
iocage exec emby pw groupmod media -m emby
# syncthing
iocage exec syncthing pw groupadd -n media -g 8675309
iocage exec syncthing pw groupmod media -m syncthing
# nextcloud (this jail reuses 'www' in freenas)
# pw groupmod media -m www
iocage exec nextcloud pw groupadd -n media -g 8675309
iocage exec nextcloud pw groupmod media -m www

## add mount point
iocage stop ALL
# https://iocage.readthedocs.io/en/latest/index.html
# iocage fstab [ -a | -r | -l ]
iocage fstab -a transmission "/mnt/${POOL_NAME}/media /media nullfs rw 0 0"
iocage fstab -a emby "/mnt/${POOL_NAME}/media /media nullfs rw 0 0"
iocage fstab -a syncthing "/mnt/${POOL_NAME}/media /media nullfs rw 0 0"
iocage fstab -a nextcloud "/mnt/${POOL_NAME}/media /media nullfs rw 0 0"

## restart all jails
# iocage start ALL
reboot

# reset permission after power failure to rectify access error
# find /mnt/VOLUMENAME/FOLDER01/ | setfacl -bn

