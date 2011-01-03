#!/bin/bash

## 请把各类可写成标准函数的脚本放在这里

# 输出信息并提示是否继续
# 用法：if_go_on "提示语句"
if_go_on()
{
    local yn
    local tag="(请输入yes或no)"

    read -ep "${1}$tag" yn
    if [ $yn = "y" -o $yn = "Y" -o $yn = "yes" -o $yn = "Yes" ]; then
	return
    else
	echo "脚本终止运行。"
	exit 1
    fi
}

# 判断某变量是否仅包含数字
# isnum <arg>
isnum()
{
    if echo $1 | grep -Eq '^[0-9]+$'; then
	return 0
    else
	return 1
    fi
}

# 判断主机的某port是否打开
# isporton <host> <port>
isporton()
{
    local host port
    [ $# -ne 2 ] && exit
    host=$1
    port=$2
    nc -z -w 1 $host $port
}

# 检查pid是否存在
# pid_chk <pid>
pid_chk()
{
    local pid
    pid=$1
    ps -p $pid > /dev/null 2>/dev/null
    return $?
}

# chk_url <url>
# 检查某个url是否可用
chk_url()
{
    wget -O /dev/null "$1" 2>&1 | grep -q '200 OK'
}

### errors echo && exit
die() {
	echo "$@" >&2
	exit 1
}

# showip <interface>
showip()
{
    ifconfig $1 | grep 'inet addr' \
    | awk '{print $2}' | awk -F: '{print $2}'
}


# 监控一个PID是否存在
# monitor_pid pid
monitor_pid() {
    local pid
    pid=$1
    while sleep 1
    do
	kill -0 $pid || break
    done
}

