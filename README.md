# sciprts
一些生产环境、练习、学习的脚本

## system_init.sh
用于centos/rhel系统初始化，使用
```
curl -sSL https://raw.githubusercontent.com/waymen/scripts/master/system_init.sh | bash
```

## install_nginx.sh
用于脚本自动编译安装nginx，默认版本为1.16.1，如果需要安装其它版本，需要修改脚本中的NGINX_SOURCE_PACKAGE变量。以下使用方式.

方式1 (需要科学上网):
```
curl -shttps://raw.githubusercontent.com/waymen/scripts/master/install_nginx.sh ｜ bash
```
方式2:
```
git clone git@github.com:waymen/scripts.git
cd scripts
./install_nginx.sh
```
