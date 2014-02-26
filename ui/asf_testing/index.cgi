#!D:/Dispatcher/Perl/bin/perl.exe
use Mojolicious::Lite;
use DBI;
use List::MoreUtils qw(uniq);



my $g_dsn='DBI:mysql:reports_devel:localhost';
my $g_db_user_name = 'reports_devel';
my $g_db_password = 'RoawivUjco';
my $dbh=DBI->connect($g_dsn, $g_db_user_name, $g_db_password);


sub db_usage_find_packages {

	my $sth=$dbh->prepare("select package from testsuites where deleted = 0 group by package");
	$sth->execute;
	my $packages = $sth->fetchall_arrayref();
	$sth->finish;
	return $packages;
}

sub db_usage_find_testsuites {
	my $name = $_[0];
	$name = $name || '%';
	my $sth=$dbh->prepare("SELECT `ts`.`name` FROM `testsuites` ts WHERE `ts`.`deleted` = 0 AND `ts`.`package` LIKE ? GROUP BY `ts`.`name`");
	$sth->execute($name);
	my $packages = $sth->fetchall_arrayref();
	$sth->finish;
	return $packages;

}

sub db_usage_find_dates {

	my $sth=$dbh->prepare("select DATE(min(`date`)), DATE(max(`date`)) from runs where `deleted` = ?");
	$sth->execute(0);
	my @dates;
	push @dates, $sth->fetchrow_array;
	$sth->finish;
	return \@dates;
}

sub db_usage_get_testcases {
	my $package = $_[0];
	my $startdate = $_[1];
	my $enddate = $_[2];
	my $testsuite = $_[3];
	my $buildname = $_[4];
	my $result;
	my $sth;
	my $query = "SELECT `ts`.`name` AS ts_name, `tc`.`name` AS tc_name, `f`.`type` AS tc_f_type,  `f`.`message` AS tc_f_message, uncompress(`f`.`cdata`),  AS tc_f_cdata , `r`.`date` AS r_date, `r`.`buildname`
								AS r_buildname
								FROM testsuites ts INNER JOIN testcases tc ON `tc`.`id_testsuites`= `ts`.`id` LEFT JOIN failures f ON `f`.`testcases_id`=`tc`.`id` INNER JOIN runs r ON `r`.`id` = `ts`.`runs_id`
								WHERE ";
	my @req;

	$query .= " `ts`.`package` = ? AND (DATE(`r`.`date`) BETWEEN ? AND ?) AND `r`.`deleted` != 1 ";
	push @req, $package;
	push @req, $startdate;
	push @req, $enddate;
	if ($testsuite ne "") {

		$query .= " AND `ts`.`name` = ? ";
		push @req, $testsuite;
	}
	
	if ($buildname ne "") {
		$query .= " AND `r`.`buildname` = ? ";
		push @req, $buildname;
	}

	$sth=$dbh->prepare($query);
	$sth->execute(@req);
	while (my @line = $sth->fetchrow_array()) {
		push @{$result->{$line[0]}}, { tc_name => $line[1], f_type => $line[2] || '-',  f_message => $line[3] || '-', f_cdata => $line[4] || '-', r_date => $line[5], r_buildname => $line[6] || '-'}
	}
	$sth->finish;
	return $result;
}

sub db_usage_top_report {
	my $package = $_[0];
	my $startdate = $_[1];
	my $enddate = $_[2];
	my $testsuite = $_[3];
	my $buildname = $_[4];
	my $simple = $_[5];
	my @result;
	my @temp;
	my $sth;
	my @req;
	my @tmp;


	my $query = "SELECT maxid.package, rs.buildname, rs.date, count(`tc`.`name`), count(`f`.`type`), sum(`tc`.`time`) FROM runs rs INNER JOIN (
					SELECT MAX(runs_id) AS max_run_id, package FROM testsuites ts INNER JOIN runs r ON r.id = ts.runs_id WHERE r.deleted != 1 GROUP BY package
					) AS maxid ON rs.id = maxid.max_run_id 
					INNER JOIN testsuites ts ON `rs`.`id` = `ts`.`runs_id` 
					INNER JOIN testcases tc ON `tc`.`id_testsuites` = `ts`.`id`
					LEFT JOIN failures f ON `f`.`testcases_id`= `tc`.`id`
					GROUP BY `rs`.`buildname` ORDER BY `rs`.`date` ";

	$sth=$dbh->prepare($query);
	$sth->execute();
	
	while (my @line = $sth->fetchrow_array()) {
		$line[0] = $line[0] || '-';
		$line[1] = $line[1] || '-';
#		if ($line[2] =~ /(\d{4}-\d{2}-\d{2})/) {
#			$line[2] = $1 || '-';
#		}
		$line[3] = $line[3] || '-';
		$line[4] = $line[4] || '-';
		$line[5] = $line[5] || '-';
		push @result, @line;
	}
	$sth->finish;
	return \@result;
}

