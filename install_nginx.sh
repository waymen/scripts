#!/bin/bash
# rhel/centos自动编译安装nignx，创建基本的配置文件、启动并开机启动，能够区分6和7系统自动安装
# nginx版本: 1.16.1稳定版  pcre版本：8.44

#1. 必须是root用户才能执行此脚本
#2. 当前没有安装nignx或者nignx不在运行
#3. 创建用户并且编译安装
#4. 构建nginx.conf、启动脚本
#5. 启动

NGINX_OWNER="nginx"                                 # nginx拥有者
NGINX_INSTALL_DIR="/opt/nginx"                      # nginx安装目录
PCRE_SOURCE_PACKAGE="pcre-8.44.tar.gz"              # pcre源码包
NGINX_SOURCE_PACKAGE="nginx-1.16.1.tar.gz"          # nginx源码包
PCRE_SOUCRE_DIR=${PCRE_SOURCE_PACKAGE%*.tar.gz}     # pcre文件名
NGINX_SOUCRE_DIR=${NGINX_SOURCE_PACKAGE%*.tar.gz}   # nginx文件名
NGINX_VHOSTS_DIR=${NGINX_INSTALL_DIR}/vhosts        # nginx虚拟机主机目录
MAKE_TEMP="/tmp"                                    # 编译安装的临时目录
NGINX_LOGS=                                         # nginx日志目录，非空则创建

# 编译选项
BUILD_OPTS="--prefix=${NGINX_INSTALL_DIR}
            --user=${NGINX_OWNER}
            --group=${NGINX_OWNER}
            --with-pcre=../${PCRE_SOUCRE_DIR}
            --with-stream
            --with-http_ssl_module
            --with-http_stub_status_module
            --with-http_gzip_static_module"

export NGINX_OWNER NGINX_INSTALL_DIR PCRE_SOURCE_PACKAGE NGINX_SOURCE_PACKAGE \
       PCRE_SOUCRE_DIR NGINX_SOUCRE_DIR NGINX_VHOSTS_DIR NGINX_LOGS MAKE_TEMP \
       BUILD_OPTS
       
# 是root用户吗？
[[ ${UID} -ne 0 ]] && { 
  echo "必须使用root用户运行此脚本"
  exit
}

# 是rhel/centos系统吗？
[[ -z $(egrep -i 'CentOS|Red Hat' /etc/redhat-release) ]] && {
  echo 'only support CentOS or Redhat system.'
  exit
}

# nginx在运行吗？
[[ $( pidof nginx | wc -l ) -eq 0 ]] || { 
  echo "nginx已经在运行"
  exit
}
# nginx已经存在了吗？
which nginx &> /dev/null && { 
  echo "nginx已经存在"
  exit
}

# 安装依赖包
yum -y install gcc gcc-c++ make automake autoconf \
  zlib zlib-devel openssl openssl-devel \
  libtool &> /dev/null || {
  echo "安装依赖包失败"
  exit
} 

# 创建启动nginx的用户和组
grep -q ${NGINX_OWNER} /etc/passwd || {
  groupadd ${NGINX_OWNER}
  useradd -s /sbin/nologin -M -g ${NGINX_OWNER} ${NGINX_OWNER}
}

# 下载nginx1.6.1与pcre8.44
cd ${MAKE_TEMP}
curl -sLO http://nginx.org/download/${NGINX_SOURCE_PACKAGE}
if [[ $? -ne 0 ]] || [[ ! -f ${NGINX_SOURCE_PACKAGE} ]]; then
  echo "下载: ${NGINX_SOURCE_PACKAGE} 失败"
  exit
fi

curl -sLO https://sourceforge.net/projects/pcre/files/pcre/8.44/${PCRE_SOURCE_PACKAGE}
if [[ $? -ne 0 ]] || [[ ! -f ${PCRE_SOURCE_PACKAGE} ]]; then
  echo "下载: ${PCRE_SOURCE_PACKAGE} 失败"
  exit
fi

# 编译安装pcre
tar xf ${PCRE_SOURCE_PACKAGE}
cd ${PCRE_SOUCRE_DIR}
./configure
make -j2 || exit
make install
cd ..

# 编译安装nginx
tar xf ${NGINX_SOURCE_PACKAGE}
cd ${NGINX_SOUCRE_DIR}
./configure ${BUILD_OPTS}
make -j2 || exit
make install
cd ..

# 创建虚拟目录与日志目录
mkdir -p ${NGINX_INSTALL_DIR}/vhosts
[[ ${NGINX_LOGS} ]] && mkdir -p ${NGINX_LOGS}

# cpu核心数，用于nginx.conf配置
cpu_count=$( awk '/^processor/' '/proc/cpuinfo' | sort |uniq | wc -l )
# 获取系统版本号
version=$( awk '{print $(NF-1)}' /etc/redhat-release 2> /dev/null | cut -d. -f1 )

# 生成nginx.conf配置文件
cat > ${NGINX_INSTALL_DIR}/conf/nginx.conf << EOF
user ${NGINX_OWNER} ${NGINX_OWNER};
worker_processes ${cpu_count};
worker_cpu_affinity auto;
worker_rlimit_nofile 65530;

pid        logs/nginx.pid;

