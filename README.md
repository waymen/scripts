# sciprts
一些生产环境、练习、学习使用的脚本

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