# Get amount testcases, total failures, total time and calc success rate.
sub db_usage_get_shortreport {
	my $package = $_[0];
	my $startdate = $_[1];
	my $enddate = $_[2];
	my $testsuite = $_[3];
	my $buildname = $_[4];
	my $simple = $_[5];
	my @result;
	my @temp;
	my $sth;
	my @req;

	my $query = "SELECT `r`.`buildname`, `r`.`priority`, `r`.`date`, count(`tc`.`name`),  count(`f`.`type`), sum(`tc`.`time`) FROM testcases tc INNER JOIN testsuites ts ON `tc`.`id_testsuites` = `ts`.`id`
					INNER JOIN runs r ON `r`.`id` = `ts`.`runs_id` LEFT JOIN failures f ON `f`.`testcases_id`= `tc`.`id` WHERE ";

#SELECT `r`.`buildname`, `r`.`id`, `r`.`date`, count(`tc`.`name`), sum(`tc`.`time`), count(`f`.`type`) FROM 
# testcases tc INNER JOIN testsuites ts ON `tc`.`id_testsuites` = `ts`.`id` INNER JOIN runs r ON `r`.`id` = `ts`.`runs_id` 
# LEFT JOIN failures f ON `f`.`testcases_id`= `tc`.`id` WHERE (DATE(`r`.`date`) BETWEEN '2012-09-04' AND '2012-09-17') AND `r`.`deleted` != 1 group by 1 Order by 3
					
	if ($package ne "") {
		$query .= " `ts`.`package` = ? AND ";
		push @req, $package;
	}
	if ($testsuite ne "") {
		$query .= " `ts`.`name` = ? AND ";
		push @req, $testsuite;
	}
	if ($buildname ne "") {
		$query .= " `r`.`buildname` = ? AND ";
		push @req, $buildname;
	}
	if ($simple == 1) {
		$query .= " `r`.`deleted` != 1  GROUP BY `r`.`buildname` ORDER BY `r`.`date`, `r`.`buildname` DESC LIMIT 10";
	} else {
		$query .= " (DATE(`r`.`date`) BETWEEN ? AND ?) AND `r`.`deleted` != 1  GROUP BY `r`.`buildname` ORDER BY `r`.`date`";
		push @req, $startdate;
		push @req, $enddate;
	}
	
	$sth=$dbh->prepare($query);
	$sth->execute(@req);
	while (my @line = $sth->fetchrow_array()) {
		#my $date;
		$line[0] = $line[0] || '-';
		if ($line[1] =~ /(\d{4}-\d{2}-\d{2})/) {
			$line[1] = $1 || '-';
		}
		$line[2] = $line[2] || '-';
		$line[3] = $line[3] || '-';
		$line[4] = $line[4] || '-';
		$line[5] = $line[5] || '-';
		push @result, @line;
		#push @{$result->{$line[0]}}, { r_date => $date, count_tc => $line[2] || '-', sum_time => $line[3] || '-', count_f => $line[4] }
	}
	$sth->finish;

	return \@result;
}

