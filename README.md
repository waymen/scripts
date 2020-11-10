# sciprts
一些生产环境、练习、学习使用的脚本，都在生产环境使用过

## system_init.sh
用于centos/rhel系统初始化
```
curl -sSL https://raw.githubusercontent.com/waymen/scripts/master/system_init.sh | bash
```

## install_nginx.sh
自动编译安装nginx，默认版本为1.16.1，如果需要安装其它版本，修改脚本中的 NGINX_SOURCE_PACKAGE 变量, 具体查看脚本内容. 可能因为墙的原因无法使用可以复制脚本内容到文件然后执行

```
curl -sSL https://raw.githubusercontent.com/waymen/scripts/master/install_nginx.sh ｜ bash
```
## update-opnessl.sh
自动编译安装openssl至1.1.1f稳定版本，centos系列的openssl版本都比较低，存在一些安全漏洞问题，另外安装一些新的包时也需要新版本的openssl，官方推荐使用openssl1.1.1系列版本
```
curl -sSL https://raw.githubusercontent.com/waymen/scripts/master/update-openssl.sh ｜ bash
```
