#!/bin/bash
#
# 奇想运营更新
#
qxserver=$HOME/hostlist/qxserver
hopserver=$HOME/hostlist/hopserver
qxclient=$HOME/hostlist/qxclient
scripts=$HOME/hostlist/scripts
user_home=/home/ssflying

! [ -x /usr/bin/parallel-ssh ] && echo "no pssh installed" && exit

. $HOME/scripts/common-func.sh

### 开启db-157的端口
ssh xyd-157 "sudo iptables -t nat -A PREROUTING -i eth0 -p tcp --dport 51822 -j DNAT --to-destination 192.168.0.155:22"
sleep 1
if ! isporton 192.168.1.1 51822; then
    echo "db-157 not available, exit, to fix manually"
    exit
fi

### 更新所有脚本
parallel-ssh -i -h $scripts "sudo svn update /qx/app/scripts/ --accept=theirs-full"

if_go_on "停止server"
### 停止server
parallel-ssh -i -h $qxserver "sudo /qx/app/scripts/qxsm.sh qxserver stop"
parallel-ssh -i -h $hopserver "sudo /qx/app/scripts/qxsm.sh hopserver stop"

### 数据库操作
#ssh db-157 "sudo /qx/app/scripts/qxsm.sh db bak"
#if_go_on "更新数据库"
#ssh db-157 "sudo /qx/app/scripts/qxsm.sh db update"
#ssh db-157 "sudo /qx/app/scripts/qxsm.sh db twobak"

if_go_on "请手动执行数据库备份和更新"

### 更新server
parallel-ssh -i -h $qxserver "sudo /qx/app/scripts/qxsm.sh qxserver update"
parallel-ssh -i -h $hopserver "sudo /qx/app/scripts/qxsm.sh hopserver update"
# 打开抓包
parallel-ssh -i -h $qxserver "sudo sed -i.bak '/iflogpackage/s/false/true/' /qx/app/qxserver/bin/config.xml"

### 更新客戶端
parallel-ssh -i -h $qxclient "sudo /qx/app/scripts/qxsm.sh qxclient update"

### 更新完毕后重启
## 重启ehcache
ssh db-157 "sudo /qx/app/scripts/qxsm.sh ehcache restart"

sleep 30
## 重启server
parallel-ssh -i -h $qxserver "sudo /qx/app/scripts/qxsm.sh qxserver start"
parallel-ssh -i -h $hopserver "sudo /qx/app/scripts/qxsm.sh hopserver start"

### 关闭db-157的端口
ssh xyd-157 "sudo iptables -t nat -D PREROUTING -i eth0 -p tcp --dport 51822 -j DNAT --to-destination 192.168.0.155:22"
sleep 1
if isporton 192.168.1.1 51822; then
    echo "db-157 is still on, try to fix it."
    exit
fi
