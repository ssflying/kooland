#!/bin/bash

name=`basename $0`
cwd=`dirname $0`
common_func="$cwd/common-func.sh"
actions="bak | update | restore"

# 导入通用函数
. $common_func 

# 用法
usage() {
    cat << EOF
Usage: $name -a <action> -d <qxclient_root> -o <bak_file> -i <restore_file>
actions: $actions
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
	    qxc_action="$OPTARG" ;;
	d)
	    qxclient_root="$OPTARG" ;;
	o)
	    qxc_bak_name="$OPTARG" ;;
	i)
	    qxc_restore_file="$OPTARG" ;;
	?)
	    usage 
	    exit 1 ;;
    esac
done
shift `expr $OPTIND - 1`

[ -z "$qxc_action" ] &&  die "必须指定一个操作动作：bak | update | restore"
[ -d "$qxclient_root" ] && qxclient_id=${qxclient_root##*/} ||  die "$qxclient_root 不存在。"
echo "$qxc_action" | grep -q "restore" && ! [ -f "${qxclient_root%$qxclient_id}/$qxc_restore_file" ] && \
    die "restore参数需要用 -i 指定用来恢复的备份文件。"
echo "$qxc_action" | grep -q "bak" &&  [ -z "$qxc_bak_name" ] && \
    die "restore参数需要用 -o 指定用来备份文件名。"

# 修改qxclient的版本号
# old_ver从start/index.html文件中提取
# new_ver为更新时的date 
# tweak_version
tweak_version()
{
    local old_ver new_ver
    old_ver=$(grep 'addparm' "$qxclient_root"/bin-release/start/index.html |  awk -F '["=]' '{print $4}')
    new_ver=$(date +%m%d)
    echo "====$FUNCNAME===="
    echo "sed -i "s/$old_ver/$new_ver/g" "$qxclient_root"/bin-release/start/index*"
    sed -i "s/$old_ver/$new_ver/g" "$qxclient_root"/bin-release/start/index*
}

# qxclient的CDN更新
cdn_update()
{
    local src dst host user passwd passwd_file
    src="$qxclient_root"
    dst="517qx"
    host="foo.cdnhost.com"
    user="username"
    passwd="passwd"
    passwd_file=/tmp/rsync-pass-bak
    echo "====$FUNCNAME===="
    echo [`date "+%Y-%m-%d %H:%M:%S"`]$FUNCNAME start......
    echo $passwd > $passwd_file
    chmod 600 $passwd_file

    rsync --compress-level=9 -a -u -v -z --progress $src $user@$host::$dst --password-file $passwd_file

    rm -fv $passwd_file

    echo [`date "+%Y-%m-%d %H:%M:%S"`]$FUNCNAME finish......
}
# qxclient 备份
qxc_bak()
{
    ( cd "$qxclient_root"
      cd ..
      # 检查文件是否己存在
      if [ -e "$qxc_bak_name" ]; then
	  mv "$qxc_bak_name" "$qxc_bak_name"-`ls -l ${qxc_bak_name}* | wc -l`
      fi
      echo "====$FUNCNAME===="
      echo "开始备份 $qxclient_root"
      tar -czf "$qxc_bak_name" $qxclient_id
      if [ -r "$qxc_bak_name" ]; then
          echo "备份成功，且备份文件大小为："
          ls -lh "$qxc_bak_name"
	  echo "进入一下歩。"
      else
	  echo "qxclient备份失敗"
	  exit 1
      fi
    )
}

# qxclient 回滚
qxc_restore()
{
    echo "====$FUNCNAME===="
    if [ -e $qxclient_root ];then
	( cd $qxclient_root
	cd ..
	if [ -e $qxclient_id-new ];then
	    rm -rf $qxclient_id-new
	fi
	mv $qxclient_id $qxclient_id-new
	tar zxvf $qxc_restore_file
	)
    else
	echo "$qxclient_root 不存在"
	exit 1
    fi
}

# qxclient 更新
qxc_update()
{

    echo "====$FUNCNAME===="
    svn update $qxclient_root 
    if [ "$?" -eq 0 ]; then
	if [ $# -eq 0 ]; then
	    #tweak_version
	    cdn_update
	fi
    else
	die "qxclient update failed"
    fi
}

case "$qxc_action" in
    update)
	qxc_update
	;;
    bak)
	qxc_bak 
	;;
    restore)
	qxc_restore
	;;
    *)
	echo "可用的动作为：$actions"
	die "未知动作."
	;;
esac