events {
    use epoll;
    multi_accept off;
    worker_connections  65530;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    charset            utf-8;
    server_tokens      off;
    keepalive_timeout  60;
    gzip  on;
    gzip_min_length 1k;
    gzip_buffers 4 16k;
    gzip_http_version 1.1;
    gzip_comp_level 4;
    gzip_disable "MSIE [1-6].";
    gzip_types text/plain application/x-javascript text/css application/xml application/json image/jpeg image/gif image/png
               image/ico image/jpg;
    gzip_vary on;
    include ${NGINX_VHOSTS_DIR}/*.conf;
}
EOF
# 启动脚本
if [[ ${version} -eq 6 ]]; then
cat > /etc/init.d/nginx << EOF
#!/bin/sh
#
# nginx - this script starts and stops the nginx daemon
#
# chkconfig:   - 85 15
# description:  Nginx is an HTTP(S) server, HTTP(S) reverse \
#               proxy and IMAP/POP3 proxy server
# processname:  nginx
# config:       /usr/local/nginx/conf/nginx.conf
# pidfile:      /usr/local/nginx/logs/nginx.pid

# Source function library.
. /etc/rc.d/init.d/functions

# Source networking configuration.
. /etc/sysconfig/network

# Check that networking is up.
[ "\$NETWORKING" = "no" ] && exit 0

nginx="${NGINX_INSTALL_DIR}/sbin/nginx"
prog=\$(basename \$nginx)
lockfile="/var/lock/subsys/nginx"
pidfile="${NGINX_INSTALL_DIR}/logs/\${prog}.pid"

NGINX_CONF_FILE="${NGINX_INSTALL_DIR}/conf/nginx.conf"

start() {
    [ -x \$nginx ] || exit 5
    [ -f \$NGINX_CONF_FILE ] || exit 6
    echo -n $"Starting \$prog: "
    daemon \$nginx -c \$NGINX_CONF_FILE
    retval=\$?
    echo
    [ \$retval -eq 0 ] && touch \$lockfile
    return \$retval
}

stop() {
    echo -n $"Stopping $prog: "
    killproc -p \$pidfile $prog
    retval=\$?
    echo
    [ \$retval -eq 0 ] && rm -f \$lockfile
    return \$retval
}

restart() {
    configtest_q || return 6
    stop
    start
}

reload() {
    configtest_q || return 6
    echo -n \$"Reloading \$prog: "
    killproc -p \$pidfile \$prog -HUP
    echo
}

configtest() {
    \$nginx -t -c \$NGINX_CONF_FILE
}

configtest_q() {
    \$nginx -t -q -c \$NGINX_CONF_FILE
}

rh_status() {
    status \$prog
}

rh_status_q() {
    rh_status >/dev/null 2>&1
}

# Upgrade the binary with no downtime.
upgrade() {
    local oldbin_pidfile="\${pidfile}.oldbin"

    configtest_q || return 6
    echo -n \$"Upgrading \$prog: "
    killproc -p \$pidfile \$prog -USR2
    retval=\$?
    sleep 1
    if [[ -f \${oldbin_pidfile} && -f \${pidfile} ]];  then
        killproc -p \$oldbin_pidfile \$prog -QUIT
        success \$"\$prog online upgrade"
        echo 
        return 0
    else
        failure \$"\$prog online upgrade"
        echo
        return 1
    fi
}

# Tell nginx to reopen logs
reopen_logs() {
    configtest_q || return 6
    echo -n \$"Reopening \$prog logs: "
    killproc -p \$pidfile \$prog -USR1
    retval=\$?
    echo
    return \$retval
}

case "\$1" in
    start)
        rh_status_q && exit 0
        \$1
        ;;
    stop)
        rh_status_q || exit 0
        \$1
        ;;
    restart|configtest|reopen_logs)
        \$1
        ;;
    force-reload|upgrade) 
        rh_status_q || exit 7
        upgrade
        ;;
    reload)
        rh_status_q || exit 7
        \$1
        ;;
    status|status_q)
        rh_\$1
        ;;
    condrestart|try-restart)
        rh_status_q || exit 7
        restart
	    ;;
    *)
        echo $"Usage: \$0 {start|stop|reload|configtest|status|force-reload|upgrade|restart|reopen_logs}"
        exit 2
esac
EOF
# 测试配置文件
cat > ${NGINX_VHOSTS_DIR}/index.conf << EOF
server {
    listen       80;
    server_name  localhost;

    location / {
        root   html;
        index  index.html index.htm;
    }
}
EOF
chmod +x /etc/init.d/nginx
chkconfig --add nginx
chkconfig nginx --level 35 on
${NGINX_INSTALL_DIR}/sbin/nginx

else
cat > /lib/systemd/system/nginx.service << EOF
[Unit]
Description=The nginx HTTP and reverse proxy server
After=network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
PIDFile=${NGINX_INSTALL_DIR}/logs/nginx.pid
ExecStartPre=${NGINX_INSTALL_DIR}/sbin/nginx -t
ExecStart=${NGINX_INSTALL_DIR}/sbin/nginx
ExecReload=${NGINX_INSTALL_DIR}/sbin/nginx -s reload
ExecStop=/usr/bin/kill -s QUIT \$MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
# 测试配置文件       
cat > ${NGINX_VHOSTS_DIR}/index.conf << EOF
server {
    listen       80;
    server_name  localhost;

    location / {
        root   html;
        index  index.html index.htm;
    }
}
EOF
systemctl start nginx
systemctl enable nginx  
fi 

curl -s localhost &> /dev/null && {
  echo "安装成功, 路径: ${NGINX_INSTALL_DIR}  版本: ${NGINX_SOUCRE_DIR}"
  cd ${MAKE_TEMP}
  # 清除编译完成后的源码包与文件
  rm -rf ${PCRE_SOURCE_PACKAGE} ${PCRE_SOUCRE_DIR} ${NGINX_SOURCE_PACKAGE} ${NGINX_SOUCRE_DIR} 
  exit 
} || { echo "已安装但未启动成功, 路径: ${NGINX_INSTALL_DIR}  版本: ${NGINX_SOUCRE_DIR}"; exit; }

