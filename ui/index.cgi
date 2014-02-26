#!D:/Dispatcher/Perl/bin/perl.exe
use Mojolicious::Lite;
use DBI;
use List::MoreUtils qw(uniq);
use Data::Dumper;
use utf8;
use Encode;
use POSIX qw/strftime/;
#use DateTime;
#use encoding 'utf8', Filter => 1;


my $dbh;
if ($ENV{COMPUTERNAME} && ($ENV{COMPUTERNAME} eq 'ISHEVELENKO')) {
	my $g_dsn='DBI:mysql:rada_analysys:localhost';
	my $g_db_user = 'root';
	my $g_db_passw = 'opt-m95d';
	$dbh=DBI->connect($g_dsn,$g_db_user, $g_db_passw, {mysql_enable_utf8 => 1}) or die;
} else {

my $g_dsn='DBI:mysql:rada_analys:rada.local';
my $g_db_user = 'test';
my $g_db_passw = 'test';
$dbh=DBI->connect($g_dsn,$g_db_user, $g_db_passw, {mysql_enable_utf8 => 1}) or die;

}
my $sql = qq{SET NAMES 'utf8';};
$dbh->do($sql);

sub util_getdate {
	my $date;
	#my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	#$year+=1900;
	#$mon++;
	#$mon = sprintf("%01d", $mon);
	#$mday = sprintf("%01d", $mday);
	
	$date = strftime('%Y-%m-%d', localtime);
	
	return $date;
}

sub util_partiesrename {
	my $name = shift;
	if ($name =~ /комуністична/i) {
		$name = 'КПУ';
	}
	if ($name =~ /Удар/i) {
		$name = 'УДАР';
	}
	if ($name =~ /Свобода/i) {
		$name = 'ВО Свобода';
	}
	if ($name =~ /Батьківщина/i) {
		$name = 'ВО Батьківщина';
	}
	if ($name =~ /партія регіонів/i) {
		$name = 'Партія Регіонів';
	}
	return $name;
}


sub db_get_parties {
	my $self = shift;
	my $sth = $dbh->prepare("SELECT `name` from `d_parties`");
	$sth->execute() or die $self->app->log->debug($sth->errstr);
	my $ret = $sth->fetchall_arrayref();
	$sth->finish;
	return $ret;
}

sub db_get_deps_by_party {
	my $self = shift;
	my $party = shift;
	my $q = qq (SELECT `d`.`name`
FROM `d_deputates` d
INNER JOIN `d_parties` p
ON `d`.`party_id` = `p`.`id`
WHERE `p`.`name` = ?);
	my $sth = $dbh->prepare($q);
	$sth->execute($party) or die $self->app->log->debug($sth->errstr);
	my $ret = $sth->fetchall_arrayref();
	$sth->finish;
	return $ret;
}

sub db_get_deputate_registrations {
	my $self = shift;
	my $dep = shift;
	my $sdate = shift;
	my $edate = shift;
	my %ret;
	my $q = qq ( SELECT `r`.`reg_type`, `r`.`reg_dep`, `r`.`reg_date`
FROM  `d_registrations` r
INNER JOIN `d_deputates` `d` ON `d`.`internal_id` = `r`.`int_dep_kod`
WHERE `d`.`name` = ?
AND (`r`.`reg_date` BETWEEN ? AND ? )
GROUP BY `r`.`reg_date`, `r`.`reg_dep`, `r`.`reg_type`
ORDER BY `r`.`reg_date`
	);
	my $sth=$dbh->prepare($q);
	$sth->execute($dep, $sdate, $edate) or die $self->app->log->debug($sth->errstr);
	while ( my @line = $sth->fetchrow_array) {
		if ($line[1] =~ /^Прис/) { $line[1] = 1;}
		if ($line[1] =~ /^Відс/) { $line[1] = 0;}
		if ($line[2] =~ /(\d{4}-\d{2}-\d{2})/) {$line[2] = $1;}
		push @{$ret{$line[0]}}, { date => $line[2],
								  status => $line[1] };
	}
	return \%ret;
}

sub db_get_deputate_activity {
	my $self = shift;
	my $dep = shift;
	my $sdate = shift;
	my $edate = shift;
	my %ret;
	my $q = qq (SELECT `ld`.`reg_date`, count(`ld`.`name`)
FROM `d_lawdrafts` ld
INNER JOIN `d_deputates` d
ON `d`.`id`=`ld`.`dep_id`
WHERE `d`.`name` = ? AND (`ld`.`reg_date` BETWEEN ? AND ?)
GROUP by `ld`.`reg_date`);
	my $sth=$dbh->prepare($q);
	$sth->execute($dep, $sdate, $edate) or die $self->app->log->debug($sth->errstr);
	while ( my @line = $sth->fetchrow_array) {
		push @{$ret{lawdrafts}}, { date => $line[0],
								  count => $line[1] };
	}
	
	$q = qq (SELECT `ld`.`reg_date`, count(`ld`.`name`)
FROM `d_lawdrafts` ld
INNER JOIN `d_deputates` d
ON `d`.`id`=`ld`.`dep_id`
WHERE `d`.`name` = ?
AND (`ld`.`reg_date` BETWEEN ? AND ?)
AND `ld`.`law_id` != ''
GROUP by `ld`.`reg_date`);
	$sth=$dbh->prepare($q);
	$sth->execute($dep, $sdate, $edate) or die $self->app->log->debug($sth->errstr);
	while ( my @line = $sth->fetchrow_array) {
		push @{$ret{laws}}, { date => $line[0],
							  count => $line[1] };
	}
	return \%ret;
}

