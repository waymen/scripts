#!/usr/bin/env bash
# 通过ss命令获取一些socket信息，可以提供给zabbix-server采集、监控网络的状态、画图、报警等
# 含ipv6的信息

LISTEN() {
  # 获取所有的监听数
  ss state all | grep -c '^LISTEN'
}

ESTAB() {
  # 获取所有的ESTAB数
  ss state all | grep -c '^ESTAB'
}

CLOSE-WAIT() {
  # 获取所有的CLOSE-WAIT数
  ss state all | grep -c '^CLOSE-WAIT'
}

TIME-WAIT() {
  # 获取所有的TIME-WAIT数
  ss state all | grep -c '^TIME-WAIT'
}

FIN-WAIT-1() {
  # 获取所有FIN-WAIT-1数
  ss state all | grep -c '^FIN-WAIT-1'
}

FIN-WAIT-2() {
  # 获取所有FIN-WAIT-2数
  ss state all | grep -c '^FIN-WAIT-2'
}

LAST-ACK() {
  # 获取所有的LAST-ACK数
  ss state all | grep -c '^LAST-ACK'
}

case ${1} in
  listen)
    LISTEN
    ;;
  estab)
    ESTAB 
    ;;
  close-wait)
    CLOSE-WAIT 
    ;;
  time-wait)
    TIME-WAIT
    ;;
  fin-wait-1)
    FIN-WAIT-1
    ;;
  fin-wait-2)
    FIN-WAIT-2
    ;;
  last-ack)
    LAST-ACK
    ;;   
  *)
  echo "${0} {listen|estab|close-wait|time-wait|fin-wait-1|fin-wait-2|last-ack}"
esac