sub db_usage_get_errorsreport {
	my $package = $_[0];
	my $startdate = $_[1];
	my $enddate = $_[2];
	my $testsuite = $_[3];
	my $buildname = $_[4];
	my $result;
	my @temp;
	my $sth;
	my @q;
	my $query = "SELECT `ts`.`name` AS ts_name, `tc`.`name` AS tc_name, `f`.`type` AS tc_f_type,  `f`.`message` AS tc_f_message, uncompress(`f`.`cdata`) AS tc_f_cdata,
					`r`.`date` AS r_date, `r`.`buildname` AS r_buildname
								FROM testsuites ts INNER JOIN testcases tc ON `tc`.`id_testsuites`= `ts`.`id` LEFT JOIN failures f ON `f`.`testcases_id`=`tc`.`id` INNER JOIN runs r ON `r`.`id` = `ts`.`runs_id`
								WHERE ";
	if ($package ne '') {
		$query .= " `ts`.`package` = ? AND ";
		push @q, $package;
	}
	if ($testsuite ne "") {
		$query .= " `ts`.`name` = ? AND ";
		push @q, $testsuite;
	}
	if ($buildname ne "") {
		$query .= " `r`.`buildname` = ? AND ";
		push @q, $buildname;
	
	}
	$query .= " (DATE(`r`.`date`) BETWEEN ? AND ? ) AND `r`.`deleted` != 1  "; # AND `f`.`type` IS NOT NULL";
	push @q, $startdate;
	push @q, $enddate;
	$sth=$dbh->prepare($query);
	$sth->execute(@q);


	while (my @line = $sth->fetchrow_array()) {
#		foreach my $look_pre ($line[4]) {
#			$look_pre =~ s/<pre>//;
#			$look_pre =~ s/<\/pre>//;
#		}
		my $date;
		if ($line[5] =~ /(\d{4}-\d{2}-\d{2})/) {
			$date = $1;
		}
		push @{$result->{$line[0]}}, { tc_name => $line[1], f_type => $line[2] || '',  f_message => $line[3] || '-', f_cdata => $line[4] || '-',
					r_date => $date, r_buildname => $line[6] };
	}
	$sth->finish;

	return $result;
}

sub db_usage_get_plotdata {
	my $startdate = $_[0];
	my $enddate = $_[1];
	my $sth;
	my @req;

# SELECT r.buildname, r.date, (
# count( tc.name ) - count( f.type )
# ) / count( tc.name ) *100
# FROM testcases tc
# INNER JOIN testsuites ts ON tc.id_testsuites = ts.id
# INNER JOIN runs r ON r.id = ts.runs_id
# LEFT JOIN failures f ON f.testcases_id = tc.id
# GROUP BY r.buildname
# ORDER BY r.date	

	# `r`.`buildname`, `r`.`date`, ROUND ((
	my $query = "SELECT `ts`.`package`, `r`.`date`, ROUND (( 
						( COUNT(`tc`.`name`)-COUNT(`f`.`type`))/COUNT(`tc`.`name`)*100 
						),3 ) FROM `testcases` tc
						INNER JOIN `testsuites` ts ON `tc`.`id_testsuites` = `ts`.`id`
						INNER JOIN `runs` r ON `r`.`id`=`ts`.`runs_id`
						LEFT JOIN `failures` f ON `f`.`testcases_id` = `tc`.`id`
						WHERE `r`.`deleted` != 1 AND (DATE(`r`.`date`) BETWEEN ? AND ?)
						GROUP BY `r`.`buildname`
						ORDER BY `r`.`date` ";
	push @req, $startdate;
	push @req, $enddate;
	
	
	$sth=$dbh->prepare($query);
	$sth->execute(@req);
	my %reslt;
	while (my @line = $sth->fetchrow_array()) {
		my $name;
#		if ($line[0] =~ /\w+\.[0-9]+-\w+\.[0-9]+/) {
#			$line[0] =~ /(\w+)_.+?-(\w+)_/;
#			$name = "$1 + $2";
#		} else {
#			$line[0] =~ /(^\w+)_/;
#			$name = $1;
#		}
		$name = $line[0];
		$line[1] =~ /(\d{4}-\d{2}-\d{2})/;
		$line[1] = $1;
		push @{$reslt{$name}}, {date=>$line[1], ratio=>$line[2]};
	}
	
	$sth->finish;
	
	return \%reslt;
}

sub db_usage_delete_buildnum {
	my $package = $_[0];
	my $startdate = $_[1];
	my $enddate = $_[2];
	my $testsuite = $_[3];
	my $buildname = $_[4];
	my $result;
	my @temp;
	my $sth;
	my @q;
	my $query = "UPDATE runs r SET `r`.`deleted`=? 
								WHERE `r`.`buildname` = ? ";
	push @q, "1";
	push @q, $buildname;
	$sth=$dbh->prepare($query);
	$sth->execute(@q);

	return $result;
}