sub db_get_parties_lawdraft_count_by_date {
	my $self = shift;
	my $sdate = shift;
	my $edate = shift;
	my $q = qq (SELECT `p`.`name`, COUNT( `ld`.`name` ) , `ld`.`reg_date`
FROM `d_parties` `p`
INNER JOIN `d_deputates` d ON `p`.`id` = `d`.`party_id`
INNER JOIN `d_lawdrafts` ld ON `d`.`id` = `ld`.`dep_id`
WHERE (`ld`.`reg_date` BETWEEN ? AND ?)

GROUP BY `p`.`name`, `ld`.`reg_date`
ORDER BY `ld`.`reg_date`, `p`.`name`);
	my $sth = $dbh->prepare($q);
	$self->app->log->debug("SDATE:$sdate");
	$self->app->log->debug("EDATE:$edate");
	$sth->execute($sdate, $edate) or die $self->app->log->debug($sth->errstr);
	my %reslt;
	my $c;
	my $c1;
	while (my @line = $sth->fetchrow_array()) {
#		$self->app->log->debug(Dumper(@line));
		my $pname;

		$pname =  $line[0];
		$pname = util_partiesrename $line[0];
		$c+=$line[1];
		if ($pname eq 'SVOBODA') {
			$c1+=($line[1]+0);
		}
		push @{$reslt{$pname}}, {
								 date=>$line[2],
								 count=>$line[1], };
	}
	$self->app->log->debug("C:$c  C1:$c1");
	return \%reslt;
	
}

sub db_get_parties_lawdraft_count_by_date_accepted {
	my $sdate = shift;
	my $edate = shift;
	my $q = qq (SELECT p.name, COUNT( ld.name ) , ld.reg_date
FROM d_parties p
INNER JOIN d_deputates d ON p.id = d.party_id
INNER JOIN d_lawdrafts ld ON d.id = ld.dep_id
WHERE (ld.reg_date BETWEEN ? AND ?)
AND ld.law_id != '' 
GROUP BY `p`.`name`, ld.reg_date
ORDER BY ld.reg_date, p.name);
	my $sth = $dbh->prepare($q);
	$sth->execute($sdate, $edate) or die $sth->err;
	my %reslt;
	while (my @line = $sth->fetchrow_array()) {
		my $pname;
		$pname = util_partiesrename $line[0];
		push @{$reslt{$pname}}, {date=>$line[2],
								 count=>$line[1]
								 };
	}
	return \%reslt;
	
}


sub law_and_lawdraft_ratio {
	my $self = shift;
	my $r_ld = shift;
	my $r_l = shift;
	my %res;
	foreach my $party_ld (keys %{$r_ld}) {
		for my $party_l (keys %{$r_l}) {
			if ($party_ld eq $party_l) {
				foreach my $item_ld (@{$r_ld->{$party_ld}}) {
					for my $item_l (@{$r_l->{$party_l}}){
						if ($item_ld->{date} eq $item_l->{date}) {
							push @{$res{$party_l}}, { date=>$item_l->{date},
													ratio=>sprintf("%.2f",($item_l->{count}/$item_ld->{count})*100)
													};
						}
					}
				}
			}
		}
	}
	return \%res;
}


get '/' => sub {
	my $self = shift;
	my @stash = ();
	my $ar_parties;
	my $enddate;
	my $startdate;
	

	$self->stash(title=>"Rada analys tool");
	$self->stash(content=>"Rada testing tool");

	$enddate = $self->param('enddate');
	$startdate = $self->param('startdate');
	my $sel_party = $self->param('sel_party');
	my $ar_deputates = $self->param('ar_deputates');
	my $deputate = $self->param('deputate');
	
	if (!$enddate) {
		$enddate = util_getdate();
	}	
	if (!defined $startdate) {
		$startdate = "2012-12-12";
	}
	
	$self->app->log->debug("STARTDATE:$startdate");
	$self->app->log->debug("ENDDATE:$enddate");
	
	$ar_parties = db_get_parties($self);
	
	my $ar_lawdrafts_byparties = db_get_parties_lawdraft_count_by_date ($self, $startdate, $enddate);
	#foreach my $it (keys %{$ar_lawdrafts_byparties}) {
	#	my $count;
	#	foreach my $ii (@{$ar_lawdrafts_byparties->{$it}}) {
	#		$count+=$ii->{count};
	#	}
	#	$self->app->log->debug("$it->$count");
	#}
	#$self->app->log->debug(Dumper $ar_lawdrafts_byparties);
	my $ar_laws = db_get_parties_lawdraft_count_by_date_accepted ($startdate, $enddate);
	my $ar_ratios = law_and_lawdraft_ratio($self, $ar_lawdrafts_byparties, $ar_laws);
	$self->stash(ar_parties=>$ar_parties);
	$self->stash(plotdata=>$ar_lawdrafts_byparties);
	$self->stash(plotdata2=>$ar_laws);
	$self->stash(plotdata3=>$ar_ratios);
	$self->stash(enddate=>$enddate);
	$self->stash(startdate=>$startdate);
	$self->stash(sel_party=>$sel_party);
	$self->stash(deputate=>$deputate);
	$self->stash(ar_deputates=>$ar_deputates);

	$self->render('index');
	
} => 'index';

