#!/bin/bash
#
# 用途：部署管理奇想服务端代码
#

# 脚本用内部变量
VER="0.1"
CWD=`dirname $0`
NAME=`basename $0`
CONFIG=${CONFIG:-$CWD/conf/default.cfg}
RTEST_CONFIG=$CWD/conf/rtest.cfg
DATE=`date -I`
PYTHON="/usr/bin/python"
SM_LOG="/tmp/sm-log-`date -I`.log"
SM_ERROR_LOG="/tmp/sm-log-`date -I`-error.log"

MULTI="n"
DEFCONFIG="y"

DB_WRAPPER="$CWD/db_mysql.sh"
COMMON_FUNC="$CWD/common-func.sh"
MINA_WRAPPER="$CWD/mina.sh"
EHCACHE_WRAPPER="$CWD/ehcache.sh"
QXC_WRAPPER="$CWD/qxclient.sh"

# log all stdout 
#exec > >(tee -a $SM_LOG)
# log all stderr
#exec 2> >(tee -a $SM_ERROR_LOG)

# 退出代码
# 0 - 正常退出
# 1 - 文件未找到
# 2 - 变量没定义
EXITSTATUS=0
# 检查是否root用户
user=`whoami`
if [ $user != "root" ]; then
    echo "请用root运行该脚本。"
    exit 1
fi

# 检查参数数量
if [ $# -lt 1 ]; then
    echo "本命令需要至少一个参数。"
    exit 1
fi

# 脚本用法提示
usage()
{
    cat << EOF
Usage: $NAME -f <config> <class> <action>

$NAME 用来自动化安装或升级qxserver程序，运行环境自动检查，
清理和启动相关服务。

<config>:  配置文件路径
class: qxserver | hopserver | db | qxclient | ehcache 
action: start | stop | restart | bak | update | check ...
EOF
}

if [ "$1" = "-f" -o "$1" = "--config" ];then
    if [ "$2" = "" ];then
	usage
	exit 1
    elif [ ! -f "$2" ];then
	echo "$2 文件不存在"
	exit 1
    else
	CONFIG="$2"
	DEFCONFIG="n"
	shift 2
    fi
fi

# 命行行参数处理
case "$1" in
    qxserver|qxs) CLASS=qxserver ;;
    database|db) CLASS=database ;;
    qxclient|qxc) CLASS=qxclient ;;
    ehcache) CLASS=ehcache ;;
    hopserver|hops) CLASS=hopserver ;;
    rtest)
	CONFIG="$RTEST_CONFIG"
	DEFCONFIG="t"
	CLASS=rtest
	;;
    virtualserver|vs) CLASS=virtual ;;
    version|-v)
	echo "$NAME版本为：$VER"
	exit 1
	;;
    *)
	echo "$1参数不正确，请看脚本用法。"
	usage
	exit 1
	;;
esac
shift 1

# 检查配置文件是否存在并可读
if [ -r "$CONFIG" -a $DEFCONFIG = "y" ]; then
    echo "使用默认配置文件，$CONFIG。"
    . "$CONFIG"
elif [ -r "$CONFIG" -a $DEFCONFIG = "n" ]; then
    echo "使用用戶指定配置文件 ==> $CONFIG"
    . "$CONFIG"
elif [ -r "$CONFIG" -a $DEFCONFIG = "t" ]; then
    echo "使用外测配置文件 ==> $CONFIG"
    . "$CONFIG"
else
    echo "$CONFIG 不可读，脚本退出。"
    exit 1
fi

# 外理橫版参数
if [ "$CLASS" = "hopserver" ]; then
    MINA_DIR="$HOP_DIR"
    MINA_ARG="$HOP_ARG"
    SVN_MINA_ADDR="$SVN_HOP_ADDR"
    CLASS=qxserver
fi

if [ `echo $MINA_DIR | tr ' ' '\n' | wc -l` -gt 1 ]; then
    MULTI="yes"
fi

# 读入系统变量（JAVA_HOME)等
[ -r /etc/profile ] && . /etc/profile

JAVA=$JAVA_HOME/bin/java
[ -z $JAVA ] && echo "$JAVA程序不存在，退出。" && exit 1

# 构建各种文件名
QXCLIENT_BAK_NAME=$QXCLIENT_ID-bak-$DATE.tar.gz
DB_BAK_NAME=$DB_BAK_DIR/DB-BAK-$DB_NAME-$DATE.sql.gz
DB_UPD_BAK_NAME=$DB_BAK_DIR/update-$DB_NAME-$DATE.sql.gz

### Functions

# 导入通用函数
. $COMMON_FUNC 

