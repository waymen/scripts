#!/bin/bash
# rhel/centos自动编译安装nignx，创建基本的配置文件、启动并开机启动，能够区分6和7系统安装
# nginx版本: 1.16.1稳定版  pcre版本：8.44
#1. 必须是root用户才能执行此脚本
#2. 当前没有安装nignx或者nignx不在运行
#3. 创建用户并且编译安装
#4. 构建nginx.conf、启动脚本

NGINX_OWNER="nginx"                                 # nginx拥有者
NGINX_INSTALL_DIR="/opt/nginx"                      # nginx安装目录
PCRE_SOURCE_PACKAGE="pcre-8.44.tar.gz"              # pcre源码包
NGINX_SOURCE_PACKAGE="nginx-1.16.1.tar.gz"          # nginx源码包
PCRE_SOUCRE_DIR=${PCRE_SOURCE_PACKAGE%*.tar.gz}     # pcre文件名
NGINX_SOUCRE_DIR=${NGINX_SOURCE_PACKAGE%*.tar.gz}   # nginx文件名
NGINX_VHOSTS_DIR=${NGINX_INSTALL_DIR}/vhosts        # nginx虚拟机主机目录
NGINX_LOGS=                                         # nginx日志目录，非空则创建

# 编译选项
BUILD_OPTS="--prefix=${NGINX_INSTALL_DIR}
            --user=${NGINX_OWNER}
            --group=${NGINX_OWNER}
            --with-pcre=../${PCRE_SOUCRE_DIR}
            --with-stream
            --with-http_ssl_module
            --with-http_stub_status_module
            --with-http_gzip_static_module
            "

[[ ${UID} -ne 0 ]] && { 
  echo "必须使用root用户运行此脚本"
  exit
}

[[ $( pidof nginx | wc -l ) -eq 0 ]] ||{ 
  echo "nginx已经在运行"
  exit
}

which nginx &> /dev/null && { 
  echo "nginx已经存在"
  exit
}

yum -y install gcc gcc-c++ make automake autoconf \
  zlib zlib-devel openssl openssl-devel \
  libtool &> /dev/null || {
  echo "安装依赖包失败"
  exit
} 

grep -q ${NGINX_OWNER} /etc/passwd || {
  groupadd ${NGINX_OWNER}
  useradd -s /sbin/nologin -M -g ${NGINX_OWNER} ${NGINX_OWNER}
}

# download pcre and nginx soucre file
cd /tmp
curl -sLO http://nginx.org/download/${NGINX_SOURCE_PACKAGE}
curl -sLO https://sourceforge.net/projects/pcre/files/pcre/8.44/${PCRE_SOURCE_PACKAGE}

[[ -f ${NGINX_SOURCE_PACKAGE} ]] || { echo "${NGINX_SOURCE_PACKAGE} 不存在"; exit; }
[[ -f ${PCRE_SOURCE_PACKAGE} ]] || { echo "${PCRE_SOURCE_PACKAGE} 不存在"; exit; }

# install pcre
tar xf ${PCRE_SOURCE_PACKAGE} || exit
cd ${PCRE_SOUCRE_DIR}
./configure
make || exit
make install
cd ..

# install nginx
tar xf ${NGINX_SOURCE_PACKAGE} || exit
cd ${NGINX_SOUCRE_DIR}
./configure ${BUILD_OPTS}
make || exit
make install

mkdir -p ${NGINX_INSTALL_DIR}/vhosts
[[ ${NGINX_LOGS} ]] && mkdir -p ${NGINX_LOGS}

cat > ${NGINX_INSTALL_DIR}/confg/nginx.conf << EOF
user ${NGINX_OWNER} ${NGINX_OWNER};
worker_processes  $( awk '/^processor/' ${proc_fs} |sort |uniq |wc -l );
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
    log_format  main  '$remote_addr $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
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
    #include ${NGINX_INSTALL_DIR}/vhosts/*.conf;
}
EOF