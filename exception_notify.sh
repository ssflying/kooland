#!/bin/sh
## 用途：用inotify监控syserr.log的改动，并提取exception字串的信息，发送报警短信

# 短信接受邮箱
emails="china_mobile_number@139.com"
# inotifywait的路径
watch_prog="/usr/bin/inotifywait"
# 错误日志目录
error_dir=/qx/app/qxserver/logs/syserr
# 错误日志文件
error_file=/qx/app/qxserver/logs/syserr/syserr.log
# 本机ip
ip_host=`/sbin/ifconfig eth0|grep "inet addr"|awk '{print $2}'|awk -F : '{print $2}'`
# 可忽略的错误信息
pattern="FileNotFoundException|EOFException"

[ ! -x $watch_prog ] && exit
while $watch_prog -qq -e modify $error_dir;do
	if grep Exception $error_file | egrep -v "$pattern"  >/dev/null 2>/dev/null; then
		date_time=`date +"%F %T"`
		exception=`grep Exception $error_file | egrep -v "$pattern" | uniq | tail -n1`
		[ -n "$exception" ] && echo -e "服务器: $ip_host\nException:\n$exception" | mutt -s "$date_time qxserver_exceptioned" $emails
		sleep 3600
	fi
done