# 列出读取的配置文件中重要的变量，并提示是否继续
# 用法：env_show
env_show()
{
    echo "===================="
    echo "当前目录：`pwd`"
    echo "本机IP: `showip eth0`"
    echo "主机名: `hostname`"
    echo 
    echo "svn地址： $SVN_PATH"
    echo
    echo "Mina配置路径：$MINA_DIR"
    echo "Mina配置文件：$MINA_CONFIG $HIBER_CONFIG $JOBS_CONFIG"
    echo "Mina svn地址：$SVN_MINA_ADDR"
    echo
    echo "Qxclient路径: $QXCLIENT_DIR"
    echo "Qxclient备份名: $QXCLIENT_BAK_NAME"
    echo "Qxclient svn地址：$SVN_CLIENT_ADDR"
    echo
    echo "Database名称：$DB_NAME"
    echo "Database更新sql文件目录: $DB_IMPORT_DIR"
    echo "Database更新sql svn地址：$SVN_DB_ADDR"
    echo 
    echo "Java命令路径：$JAVA"
    echo "Python命令路径: $PYTHON"
    echo "===================="

    if_go_on "上述信息是否无误"
}

# 检查xml语法
# chxml <file1> <file2> ...
chkxml()
{
    local xml
    [ ! -x $PYTHON ] && echo "请安装python环境。" && exit 1
    for xml in "$@"
    do
	tempfile=$(mktemp -p /tmp 2>/dev/null)
	echo "开始检查$xml的语法..."
	$PYTHON $XML_PARSE $xml 2>&1 | tail -n 1 > $tempfile
	$PYTHON $XML_PARSE $xml > /dev/null 2>&1
	if [ $? -ne 0 ]; then
	    echo "$xml 有语法错误，错误信息为："
	    cat $tempfile
	    rm -f $tempfile
	    exit 1
	fi
	echo "$xml 语法ok"
	rm -f $tempfile
    done
}

# 检查配置文件
chkconfig()
{
    local tmp
    chkxml $MINA_CONFIG $HIBER_CONFIG
    [ -z "$CHK_TAGS" ] && echo "请检查 $CONF 文件中的 CHK_TAGS 是否设置" && exit 1
    if_go_on "是否继续？"
    echo "开始检查环境变量值是否设定正确..."
    echo "======================================================================="
    for tag in $CHK_TAGS
    do
	tmp=`grep $tag $MINA_CONFIG | sed -r 's/\s+//g' | sed 's/^<.*>\([^<].*\)<.*>$/\1/'`
	printf "%-20s%-20s\n" $tag $tmp
    done
    for tag in $HIBER_TAGS
    do
	tmp=`grep $tag $HIBER_CONFIG | sed -r 's/\s+//g' | sed 's/^<.*>\([^<].*\)<.*>$/\1/'`
	if [ $tag == "connection.url" ]; then
	    tmp=`echo $tmp | awk -F '?' '{print $1}'`
	fi
	printf "%-20s%-20s\n" $tag $tmp
    done
    echo "======================================================================="
    echo
}

# 检查运行主机环境
chkres()
{
    local capa_k capa_h part mem min_size
    declare -i min_size mem
    echo "开始检查系统资源是否充足..."
    echo "======================================================================="
    capa_k=$(df $MINA_DIR | awk '{if(NR==2) print $4}')
    capa_h=$(df -h $MINA_DIR | awk '{if(NR==2) print $4}')
    part=$(df -h $MINA_DIR | awk '{if(NR==2) print $1}')
    echo "$MINA_DIR 所在分区 $part 剩余磁盘容量为 $capa_h "
    min_size=$((`echo $MIN_SIZE | tr -d [mM]` * 1024))
    if [ $capa_k -lt $min_size ]; then
	echo "且小于${CONF}中设定的最小值$MIN_SIZE, 脚本退出。"
	exit 1
    fi
    if [ -d $MINA_LOG -a -w $MINA_LOG ]; then
	echo "$MINA_LOG 存在并可写入"
    else
	echo "请手动检查$MINA_LOG 目录。"
	exit 1
    fi
    mem=$(free -m | grep Mem | awk '{print $4+$6+$7}')
    echo "主机可用内存大小为：${mem}M"
    echo "======================================================================="
    echo

}