post '/delete' => sub {
	my $self = shift;
	my @stash = ();
	my $testsuite;
	my $package;
	my $failure;
	my $enddate;
	my $startdate;
	my $report;
	my $res;
	my $reserr;
	my $resshort;
	my $errors_report;
	my $buildname;
	my $delete;
	my $simple = 0;
	my $topreport;
	my $plotdata;
	my $packages;
	my $dates;
	my $testsuites;
	
	$package = $self->param('package');
	$testsuite = $self->param('testsuite');
	$failure = $self->param('failure');
	$enddate = $self->param('enddate');
	$startdate = $self->param('startdate');
	$report = $self->param('report');
	$buildname = $self->param('buildname');
	$delete = $self->param('delete');
	
	db_usage_delete_buildnum($package, $startdate, $enddate, $testsuite, $buildname);
	$buildname = '';
	$delete = '0';
	
	$self->stash(reserr=>$reserr);
	$self->stash(pack=>$packages);
	$self->stash(dates=>$dates);
	$self->stash(testsuites=>$testsuites);
	$self->stash(testsuite=>$testsuite);
	$self->stash(package=>$package);
	$self->stash(failure=>$failure);
	$self->stash(enddate=>$enddate);
	$self->stash(startdate=>$startdate);
	$self->stash(resshort=>$resshort);
	$self->stash(errors_report=>$errors_report);
	$self->stash(report=>$report);
	$self->stash(buildname=>$buildname);
	$self->stash(simple=>$simple);
	$self->stash(topreport=>$topreport);
	$self->stash(plotdata=>$plotdata);
	#$self->render('index');
	
	$self->redirect_to('index');
	
} => 'delete';

get '/' => sub {
	my $self = shift;
	my @stash = ();
	my $testsuite;
	my $package;
	my $failure;
	my $enddate;
	my $startdate;
	my $report;
	my $res;
	my $reserr;
	my $resshort;
	my $errors_report;
	my $buildname;
	my $delete;
	my $simple = 0;
	my $topreport;
	my $plotdata;
	

	$self->stash(title=>"ASF Testing - CI Reports");
	$self->stash(content=>"ASF Testing - CI Reports");

	$package = $self->param('package');
	$testsuite = $self->param('testsuite');
	$failure = $self->param('failure');
	$enddate = $self->param('enddate');
	$startdate = $self->param('startdate');
	$report = $self->param('report');
	$buildname = $self->param('buildname');
	$delete = $self->param('delete');
	
	
	if (($startdate eq '') && ($enddate eq '')) {
		$simple = 1;
	}
	

	
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year+=1900;
	$mon++;
	($mon < 10) and $mon="0$mon";
	($mday < 10) and $mday="0$mday";
	
	if ($enddate eq '') {
		$enddate = "$year-$mon-$mday";
	}
	
	if ($simple == 1) {
		$mon = int $mon;
		$mon--;
		if ($mon < 1) {
			$mon = 12;
			$year = int $year;
			$year--;
		}
	}
	
	($mon < 10) and $mon="0$mon";
	($mday < 10) and $mday="0$mday";
	
	if ($startdate eq '') {
		$startdate = "$year-$mon-$mday";
	}
	
	
	my $packages=db_usage_find_packages();
	my $dates = db_usage_find_dates();
	

	$startdate = $startdate || $dates->[0];
	$enddate = $enddate || $dates->[1];

	my $testsuites = db_usage_find_testsuites($package);

	if ($testsuite !~ /$package/) {
		$testsuite = '';
	}

	# if ($delete eq '1') {
		# db_usage_delete_buildnum($package, $startdate, $enddate, $testsuite, $buildname);
		# $buildname = '';
		# $delete = '0';
	# }

	if ($simple == 1) {
		$topreport = db_usage_top_report();
		$plotdata = db_usage_get_plotdata($startdate, $enddate);
	} else {
		$resshort = db_usage_get_shortreport($package, $startdate, $enddate, $testsuite, $buildname, $simple);
		$reserr = db_usage_get_errorsreport($package, $startdate, $enddate, $testsuite, $buildname);
	}
	
	$self->stash(reserr=>$reserr);
	$self->stash(pack=>$packages);
	$self->stash(dates=>$dates);
	$self->stash(testsuites=>$testsuites);
	$self->stash(testsuite=>$testsuite);
	$self->stash(package=>$package);
	$self->stash(failure=>$failure);
	$self->stash(enddate=>$enddate);
	$self->stash(startdate=>$startdate);
	$self->stash(resshort=>$resshort);
	$self->stash(errors_report=>$errors_report);
	$self->stash(report=>$report);
	$self->stash(buildname=>$buildname);
	$self->stash(simple=>$simple);
	$self->stash(topreport=>$topreport);
	$self->stash(plotdata=>$plotdata);
	$self->render('index');
	
} => 'index';



app->start;

