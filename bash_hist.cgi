#!/usr/bin/perl

use DBI;
use CGI qw(:standard);

## flush STDOUT
$| = 1;

## get form params
my $q_user = param('user');
my $q_host = param('host');
my $q_date = param('date');
my $q_limit = param('limit') || 34;

## host/ip maps
my %hosts = (
    "db-157" => "124.172.232.157",
    "xyd-157" => "124.172.232.157",
    "xyd-158" => "124.172.232.158",
    "xyd-159" => "124.172.232.159",
    "xyd-160" => "124.172.232.160",
    "xyd-161" => "124.172.232.161",
    "xyd-163" => "124.172.232.163",
    "xyd-164" => "124.172.232.164",
    "sd-96" => "121.9.241.96",
    "sd-97" => "121.9.241.97",
    "sd-98" => "121.9.241.98",
    "dg-66" => "113.105.167.66",
    "dg-662" => "113.105.167.66",
    "gs-13" => "121.8.124.13",
    "gs-11" => "121.8.124.11",
    "gs-8" => "192.168.1.8",
);

## header form goes here
print header(-charset=>'utf-8'),
	start_html('Bash History Query'),
	h1('Bash History Query'),
	h2('Query Criteria');

## forms goes here
print start_form,
	p("Enter the username:", textfield("user")),
	p("Enter the command display limit(default 34):", textfield("limit")),
	p("Enter host alias(eg. xyd-164):", textfield('host')),
	p("Enter the date(eg. 2010-12-09):", textfield('date')),
	submit(),
	end_form;

## construct query statment based on the form return value
my @query_cri;		# criteria array
my $query_stat;		# query statement
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
## connect mysql
    my $database = 'users_command';
    my $hostname = 'localhost';
    my $port = '3306';
    my $username = 'root';
    my $pw = 'dwqx_mysqlsa';
    my $dbh = DBI->connect("DBI:mysql:$database:$hostname:$port", $username, $pw, {RaiseError => 1});

## execute sql
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
