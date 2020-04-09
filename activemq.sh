#!/bin/bash
# chkconfig: 35 20 79    
# description:  start or stop, restart activemq server

JAVA_HOME="/usr/local/jdk"
ACTIVEMQ_HOME="/opt/activemq"
PATH=${ACTIVEMQ_HOME}/bin:${JAVA_HOME}/bin:${PATH}

export ACTIVEMQ_HOME JAVA_HOME PATH

case "$1" in
  start)
    activemq start
    ;;
  stop)
    activemq stop
    ;;
  status) 
    activemq status
    ;;
  restart) 
    activemq restart
    ;;
  *)
    echo "Usage: $0 {start|stop|status|restart}"
    ;;
esac
exit $?