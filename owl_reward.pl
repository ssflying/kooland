#!/usr/bin/perl
use strict;
use Encode;
use DBI;

die "Usage: $0 <期数>.csv\n" unless @ARGV == 1;

### 变量初始化
my $filename = shift;
my $database = 'qxworld';
my $hostname = '*.*.*.*';
my $port = '3306';
my $username = 'somename';
my $pw = 'somepass';

### 连接mysql数据库并准备插入语句格式。
my $dbh = DBI->connect("DBI:mysql:$database:$hostname:$port", $username, $pw, {RaiseError => 1});
$dbh->do('SET NAMES utf8'); i	# 编码设为utf8
my $sth = $dbh->prepare(q"INSERT INTO Reward (rewardId, playerId, money, description, createTime) values (?,?,?,?,now())");

my %id;				# 保存毎个id对应的获奖次数
my @tags = ('a'..'z');		# 重复的id出现时，加按顺序在ID后tag以区分。

open(CSV, "< $filename") or die "can't open file: $!\n";
while(<CSV>) {
    next if $. == 1;		# 过滤第一行
    s/\r//;			# dos(\r\n) to unix(\n)
    chomp;
    # 数据来源为GBK（cp936格式），用encode转化。
    my $entry = encode("UTF-8", decode("CP936", $_));
    my ($playerId, $desc, $money) = split /,/, $entry;
    ++$id{$playerId};
    # rewardId默认为描述中期数。若描述中不存在期数，则使用filename中的期数。
    my $rewardId;
    if($desc =~ /第(\d+)期/) {
    $rewardId = $1;
    } else {
	($rewardId, undef) = split /\./, $filename;
    }
    # 如果某playerId多次获奖，则在第二次时用期数+tag[0], 依次类推。
    $rewardId = $id{$playerId} > 1 ? $rewardId . $tags[$id{$playerId}-2] : $rewardId;
    print "$rewardId\t$playerId\t$desc\t$money\n";
    $sth->execute($rewardId, $playerId, $money, $desc);
}
close(CSV);
$sth->finish();
$dbh->disconnect();
