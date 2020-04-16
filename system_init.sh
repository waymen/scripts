#!/bin/bash
# system init for RHEL/centos 6 or later
# fname: system_init.sh

[[ ${UID} -ne 0 ]] && {
  echo 'You must run this script as root.'
  exit 1
}

[[ -z $(egrep -i 'CentOS|Red Hat' /etc/redhat-release) ]] && {
  echo 'only support CentOS or Redhat system.'
  exit 1
}

export VERSION=$( awk '{print $(NF-1)}' /etc/redhat-release | cut -d. -f1 )

echo "-----Disable selinux and iptables-----"
/usr/sbin/setenforce 0
sed -i 's#SELINUX=enforcing#SELINUX=disabled#g' /etc/selinux/config
iptables -F
iptables -X
iptables -Z
iptables -t nat -F
iptables -t nat -X
iptables -t nat -Z
service iptables stop
service iptables save

echo "-----delete user----------------"
for user in adm lp sync shutdown halt uucp operator games gopher; do
  [[ -n $(grep ${user} /etc/passwd) ]] && userdel -r ${user} &> /dev/null
done

echo "-----Settings start Service-----"
if [[ ${VERSION} -eq 6 ]]; then
  for service in $( chkconfig --list| grep on | awk '{print $1}' ); do
      chkconfig --level 12345 ${service} off
    done 

  for i in crond network rsyslog sshd; do
    chkconfig --level 35 ${i} on
  done

elif [[ ${VERSION} -eq 7 ]]; then
  for service in NetworkManager firewalld; do
    systemctl stop $service
    systemctl disable $service
  done
fi

echo "-----Add aliyun repo-----"
cd /etc/yum.repos.d/ && mkdir bak && mv *.repo  bak/
if [[ ${VERSION} -eq 6 ]]; then
curl http://mirrors.aliyun.com/repo/Centos-6.repo -o /etc/yum.repos.d/Centos-6.repo --silent
curl http://mirrors.aliyun.com/repo/epel-6.repo  -o  /etc/yum.repos.d/epel-6.repo --silent
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6

elif [[ $VERSION -eq 7 ]]; then
  curl http://mirrors.aliyun.com/repo/Centos-7.repo -o  /etc/yum.repos.d/Centos-7.repo --silent
  curl http://mirrors.aliyun.com/repo/epel-7.repo   -o  /etc/yum.repos.d/epel-7.repo --silent
  rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
fi

echo "-----Install package-----"
yum install -y curl gcc gcc-c++ make autoconf vim-enhanced tmux lrzsz ntpdate unzip openssh-clients net-tools #qemu-guest-agent

echo "-----Settings NTP------"
/usr/sbin/ntpdate ntp1.aliyun.com
yum update -y
echo '5 * * * * /usr/sbin/ntpdate ntp1.aliyun.com && /sbin/hwclock -w >/dev/null 2>&1' >> /var/spool/cron/root

echo "-----Settings SSH-----"
\cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak  # backup
sed -i 's%#UseDNS yes%UseDNS no%g' /etc/ssh/sshd_config
sed -i 's/^GSSAPIAuthentication yes$/GSSAPIAuthentication no/' /etc/ssh/sshd_config
sed -i '/#AddressFamily any/a\AddressFamily inet' /etc/ssh/sshd_config # disalbe ipv6 listen
if [[ ${VERSION} -eq 6 ]]; then
  /etc/init.d/sshd reload
elif [[ ${VERSION} -eq 7 ]]; then
  systemctl reload sshd.service
fi 

echo "-----Disalbe control-alt-delete key-----"
if [[ ${VERSION} -eq 6 ]]; then
  sed -i 's#exec /sbin/shutdown -r now#\#exec /sbin/shutdown -r now#' /etc/init/control-alt-delete.conf
  echo 'exec echo "Control+Alt+Delete already disabled"' >> /etc/init/control-alt-delete.conf
  initctl reload-configuration
  /sbin/init q
elif [[ ${VERSION} -eq 7 ]]; then
   ln -sf /dev/null /etc/systemd/system/ctrl-alt-del.target
   systemctl mask ctrl-alt-del.target
fi

echo "-----Settings Limit-----"
if [[ ${VERSION} -eq 6 ]]; then
  sed -i 's/1024/65535/' /etc/security/limits.d/90-nproc.conf
elif [[ ${VERSION} -eq 7 ]]; then
  sed -i 's/4096/65535/' /etc/security/limits.d/20-nproc.conf
fi
cat >> /etc/security/limits.conf <<EOF
* hard nofile 65536
* soft nofile 65536
* soft nproc  65536
* hard nproc  65536
EOF

echo "-----Settings Core Parameters -----"
\cp /etc/sysctl.conf /etc/sysctl.conf.bak
cat >> /etc/sysctl.conf <<EOF
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.ip_local_port_range = 1024 65530
vm.max_map_count = 262144
net.core.somaxconn=2062144
fs.file-max=655350
EOF

echo "----disabled ipv6----"
modprobe -r ipv6
echo "NETWORKING_IPV6=no" >> /etc/sysconfig/network
sed -i 's/::1/#::1/' /etc/hosts
echo -e 'alias net-pf-10 off\noptions ipv6 disable=1' > /etc/modprobe.d/ipv6off.conf
/sbin/sysctl -p

echo "-----Miscellaneous-----"
echo "alias grep='grep --color=auto'" >> /etc/bashrc
echo "alias egrep='egrep --color=auto'" >> /etc/bashrc
echo "alias vi='vim'"  >> /etc/bashrc

#echo '--------reboot-------'
#/sbin/reboot
