#!/bin/bash
# 说明: 此脚本用于每天定时备份并切割mysql的错误日志，然后保留多少天(取决于LOG_KEEP_DAY变量值)，防止占满磁盘
# 此脚本的权限应该设置为700权限并只能root用户执行, 最后添加到crontab定时执行

##################################### variables #########################################
MYSQL_USER="your_user"                          # 用户名               
MYSQL_PASSWD="your_password"                    # 密码
MYSQL_HOST="localhost"                          # 主机，默认localhost
MYSQL_PORT="3306"                               # 端口
MYSQL_CHARSET="utf8mb4"                         # 客户端编码
MYSQL_BIN=                                      # mysql工具命令路径，默认取系统的环境变量, 除非指定
MYSQL_ERRORLOG_BACKUPDIR="/data/logs/mysql"     # mysql错误日志备份目录
SCRIPT_LOG=                                     # 记录脚本操作日志, 默认为/tmp/script_name.sh.log，除非指定
LOG_KEEP_DAY=15                                 # 错误日志保留天数

#################################### functions ##########################################
print() { printf "%s\n" "$*"; }                 # 对printf一个包装, 用于打印
now() { date +"%Y-%m-%d-%H-%M-%S"; }            # 获取当前时间, 格式是YYYY-mm-dd-HH-MM-SS
yesterday() { date -d 'yesterday' '+%Y%m%d'; }  # 获取昨天的时间，格式是YYYYmmdd

log() {   
  # 写入日志到文件，格式是: 时间  内容
  local msg="$*"
  [[ -z ${msg} ]] && return 1
  print "$( now ) ${msg}" >> ${SCRIPT_LOG} 2> /dev/null
}

mysql_checklogin() {
  # 检测mysql服务
  [[ $( ss -tnl | grep -c ${MYSQL_PORT} ) -eq 0 ]] && return 1  # 是否运行
  [[ $( mysql_execute "select user();") ]] || return 1          # 是否能够登陆
  return 0
}

mysql_execute() {
  # 包装一个mysql执行命令的函数
  local cmd="$*"
  mysql -u ${MYSQL_USER} \
  -p${MYSQL_PASSWD} \
  -h ${MYSQL_HOST} \
  -P ${MYSQL_PORT} \
  --default-character-set="${MYSQL_CHARSET}" \
  -s \
  -N \
  -e "${cmd}" 2> /dev/null
}

flush_mysql_errorlog() {
  # 重新生成新的错误日志文件
  mysql_execute "flush error logs;"
}

set_variables() {
  # 设置环境变量
  PATH="/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin"
  [[ -z ${SCRIPT_LOG} ]] && SCRIPT_LOG="/tmp/.${0##*/}.log"
  [[ -z ${MYSQL_BIN} ]] || PATH=${MYSQL_BIN}:${PATH}
  export MYSQL_USER MYSQL_PASSWD MYSQL_HOST \
         MYSQL_ERRORLOG_BACKUPDIR \
         MYSQL_PORT MYSQL_CHARSET MYSQL_BIN \
         LOG_KEEP_DAY SCRIPT_LOG PATH
}

main() {
  # 入口函数
  [[ ${UID} -ne 0 ]] && { 
    local msg="必须使用root用户运行此脚本"
    print ${msg}; exit 1
  }
  # 定义变量
  set_variables

  # 检测是否能登陆
  mysql_checklogin || {
    local msg="mysql无法登陆: 请检测服务是否启动或连接信息是否准确"
    print ${msg}; log ${msg}; exit 1
  }
  
  # 获取mysql错误日志文件路径及日志文件名
  local mysql_error_log=$( mysql_execute "show variables like 'log_error';" | awk '{print $NF}') # eg: /data/logs/mysql/error.log
  local mysql_error_logbase=$( basename ${mysql_error_log} ) # eg: error.log

  # 进入到错误日志备份目录，flush重新生成新的日志，重命名、压缩、最后删除LOG_KEEP_DAY天以前的文件
  [[ -d ${MYSQL_ERRORLOG_BACKUPDIR} ]] || mkdir -p ${MYSQL_ERRORLOG_BACKUPDIR}  # 没有就创建
  cd ${MYSQL_ERRORLOG_BACKUPDIR}          # 切换目录
  log "进入到${MYSQL_ERRORLOG_BACKUPDIR}目录"

  local new_mysql_error_log="${mysql_error_logbase}-$( yesterday )"  # 新日志文件名, eg: error-20200211
  \mv ${mysql_error_log} ${new_mysql_error_log}        # 重命名
  log "将${mysql_error_log}重命名为${new_mysql_error_log}"

  flush_mysql_errorlog                                # 刷新, 产生新的日志文件
  log "flush生产新的日志文件"

  gzip -9 ${new_mysql_error_log}                      # 压缩, 会生成.gz后缀的压缩文件, eg: error-20200211.gz
  log "压缩日志文件"

  find -type f -name "${mysql_error_logbase}-*.gz" -mtime +${LOG_KEEP_DAY} | xargs rm -rf  # 找到符合条件的旧日志文件然后删除
  log "查找旧文件并删除"

  exit
}

# 执行入口函数
main
