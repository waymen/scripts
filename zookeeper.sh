#!/bin/bash
# chkconfig: 35 20 70  
# description: zookeeper systemV.

ZOO_HOME="/opt/zookeeper"
JAVA_HOME="/usr/local/jdk"
PATH="${ZOO_HOME}/bin:${JAVA_HOME}/bin:$PATH"

export ZOO_HOME JAVA_HOME PATH

case "$1" in
  start)
    zkServer.sh start
    ;;  
  stop) 
    zkServer.sh stop
    ;;
  restart) 
    zkServer.sh restart
    ;; 
  status) 
    zkServer.sh status
    ;;  
  *)  
    echo "${0} {start|stop|restart|status}"
    ;;
esac