# rtest <action>
# receive from the main function
rtest()
{
    local mina_dir

    if [ $# -gt 2 ] ; then
	echo "each time, only one action please."
	exit 1
    fi

    case "$1" in
	start)
	    for mina_dir in $RTEST_MINA_DIR
	    do
		if echo "$mina_dir" | grep -q "hop"; then
		    $MINA_WRAPPER -a start -d "$mina_dir" -o "$HOP_ARG"
		else
		    $MINA_WRAPPER -a start -d "$mina_dir" -o "$MINA_ARG"
		fi
	    done
	    ;;
	stop)
	    for mina_dir in $RTEST_MINA_DIR
	    do
		$MINA_WRAPPER -a stop -d "$mina_dir" 
	    done
	    ;;
	restart)
	    for mina_dir in $RTEST_MINA_DIR
	    do
		$MINA_WRAPPER -a stop -d "$mina_dir" 
		if echo "$mina_dir" | grep -q "hop"; then
		    $MINA_WRAPPER -a start -d "$mina_dir" -o "$HOP_ARG"
		else
		    $MINA_WRAPPER -a start -d "$mina_dir" -o "$MINA_ARG"
		fi
	    done
	    ;;
	update)
	    for mina_dir in $RTEST_MINA_DIR
	    do
		mina_stop "$mina_dir"
		mina_update "$mina_dir"
	    done
	    ;;
	qxcu|qxcupdate)
	    qxc_update --nocdn
	    ;;
	db)
	    shift 1
	    db "$@"
	    ;;
	status)
	    for mina_dir in $RTEST_MINA_DIR
	    do
		mina_status "$mina_dir"
	    done
	    ;;
	*)
	    echo "wrong action! Please use: rtest <start|stop|restart>"
	    exit 1
	    ;;
    esac
}

# wrapper for qxserver func
qxs()
{
    if [ $# -gt 1 ]; then
	echo "too many arguments."
	exit 1
    fi
    case $1 in
	start)
	    $MINA_WRAPPER -a start -d "$MINA_DIR" -o "$MINA_ARG"
	    ;;
	stop)
	    $MINA_WRAPPER -a stop -d "$MINA_DIR" 
	    ;;
	restart)
	    $MINA_WRAPPER -a stop -d "$MINA_DIR" 
	    $MINA_WRAPPER -a start -d "$MINA_DIR" -o "$MINA_ARG"
	    ;;
	bak)
	    $MINA_WRAPPER -a bak -d "$MINA_DIR" 
	    ;;
	update)
	    $MINA_WRAPPER -a bak -d "$MINA_DIR" 
	    $MINA_WRAPPER -a update -d "$MINA_DIR" 
	    ;;
	restore)
	    $MINA_WRAPPER -a restore -d "$MINA_DIR" ### need fixed
	    ;;
	*)
	    echo "unknown options, exit..."
	    exit  1
	    ;;
    esac
}

# wrapper for qxclient func
qxc()
{
    if [ $# -gt 1 ]; then
	echo "too many arguments."
	exit 1
    fi
    case $1 in
	update)
	    $QXC_WRAPPER -a bak -d $QXCLIENT_DIR -o $QXCLIENT_BAK_NAME
	    $QXC_WRAPPER -a update -d $QXCLIENT_DIR 
	    ;;
	bak)
	    $QXC_WRAPPER -a bak -d $QXCLIENT_DIR -o $QXCLIENT_BAK_NAME
	    ;;
	restore)
	    $QXC_WRAPPER -a bak -d $QXCLIENT_DIR -i $QXCLIENT_BAK_NAME ### need fixed
	    ;;
	*)
	    echo "unkown arguments"
	    exit 1
	    ;;
    esac
}

# wrapper for db manipulate funcs
db()
{
    if [ $# -gt 1 ]; then
	echo "too many arguments."
	exit 1
    fi
    case $1 in
	bak)
	    $DB_WRAPPER -a bak -u "$DB_USER" -p "$DB_PASSWD" -n "$DB_NAME" -o "$DB_BAK_NAME"
	    ;;
	update)
	    svn update $DB_IMPORT_DIR --username $SVN_USER --password $SVN_PASSWD
	    for file in "$DB_IMPORT_DIR"/*.sql
	    do
		$DB_WRAPPER -a update -u "$DB_USER" -p "$DB_PASSWD" -n "$DB_NAME" -i "$file"
	    done
	    ;;
	twobak)
	    $DB_WRAPPER -a bak -u "$DB_USER" -p "$DB_PASSWD" -n "$DB_NAME" -o "$DB_UPD_BAK_NAME"
	    ;;
	*)
	    echo "unkown arguments"
	    exit 1
	    ;;
    esac
    return 0
}

### Main

echo "本次运行脚本的曰志文件名为 $SM_LOG"
cat /dev/null > $SM_LOG
echo "[`date "+%Y-%m-%d %H:%M:%S"`] 脚本启动......" | tee -a $SM_LOG

case $CLASS in
    rtest)
	rtest "$@"
	;;
    qxserver)
	echo "对qxserver执行: $@"
	qxs "$@"
	;;
    qxclient)
	echo "对qxclient执行: $@"
	qxc "$@"
	;;
    ehcache)
	echo "运行ehcache $@"
	"$EHCACHE_WRAPPER" "$EHCACHE" "$@"
	;;
    virtual)
	mina_start "$MINA_DIR" "$VIRTUAL_ARG"
	;;
    database)
	echo "对数据库执行: $@"
	db "$@"
	;;
    external)
	ext "$@"
	;;
esac