get '/deputates' => sub {
	my $self = shift;
	my @stash = ();
	my $ar_parties;
	my $enddate;
	my $startdate;
	my $plotdata;
	my $sel_party = $self->param('sel_party');
	my $ar_deputates = $self->param('ar_deputates');
	my $deputate = $self->param('deputate');
	$enddate = $self->param('enddate');
	$startdate = $self->param('startdate');
	
	if ($enddate eq '') {
		$enddate = util_getdate();
	}	
	if ($startdate eq '') {
		$startdate = "2012-12-12";
	}
	
	$self->app->log->debug("STARTDATE:$startdate");
	$self->app->log->debug("ENDDATE:$enddate");

	$ar_parties = db_get_parties();
	$ar_deputates = db_get_deps_by_party($self, $sel_party);
	
	if ($deputate) {
		$plotdata = db_get_deputate_activity($self, $deputate, $startdate, $enddate);
	}
	
	$self->stash(ar_parties=>$ar_parties);
	$self->stash(enddate=>$enddate);
	$self->stash(startdate=>$startdate);
	$self->stash(sel_party=>$sel_party);
	$self->stash(deputate=>$deputate);
	$self->stash(ar_deputates=>$ar_deputates);
	$self->stash(plotdata=>$plotdata);
	
	$self->render('deputates');
} => 'deputates';

get '/registrations' => sub {

	my $self = shift;
	my @stash = ();
	my $ar_parties;
	my $startdate;
	my $enddate;
	my $plotdata;
	$enddate = $self->param('enddate');
	$startdate = $self->param('startdate');
	my $sel_party = $self->param('sel_party');
	my $ar_deputates = $self->param('ar_deputates');
	my $deputate = $self->param('deputate');
	
	
		if ($enddate eq '') {
		$enddate = util_getdate();
	}	
	if ($startdate eq '') {
		$startdate = "2012-12-12";
	}
	
	$self->app->log->debug("STARTDATE:$startdate");
	$self->app->log->debug("ENDDATE:$enddate");

	$ar_parties = db_get_parties();
	$ar_deputates = db_get_deps_by_party($self, $sel_party);
	
	if ($deputate) {
		$plotdata = db_get_deputate_registrations($self, $deputate, $startdate, $enddate);
	}
	
	$self->stash(ar_parties=>$ar_parties);
	$self->stash(enddate=>$enddate);
	$self->stash(startdate=>$startdate);
	$self->stash(sel_party=>$sel_party);
	$self->stash(deputate=>$deputate);
	$self->stash(ar_deputates=>$ar_deputates);
	$self->stash(plotdata=>$plotdata);
	
	$self->render('registrations');
	

} => 'registrations';

get '/votings' => sub {
	my $self = shift;
	my @stash = ();
	my $ar_parties;
	my $startdate;
	my $enddate;
	my $plotdata;
	$enddate = $self->param('enddate');
	$startdate = $self->param('startdate');
	my $sel_party = $self->param('sel_party');
	my $ar_deputates = $self->param('ar_deputates');
	my $deputate = $self->param('deputate');
	
	
		if ($enddate eq '') {
		$enddate = util_getdate();
	}	
	if ($startdate eq '') {
		$startdate = "2012-12-12";
	}
	
	$self->app->log->debug("STARTDATE:$startdate");
	$self->app->log->debug("ENDDATE:$enddate");

	$ar_parties = db_get_parties();
	$ar_deputates = db_get_deps_by_party($self, $sel_party);
	
	if ($deputate) {
		$plotdata = db_get_deputate_registrations($self, $deputate, $startdate, $enddate);
	}
	
	$self->stash(ar_parties=>$ar_parties);
	$self->stash(enddate=>$enddate);
	$self->stash(startdate=>$startdate);
	$self->stash(sel_party=>$sel_party);
	$self->stash(deputate=>$deputate);
	$self->stash(ar_deputates=>$ar_deputates);
	$self->stash(plotdata=>$plotdata);
	
	$self->render('registrations');
	
} => 'votings';

app->start;

