#!/bin/bash
passwd=123456
grub=grub-0.97-77.el6.x86_64.rpm
read -p "请输入你需要格式u盘的名字 如/dev/sdb :" name
newname=$(basename $name)
mname=$(mount |awk "/$newname/ {print \$1}")
if [ -n "$mname" ];then
	for i in $mname
	   do
		umount -f  $i
	done
fi
##格式化U盘并挂载
dd if=/dev/zero of=$name bs=500 count=1  >/dev/null 2>&1
fdisk -cu $name &>/dev/null <<EOF
n
p
1


a
1
w
EOF
mkfsname=$name'1'
mkfs.ext4 $mkfsname &>/dev/null
mkdir -p /mnt/usb
mount $mkfsname /mnt/usb
##安装相应的软件
cat > /etc/yum.repos.d/server.repo <<EOF
[ server]
name=server
baseurl=http://172.25.254.250/rhel7.2/x86_64/dvd
enabled=1
gpgcheck=0
EOF
mkdir -p /dev/shm/usb
yum -y install filesystem bash coreutils passwd shadow-utils openssh-clients rpm yum net-tools bind-utils vim-enhanced findutils lvm2 util-linux-ng --installroot=/dev/shm/usb/
cp -arv /dev/shm/usb/* /mnt/usb/
cp /boot/vmlinuz-2.6.32-279.el6.x86_64  /mnt/usb/boot/
cp /boot/initramfs-2.6.32-279.el6.x86_64.img  /mnt/usb/boot/
cp -arv /lib/modules/2.6.32-279.el6.x86_64/  /mnt/usb/lib/modules/
rpm -ivh $grub --root=/mnt/usb/ --nodeps --force
grub-install --root-directory=/mnt/usb/  --recheck  /dev/sdb &>/dev/null
 cp /boot/grub/grub.conf /mnt/usb/boot/grub/
uuid=$(blkid $mkfsname | grep -Eo '(.){8}-((.){4}-){3}(.){12}')
echo "
default=0
timeout=5
splashimage=/boot/grub/splash.xpm.gz
title My USB System from hugo
        root (hd0,0)
        kernel /boot/vmlinuz-2.6.32-279.el6.x86_64 ro root=$uuid selinux=0
        initrd /boot/initramfs-2.6.32-279.el6.x86_64.img
" >/mnt/usb/boot/grub/grub.cnf
cp /etc/skel/.bash* /mnt/usb/root/
chroot /mnt/usb/
exit
echo "
NETWORKING=yes
HOSTNAME=usb.hugo.org
"> /mnt/usb/etc/sysconfig/network
cp /etc/sysconfig/network-scripts/ifcfg-eth0 /mnt/usb/etc/sysconfig/network-scripts/
cat >/mnt/usb/etc/sysconfig/network-scrpits/ifcfg-eth0 <<EOF
DEVICE=eth0
BOOTPROTO=none
ONBOOT=yes
USERCTL=no
IPADDR=192.168.0.123
NETMASK=255.255.255.0
GATEWAY=192.168.0.254
EOF
cat >/mnt/usb/etc/fstab <<EOF
$uuid    		  /  			ext4    defaults        0 0
sysfs                   /sys                    sysfs   defaults        0 0
proc                    /proc                   proc    defaults        0 0
tmpfs                   /dev/shm                tmpfs   defaults        0 0
devpts                  /dev/pts                devpts  gid=5,mode=620  0 0
EOF
yum install -y expect
expect <<EOF  
	spawn grub-md5-crypt
	expect {
	  "*Password: " { send "$passwd\r";exp_continue}
		eof {exit}
		}
EOF
 p=$(cat /etc/passwd | grep '^root' | sed -i 's#x#$1$UscrQ/$RrLcKvlPkqj8uwDDfQyt5.#')
sed '/^root/d'
echo "$p">>/etc/passwd
sync

