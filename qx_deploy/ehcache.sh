#!/bin/bash

. /etc/profile 

if [ $# -gt 2 ]; then
    echo "用法：ehcache <start|stop|restart>"
    exit 1
fi

if [ -z "$JAVA_HOME" ]; then
    echo "JAVA_HOME未定义，脚本退出。"
    exit 1
fi

java="$JAVA_HOME"/bin/java 
log=/var/log/ehcache.log
ehcache_dir="$1"
action="$2"
if ! [ -d "$ehcache_dir" ]; then
    echo "$ehcache_dir 不是一个目录"
    exit 1
fi
pid_file="$ehcache_dir"/ehcache.pid

ehcache_start() {
    ( cd "$ehcache_dir"/bin
    $java -server -Xmx1g -jar ../lib/ehcache-standalone-server-1.0.0.jar 7070 ../war > "$log" &
    echo $! > "$pid_file"
    )
    return 0
}

ehcache_stop() {
    if kill `cat $pid_file`; then
	echo "stop ehcache normally"
    else
	echo "ehcache can't be killed"
	echo "and its pid: `cat $pid_file`"
    fi
}

case $action in
    start)
	ehcache_start
	;;
    stop)
	ehcache_stop
	;;
    restart)
	ehcache_stop
	sleep 3
	ehcache_start
	;;
    *)
	echo "未知参数。"
	;;
esac

