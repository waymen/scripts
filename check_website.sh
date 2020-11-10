#!/bin/bash
# 检测网站的状态码, 并记录日志

# variables
logfile="/tmp/${0##*/}.log"                  # 日志文件
user_agent="Mozilla/5.0"                     # http用户端代理类型
connect_timeout=3                            # 连接超时时间

urls=( "www.baidu.com" "www.qq.com" "www.163.com" 
       "www.hao123.com" "www.sina.com" "www.taobao.com" )

# functions
print() { printf "%s\n" "$*"; }               # 对printf一个包装, 用于打印
now() { date +"%Y-%m-%d %H:%M:%S"; }          # 获取当前时间, 格式是YYYY-mm-dd-HH-MM-SS

log() {
  # Write the message to the log file.
  msg="$*"
  [[ ${msg} ]] || return 1
  print "$( now ) ${msg}" >> ${logfile} 2> /dev/null
}

for url in ${urls[@]}; do
  { 
    http_code=$( curl --user-agent "${user_agent}" -o /dev/null -s -w %{http_code} \
                 --connect-timeout ${connect_timeout} ${url} )

    if [[ ${http_code} -ne 200 ]]; then
      msg="${url} is down, status_code: ${http_code}"
      print ${msg}; log ${msg}  # 记录日志时间与检测时间不够匹配, 希望能打印颜色
    else
      msg="${url} is up, status_code: ${http_code}"
      print ${msg}; log ${msg}
    fi
  } &     # 希望能够控制多进程的个数
done
wait
