#!/bin/bash

### mina应用的管理：start, stop restart status

date=`date -I`
name=`basename $0`
cwd=`dirname $0`
common_func="$cwd/common-func.sh"
db_connect="$cwd/perl/dbiconnect.pl"
actions="start | stop | restart | bak | restore"

# 导入通用函数
. $common_func 
. /etc/profile
# 环境变量
[ -z "$JAVA_HOME" ] && die "JAVA_HOME变量未定义，脚本退出。" 
javabin=${JAVA:-$JAVA_HOME/bin/java}
! [ -x "$javabin" ] && die "$javabin 不可执行，脚本退出。"


usage() {
    cat << EOF
Usage: $name -a <action> -d <mina_dir> -o <mina arguments> -i <mina restore file>"
	<action>: $actions
	<mina_dir>: 如/qx/app/qxserver
	<mina arguments>: qxserver(com.diwenculture.qx.QxServer) hopserver(com.kooland.minicore.HopServer)
EOF
}

if [ $# -lt 4 ]; then
    usage
    die "too few arguments."
fi

while getopts :a:d:o:i: option
do
    case "$option" in
	a)
	    mina_action="$OPTARG" ;;
	d)
	    mina_base="$OPTARG" ;;
	o)
	    mina_option="$OPTARG" ;;
	i)
	    mina_restore_file="$OPTARG" ;;
	?)
	    usage 
	    exit 1 ;;
    esac
done
shift `expr $OPTIND - 1`

[ -z "$mina_action" ] &&  die "必须指定一个操作动作：start | stop | restart | bak .."

[ -d "$mina_base" ] ||  die "$mina_base 不存在。"

echo "$mina_action" | egrep -q "start|restart" && [ -z "$mina_option" ] && \
    die "start|restart参数需要用 -o 指定启动参数。"

echo "$mina_action" | grep -q "restore" && [ -z "$mina_restore_file" ] && \
    die "restore参数需要用 -i 指定用来恢复的备份文件。"

# 判断程序是否运行
# if_mina_run <mina_dir>
if_mina_run()
{
    local mina_dir
    mina_dir="$1"
    pgrep -u root -f "$mina_dir"/sh >/dev/null
}

# db_chk 
# db_chk <mina_dir>
db_chk()
{
    local mina_dir
    local hiber_cfg db_user db_pass db_name host_port dsn 

    if  [ ! -x $db_connect ]; then
	echo "$db_connect 不可执行。"
	exit 1
    fi
    mina_dir=$1
    hiber_cfg=$mina_dir/bin/hibernate.cfg.xml
    db_user=$(grep connection.username $hiber_cfg | awk -F '[<>]' '{print $3}') 
    db_pass=$(grep connection.pass $hiber_cfg | awk -F '[<>]' '{print $3}') 
    db_name=$(grep connection.url $hiber_cfg | awk -F '[/?]' '{print $4}')
    host_port=$(grep connection.url $hiber_cfg | awk -F '[/?]' '{print $3}')
    dsn="dbi:mysql:""$db_name"":$host_port"

    if $db_connect "$dsn" "$db_user" "$db_pass" 2>&1 >/dev/null; then
	return 0
    else
	return 1
    fi
}
# mina_chk <mina_dir>
mina_chk()
{
    local mina_dir
    local ehcache_url
    mina_dir=$1
    ehcache_url="http://"$(grep ehcache_1 $mina_dir/bin/config.xml | awk -F '[<>]' '{print $3}')"/ehcache/rest"

    if ! chk_url "$ehcache_url"; then
	echo "ehcache 未成功启动，请检查"
	exit 1
    fi
    if ! db_chk "$mina_dir"; then
	echo "不能连接数据库。"
	exit 1
    fi

}

# 当前的mina 状态信息
# mina_status <mina_dir>
mina_status()
{
    local mina_dir pid_file
    mina_dir="$1"
    pid_file="$mina_dir"/"${mina_dir##*/}".pid
    [ ! -r $pid_file ] && die "pid 文件未发现，请下次用脚本启动mina"
    pid=`cat $pid_file`
    echo "========================================================="
    echo "当前运行的mina($mina_dir)进程信息为："
    ps -p $pid u
    echo 
}

# 初次安装mina ,并从$SKEL中复制配置文件模板
# mina_initial <mina_dir>
#mina_initial()
#{
#    local mina_dir
#    mina_dir="$1"
#    [ ! -d "$mina_dir" ] && mkdir -p "$mina_dir"
#    if echo $mina_dir | grep -q hop; then
#	SVN_MINA_ADDR=$SVN_HOP_ADDR
#    fi
#    svn co "$SVN_MINA_ADDR" --username "$SVN_USER" --password "$SVN_PASSWD" "$mina_dir"
##    [ ! -f "$mina_dir"/bin/config.xml ] && \
##    if_go_on "是否自动从 $SKEL 中复制配置文件模板？"
##    cp -fv "$SKEL"/* "$mina_dir"/bin/
#}

