#!/bin/bash
# 自动编译更新安装openssl至1.1.1系列版本
# 2020/01/10

##################################### variables ###############################################################
OPENSSL_HOME="/usr/local/openssl"
OPENSSL_CONFDIR=                             
OPENSSL_TAR="openssl-1.1.1f.tar.gz"
OPENSSL_BUILD_DIR="/tmp"
OPENSSL_NEED_PACKAGE="gcc make zlib-devel curl"

export OPENSSL_HOME OPENSSL_CONFDIR OPENSSL_TAR OPENSSL_BUILD_DIR OPENSSL_NEED_PACKAGE

#################################### functions ##############################################################
print() { printf "%s\n" "$*"; }              # 对printf一个包装, 用于打印

exit_msg() {
  # 打印并退出
  local msg="$*"
  print ${msg}; exit
}

#################################### main ###################################################################
# 是root用户吗？
[[ ${UID} -ne 0 ]] && { 
  exit_msg "必须使用root用户运行此脚本"
}

# 是rhel/centos系统吗？
[[ -z $(egrep -i 'CentOS|Red Hat' /etc/redhat-release) ]] && {
  exit_msg '仅支持CentOS或Redhat系统'
}

[[ ${OPENSSL_CONFDIR} ]] || OPENSSL_CONFDIR=${OPENSSL_HOME}
export OPENSSL_CONFDIR

# 安装目录是否存在, 检查是否安装过
[[ -d ${OPENSSL_HOME} ]] && { exit_msg "${OPENSSL_HOME}: 已存在"; }

# 配置目录是否存在, 检查是否安装过
[[ -d ${OPENSSL_CONFDIR} ]] && { exit_msg "${OPENSSL_CONFDIR}: 已存在"; }

# 如果OPENSSL_TAR指定的源码包不存在则下载
[[ -f ${OPENSSL_TAR} ]] || {
  curl -sOL https://www.openssl.org/source/${OPENSSL_TAR} &> /dev/null
  [[ $? -ne 0 ]] || [[ ! -f ${OPENSSL_TAR} ]] && {
    exit_msg "下载 ${OPENSSL_TAR}失败"
  }
}

# 检测当前openssl版本是否低于1.1.1
openssl_version=$( openssl version 2> /dev/null | awk '{print $2}' | egrep '([0-9]+\.){2}[0-9]' -o)
[[ ${openssl_version} ]] || {
  openssl_version_major=$( awk -F. '{print $2}' )
  openssl_version_minor=$( awk -F. '{print $3}' )
  openssl_version_micro=$( awk -F. '{print $3}' )
  {{ [[ ${openssl_version_major} -ge 1 ]] && [[ ${openssl_version_minor} -ge 1 ]]; }} && \
  [[ ${openssl_version_micro} -ge 1 ]] && { 
    exit_msg "当前openssl版本为: ${openssl_version} 高于1.1.1，略过" 
  }
}

# 这步说明包已经存在了，开始编译安装
# 安装依赖包
yum -y install ${OPENSSL_NEED_PACKAGE} &> /dev/null || {
  exit_msg "安装依赖包失败"
}

# 将包移动到OPENSSL_BUILD_DIR目录，开始编译安装
\mv ${OPENSSL_TAR} ${OPENSSL_BUILD_DIR}
cd ${OPENSSL_BUILD_DIR}
tar xf ${OPENSSL_TAR}
OPENSSL_TARDIR=${OPENSSL_TAR%*.tar.gz}
export OPENSSL_TARDIR
cd OPENSSL_TARDIR
./config --prefix=${OPENSSL_HOME} openssldir=${OPENSSL_CONFDIR} shared zlib
make -j $(awk '/^processor/' '/proc/cpuinfo' | sort |uniq | wc -l) || exit_msg "make 失败"
make install

# 添加so库
print "${OPENSSL_HOME}/lib" >> /etc/ld.so.conf.d/openssl.conf
ldconfig

# 添加环opessl的环境变量
print "export OPENSSL_BIN=${OPENSSL_HOME}/bin" >> /etc/profile.d/openssl.sh
print 'export PATH=${OPENSSL_BIN}:$PATH' /etc/profile.d/openssl.sh
source /etc/profile.d/openssl.sh 

# 添加inclue库文件(软连接)，相当于装了openssl-devel，这一步不实际上不做也可以
if [[ -d /usr/include/openssl ]]; then 
  \mv /usr/include/openssl /usr/include/openssl.bak
  ln -s ${OPENSSL_HOME}/inclued/openssl  /usr/include/openssl
else
  ln -s ${OPENSSL_HOME}/inclued/openssl  /usr/include/openssl
fi

print "ucess. openssl install to ${OPENSSL_HOME}"










