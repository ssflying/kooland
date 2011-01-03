#!/usr/bin/perl
## 用途：检查mysql是否可以连接，成功返回0, 否则1。

use strict;
use DBI;

# dsn:格式：DBI:mysql:$database:$hostname:$port
my $dsn=$ARGV[0];
my $user=$ARGV[1];
my $pw=$ARGV[2];

# PERL DBI CONNECT
my $dbh = DBI->connect($dsn, $user, $pw);

if ( $dbh ) {
    if ( ! $dbh->errstr ) {
	$dbh->disconnect;
	exit 0;
    }
}

exit 1;