# 启动mina
# mina_start <mina_dir> <mina_arg>
mina_start()
{
    local mina_dir mina_arg pid_file rc
    local jars
    mina_dir="$1"
    mina_arg="$2"
    pid_file="$mina_dir"/"${mina_dir##*/}".pid

    # 启动前检查是否有以mina_dir启动的进程
    if if_mina_run "$mina_dir"; then
	echo "there is already a $mina_dir process running."
	ps -fp `pgrep -u root -f "$mina_dir"/sh`
	if_go_on "Please make sure whether to kill it or not?"
    fi

    # 启动mina前，检查ehcache是否启动完全 ，是否可以连接数据库。
    mina_chk "$mina_dir"

    (
    cd "$mina_dir"
    jars=`ls ./lib/*/*.jar | xargs echo | sed -e 's/ /:/g'`
    echo "====$FUNCNAME===="
    echo "starting $mina_dir..."
    $javabin -cp ./bin/:$jars "$mina_arg"  -Dmyapp.name="$mina_dir/sh" 1>/dev/null &
    sleep 1
    echo $! > $pid_file
    )

    rc=1
    until [ $rc -eq 0 ]
    do
#	if if_mina_run "$mina_dir" ; then
	if kill -0 `cat "$pid_file"` ; then
	    echo "start $mina_dir successful..."
	    mina_status "$mina_dir"
	    rc=0
	fi
	sleep 1
    done
}

# 关闭mina
# mina_stop <mina_dir>
mina_stop()
{
    local mina_dir pid_file mina_id
    mina_dir="$1"
    mina_id="${mina_dir##*/}"
    pid_file="$mina_dir"/"$mina_id".pid

    echo "====$FUNCNAME===="
    echo "停止前 $mina_dir 进程的状态:"
    mina_status "$mina_dir"

    if [ -e "$pid_file" ]; then
	pid=`cat $pid_file`
	if pid_chk $pid; then
	    echo "关掉 $mina_id 进程..."
	    kill $pid
	    sleep 1
	    if ! pid_chk $pid; then
		echo "$mina_id 成功停止"
	    else
		die "$mina_id 关闭失败"
	    fi
	else
	    die "$pid_file 中不包含有效的pid信息，可能是上次未用脚本启动。"
	fi
    else
	die "$pid_file不存在 ，可能是上次未用脚本启动。"
    fi
}

# 备份mina
# mina_bak <mina_dir>
mina_bak()
{
    local mina_dir mina_bak_name mina_id
    mina_dir=$1
    mina_id=${mina_dir##*/}
    mina_bak_name="$mina_id"-bak-$date.tar.gz
    echo "====$FUNCNAME===="
    ( cd $mina_dir
      cd ..
      echo "开始备份  $mina_dir"
      if [ -e $mina_bak_name ]; then
	  mv "$mina_bak_name" "$mina_bak_name"-`ls -l ${mina_bak_name}* | wc -l`
      fi
      tar --exclude=logs  -czf $mina_bak_name $mina_id
      if [ -r $mina_bak_name ]; then
          echo "备份成功，且备份文件大小为："
          ls -lh $mina_bak_name
	  echo "进入一下歩。"
      else
	  die "mina备份失敗"
      fi
    )
}

# mina更新
# mina_update <mina_dir>
mina_update()
{
    local mina_dir
    mina_dir="$1"
    echo "====$FUNCNAME===="
    if if_mina_run "$mina_dir";then
	echo "$mina_dir is running, please stop it before update."
	exit 1
    fi
    svn update $mina_dir --accept theirs-full
}

# 备份文件的指定待修改
# mina_restore <mina_dir> <bak_file>
mina_restore()
{
    local mina_dir bak_file
    mina_dir="$1"
    bak_file="$2"

    if ! [ -f "$bak_file" ]; then
	die "$bak_file不存在。"
    fi
    
    echo "====$FUNCNAME===="
    if [ -e "$mina_dir" ]; then
	( cd "$mina_dir"
	  rm -rfv `find . -maxdepth 1 -type d ! \( -name logs -o -name . \)`
	  cd ..
	  tar -zxvf "$bak_file"
	)
    else
	die "$mina_dir不存在"
    fi
}

case "$mina_action" in
    start)
	mina_start "$mina_base" "$mina_option"
	;;
    stop)
	mina_stop "$mina_base"
	;;
    restart)
	mina_stop "$mina_base"
	mina_start "$mina_base" "$mina_option"
	;;
    bak)
	mina_bak "$mina_base"
	;;
    restore)
	mina_restore "$mina_base" "$mina_restore_file"
	;;
    update)
	mina_update "$mina_base"
	;;
    *)
	echo "可用的动作为：$actions"
	die "未知动作."
	;;
esac
