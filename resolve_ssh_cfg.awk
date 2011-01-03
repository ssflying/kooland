#!/usr/bin/awk -f
## 用途：解析~/.ssh/config文件（区分大小写），为如下格式：
##       hostalias,username,ip,port
#        以供其他程序调用

BEGIN { FS = "\n"; RS = ""; IGNORECASE = 1}
{
    if ( $1 ~ /^Host [^\*]/  ) {
	hostalias = substr($1, 6)
	for(i=2; i<=NF; ++i) {
	    if( match($i, /^[[:blank:]]*Port /) )  
		port = substr($i, RSTART + RLENGTH)
	    if( match($i, /^[[:blank:]]*HostName /) )
		ip = substr($i, RSTART + RLENGTH)
	    if( match($i, /^[[:blank:]]*User /) )
		user = substr($i, RSTART + RLENGTH)
	}
	print hostalias "," user "," ip "," port
    }
    next
}
