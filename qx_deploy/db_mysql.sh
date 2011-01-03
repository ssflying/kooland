#!/bin/sh
#
# 用途：数据库操作
name=`basename $0`

usage() {
    echo "Usage: $name -a <action> -u <user> -p <password> -n <database> -o <dumpfile> -i <inputsql>"
}

if [ $# -lt 6 ]; then
    echo "too few arguments."
    exit 1
fi

while getopts :a:u:p:n:o:i: option
do
    case "$option" in
	a)
	    db_action="$OPTARG" ;;
	u)
	    db_user="$OPTARG" ;;
	p)
	    db_passwd="$OPTARG" ;;
	n)
	    db_name="$OPTARG" ;;
	o)
	    db_bak_name="$OPTARG" ;;
	i)
	    db_input_file="$OPTARG" ;;
	?)
	    echo "Usage: $name -u <user> -p <password> -n <database> -o <dumpfile> -i <inputsql>"
	    exit 1 ;;
    esac
done
shift `expr $OPTIND - 1 `
if [ -z "$db_action" ]; then
    echo "必须指定一个操作动作：bak or update"
    exit 1
fi
for option in db_user db_name
do
    if [ -z \$"$option" ]; then
	echo "必须指定$option"
	exit 1
    fi
done

def_db_name="$db_name"-`date -I`.sql.gz

# 备份数据库
# db_bak <dbname> <dst_file>
db_bak()
{
    local dbname dst_file dst_dir bakcmd free_size limit_size count
    dbname="$1"
    dst_file="$2"
    dst_dir=`dirname "$dst_file"`
    # 检查目录是否存在并创建
    if [ ! -d $dst_dir ]; then
	mkdir -p $dst_dir
	if [ $? -ne 0 ]; then
	    echo "无法创建$dst_dir"
	    return 1
	fi
    else
	echo "目录己存在。"
    fi

    # 检查磁盘分区是否充足, 2G
    free_size=`df $dst_dir | tail -n1 | awk '{print $4}'`
    limit_size=`expr 2 \* 1024 \* 1024`	
    if [ $free_size -lt $limit_size ]; then
	echo "磁盘空间不足，请淸理"
	exit 1
    fi

    # 检查dst_file是否存在
    if [ -e "$dst_file" ]; then
	mv "$dst_file" "$dst_file"-`ls -l ${dst_file}* | wc -l`
    fi

    if echo $dst_file | grep -q gz$; then
	bakcmd="mysqldump -u"$db_user" -p"$db_passwd" $dbname | gzip -1 > $dst_file"
    else
	bakcmd="mysqldump -u"$db_user" -p"$db_passwd" $dbname > $dst_file"
    fi
    echo "====$FUNCNAME===="
    echo "开始备份数据库"
    if [ -z "$db_passwd" ]; then
	echo "请输入数据库密码"
    else
	echo "$bakcmd" | sed "s/$db_passwd/*****/g"
    fi
    eval "$bakcmd"
    if [ $? -ne 0 ]; then
	echo "sql备份出错"
	exit 1
    else
	echo "$dbname 备份完毕"
    fi
}

# 更新数据库
# db_update <db_name> <update_sql>
db_update()
{
    local dbname inputfile
    dbname="$1"
    inputfile="$2"
    if [ ! -f "$inputfile" ]; then
	echo "$inputfile 不存在，请检查."
	return 1
    fi
    echo "====$FUNCNAME===="
    echo "现在导入$inputfile文件"
    mysql -u$db_user -p$db_passwd $dbname < $inputfile
    if [ $? -ne 0 ]; then
	echo "sql语句导入错误"
	return  1
    fi
}

# 

case "$db_action" in
    bak)
	if [ -z "$db_bak_name" ]; then
	    echo "使用默认文件名 $def_db_name"
	    db_bak_name="$def_db_name"
	fi
	db_bak "$db_name" "$db_bak_name"
	;;
    update)
	if [ -z "$db_input_file" ]; then
	    echo "请用-i参数指定导入的sql语句文件。"
	    exit 1
	fi
	db_update "$db_name" "$db_input_file"
	;;
    *)
	echo "unkown action"
	return 1
	;;
esac
