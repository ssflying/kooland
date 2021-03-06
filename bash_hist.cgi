#!/usr/bin/perl

use DBI;
use CGI qw(:standard);

## 不要缓存标准输出
$| = 1;

## 定义表单的变量赋值
my $q_user = param('user');
my $q_host = param('host');
my $q_date = param('date');
my $q_limit = param('limit') || 34;

## 主机昵称和ip的对应
my %hosts = (
    "db-157" => "192.168.1.157",
    "xyd-157" => "192.168.1.157",
    "xyd-158" => "192.168.1.158",
    "xyd-159" => "192.168.1.159",
    "xyd-160" => "192.168.1.160",
    "xyd-161" => "192.168.1.161",
    "xyd-163" => "192.168.1.163",
    "xyd-164" => "192.168.1.164",
    "sd-96" => "200.9.241.96",
    "sd-97" => "200.9.241.97",
    "sd-98" => "200.9.241.98",
    "dg-66" => "200.105.167.66",
    "dg-662" => "200.105.167.66",
    "gs-13" => "200.8.124.13",
    "gs-11" => "200.8.124.11",
    "gs-8" => "192.168.1.8",
);

## html头
print header(-charset=>'utf-8'),
	start_html('Bash History Query'),
	h1('Bash History Query'),
	h2('Query Criteria');

## 表单
print start_form,
	p("Enter the username:", textfield("user")),
	p("Enter the command display limit(default 34):", textfield("limit")),
	p("Enter host alias(eg. xyd-164):", textfield('host')),
	p("Enter the date(eg. 2010-12-09):", textfield('date')),
	submit(),
	end_form;

## 逻辑及数据处理
## 依据表单返回值构建sql查询语句
my @query_cri;		# 存储查询条件
my $query_stat;		# 查詢的sql语句
if (exists($hosts{$q_host})) {
    my $host = $hosts{$q_host};
    push @query_cri, " (host = \'$host\') ";
}
unless($q_user eq "") {
    push @query_cri, " (user = \'$q_user\') ";
}
if($q_date =~ /^\s*\d{4}-\d{2}-\d{2}\s*$/) {
    push @query_cri, " (date = \'$q_date\') ";
}
if(@query_cri > 0) {
    $query_stat = $query_stat . " WHERE ";
    $query_stat = $query_stat . join(" AND ", @query_cri);
}
$query_stat .= " ORDER BY date DESC LIMIT $q_limit ";

unless($q_user eq "") {
## 连接mysql
    my $database = 'users_command';
    my $hostname = 'localhost';
    my $port = '3306';
    my $username = 'someuser';
    my $pw = 'somepass';
    my $dbh = DBI->connect("DBI:mysql:$database:$hostname:$port", $username, $pw, {RaiseError => 1});

## 执行sql语句
    my $sth = $dbh->prepare(qq{SELECT * FROM command $query_stat})
	or die "Unable to prepare our query:".$dbh->errstr."\n";
    my $rc = $sth->execute()
	or die "Unable to execute our query:".$dbh->errstr."\n";

    if ($rc == 0) {
	print hr, "\n";
	print h4 "no entries";
    } else {
	print hr, "\n";
	print p("Results:");
	print qq(<table border="1" cellpadding="5" cellspacing="0">);
	print Tr(th [qw(time user host cmd)]);

	### use hashref method
	while(my $href = $sth->fetchrow_hashref) {
	    my $user = $href->{'user'};
	    my $host = $href->{'host'};
	    my $date = $href->{'date'};
	    my $time = $href->{'t_time'};
	    my $cmd = escapeHTML($href->{'cmd'});
	    print qq(
	    <tr valign="top">
	    <td>$date $time</td><td>$user</td><td>$host</td><td>$cmd</td>
	    </tr>
	    );
	}
	print qq(</table>);
    }
    $sth->finish;
    $dbh->disconnect;
}
print end_html;
