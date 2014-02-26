#!D:/Dispatcher/Perl/bin/perl.exe
use Mojolicious::Lite;
use DBI;



my $g_dsn='DBI:mysql:testing_dev:localhost';
my $g_db_user_name = 'testing_dev';
my $g_db_password = 'testing_pass';
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
	my $result;
	my $sth;
	my $query = "SELECT `ts`.`name` AS ts_name, `tc`.`name` AS tc_name, `f`.`type` AS tc_f_type,  `f`.`message` AS tc_f_message, uncompress(`f`.`cdata`),  AS tc_f_cdata , `r`.`date` AS r_date
								FROM testsuites ts INNER JOIN testcases tc ON `tc`.`id_testsuites`= `ts`.`id` LEFT JOIN failures f ON `f`.`testcases_id`=`tc`.`id` INNER JOIN runs r ON `r`.`id` = `ts`.`runs_id`
								WHERE ";
	my @req;

	$query .= " `ts`.`package` = ? AND (`r`.`date` BETWEEN ? AND ?) ";
	push @req, $package;
	push @req, $startdate;
	push @req, $enddate;
	if ($testsuite ne "") {

		$query .= " AND `ts`.`name` = ? ";
		push @req, $testsuite;
	}

	$sth=$dbh->prepare($query);
	$sth->execute(@req);
	while (my @line = $sth->fetchrow_array()) {
		push @{$result->{$line[0]}}, { tc_name => $line[1], f_type => $line[2] || '-',  f_message => $line[3] || '-', f_cdata => $line[4] || '-', r_date => $line[5]}
	}
	$sth->finish;
	return $result;
}

# Get amount testcases, total failures, total time and calc success rate.
sub db_usage_get_shortreport {
	my $package = $_[0];
	my $startdate = $_[1];
	my $enddate = $_[2];
	my $testsuite = $_[3];
	my $result;
	my @temp;
	my $sth;
	my @req;

# SELECT count testcases.
	my $query = "SELECT count(`tc`.`name`)
							FROM testcases tc INNER JOIN testsuites ts ON `tc`.`id_testsuites`= `ts`.`id` INNER JOIN runs r ON `r`.`id` = `ts`.`runs_id`
							WHERE ";
	if ($package ne "") {
		$query .= " `ts`.`package` = ? AND ";
		push @req, $package;
	}
	if ($testsuite ne "") {
		$query .= " `ts`.`name` = ? AND ";
		push @req, $testsuite;
	}
	$query .= " (`r`.`date` BETWEEN ? AND ?) ";
	push @req, $startdate;
	push @req, $enddate;
	$sth=$dbh->prepare($query);
	$sth->execute(@req);
	@temp = $sth->fetchrow_array();
	my $testcases_count = $temp[0];
	$sth->finish;
	@req = ();
# Select total time execution of those testcases
	$query = "SELECT sum(`tc`.`time`) FROM testcases tc INNER JOIN testsuites ts ON `tc`.`id_testsuites`= `ts`.`id` INNER JOIN runs r ON `r`.`id` = `ts`.`runs_id` WHERE ";
	if ($package ne "") {
		$query .= " `ts`.`package` = ? AND ";
		push @req, $package;
	}
	if ($testsuite ne "") {
		$query .= " `ts`.`name` = ? AND ";
		push @req, $testsuite;
	}
	$query .= " (`r`.`date` BETWEEN ? AND ? ) ";
	push @req, $startdate;
	push @req, $enddate;
	$sth=$dbh->prepare($query);
	$sth->execute(@req);
	@temp = $sth->fetchrow_array();
	my $testcases_time = $temp[0];
	$sth->finish;
	@req = ();

# Select count failures of those testcases
	$query = "SELECT count(`f`.`type`) FROM failures f LEFT JOIN testcases tc ON `f`.`testcases_id`= `tc`.`id` INNER JOIN testsuites ts ON `tc`.`id_testsuites`= `ts`.`id` INNER JOIN runs r ON `r`.`id` = `ts`.`runs_id` WHERE ";
	if ($package ne "") {
		$query .= " `ts`.`package` = ? AND ";
		push @req, $package;
	}
	if ($testsuite ne "") {
		$query .= " `ts`.`name` = ? AND ";
		push @req, $testsuite;
	}
	$query .= " (`r`.`date` BETWEEN ? AND ? ) ";
	push @req, $startdate;
	push @req, $enddate;
	$sth=$dbh->prepare($query);
	$sth->execute(@req);
	@temp = $sth->fetchrow_array();
	my $failures_count = $temp[0];
	$sth->finish;
	@req = ();


	push @{$result}, $testcases_count;
	push @{$result}, $testcases_time;
	push @{$result}, $failures_count;
	return $result;
}

sub db_usage_get_errorsreport {
	my $package = $_[0];
	my $startdate = $_[1];
	my $enddate = $_[2];
	my $testsuite = $_[3];
	my $result;
	my @temp;
	my $sth;
	my $query = "SELECT `ts`.`name` AS ts_name, `tc`.`name` AS tc_name, `f`.`type` AS tc_f_type,  `f`.`message` AS tc_f_message, uncompress(`f`.`cdata`) AS tc_f_cdata,
					`r`.`date` AS r_date, `r`.`buildname` AS r_buildname
								FROM testsuites ts INNER JOIN testcases tc ON `tc`.`id_testsuites`= `ts`.`id` LEFT JOIN failures f ON `f`.`testcases_id`=`tc`.`id` INNER JOIN runs r ON `r`.`id` = `ts`.`runs_id`
								WHERE ";
	if ($package ne '') {
		$query .= " `ts`.`package` = \'" . $package ."\' AND ";
	}
	if ($testsuite ne "") {
		$query .= " `ts`.`name` = \'" . $testsuite . "\' AND ";
	}
	$query .= " (`r`.`date` BETWEEN \'".$startdate."\' AND \'".$enddate."\')"; # AND `f`.`type` IS NOT NULL";
	$sth=$dbh->prepare($query);
	$sth->execute();


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

	$self->stash(title=>"Alstom ASF test framework");
	$self->stash(content=>"Alstom ASF test framework");

	$package = $self->param('package');
	$testsuite = $self->param('testsuite');
	$failure = $self->param('failure');
	$enddate = $self->param('enddate');
	$startdate = $self->param('startdate');
	$report = $self->param('report');


	my $packages=db_usage_find_packages();
	my $dates = db_usage_find_dates();

	$startdate = $startdate || $dates->[0];
	$enddate = $enddate || $dates->[1];

	my $testsuites = db_usage_find_testsuites($package);

	if ($testsuite !~ /$package/) {
		$testsuite = '';
	}


	$resshort = db_usage_get_shortreport($package, $startdate, $enddate, $testsuite);
	$reserr = db_usage_get_errorsreport($package, $startdate, $enddate, $testsuite);

	$self->stash(reserr=>$reserr);
	$self->stash(pack=>$packages);
	$self->stash(dates=>$dates);
	$self->stash(testsuites=>$testsuites);
	$self->stash(testsuite=>$testsuite);
	$self->stash(package=>$package);
	$self->stash(failure=>$failure);
	$self->stash(enddate=>$enddate);
	$self->stash(startdate=>$startdate);
	$self->stash(res_short=>$resshort);
	$self->stash(errors_report=>$errors_report);
	$self->stash(report=>$report);
	$self->render('index');
} => 'index';



app->start;

__DATA__

<%# --------------------------------------------------------- %>
@@ index.html.ep
% layout 'main';

<div class="span6 offset6">
	<%= include 'top' %>
</div>

<div class="row">
	<div class="span2">
		<%= include 'left_packages' %>
	</div>
	<div class="span8 offset1">
		<%= include 'short_report' %>
	</div>
</div>

<div class="row">
	<div class="span2">
		<%= include 'left_testsuites' %>
	</div>
	<div class="span9 offset1">

		<%= include 'errors_report' %>
	</div>
</div>



<%# --------------------------------------------------------- %>
@@ top.html.ep
<form name="SelectDate" action="<%= url_for 'index' %>" method="GET" class="well form-inline">
<input type="hidden" name="testsuite" value="<%= $testsuite %>">
<input type="hidden" name="package" value="<%= $package %>">
<input type="hidden" name="failure" value="<%= $failure %>">
<input type="hidden" name="report" value="<%= $report %>">
Select date between <%= $dates->[0] %> and <%= $dates->[1] %>:<br>

<input class="input-small" name="startdate" type="text" id="from" size=25> -
<input class="input-small" name="enddate" type="text" id="to" size=25>
<button type="submit" class="btn">set dates range</button>
<br>Current Date Range: <b><%= $startdate %></b> and <b><%= $enddate %></b>
</form>



<%# --------------------------------------------------------- %>
@@ left_packages.html.ep

Packages:<br>
<ul>
% foreach my $a (@$pack) {
	<li><a href="<%= url_for('index')->query( package => $a->[0], testsuite => $testsuite, startdate => $startdate, enddate => $enddate, report => $report ) %> ">
	% if ($a->[0] eq $package) {
		<b> <%= $a->[0] %> </b>
		% } else {
			<%= $a->[0] %>
		% }
		</a></li>
% }
</ul>


<%# --------------------------------------------------------- %>
@@ left_testsuites.html.ep

Testsuites:<br>
<ul>
% foreach my $a (@$testsuites) {
	<li><a href="<%= url_for('index')->query( package => $package, testsuite => $a->[0], startdate => $startdate, enddate => $enddate, report => $report ) %> ">
	% if ($a->[0] eq $testsuite) {
		<b> <%= $a->[0] %> </b>
		% } else {
			<%= $a->[0] %>
		% }
		</a></li>
% }
</ul>
<br>
<a href="<%= url_for('index')->query( package => $package, testsuite => '', startdate => $startdate, enddate => $enddate, report => $report ) %> " class="btn btn-mini btn-primary">
<b>RESET ACTIVE TESTSUITE</b></a>







<%# --------------------------------------------------------- %>
@@ short_report.html.ep



<table class="table table-condensed table-bordered">
<thead>
	<tr>
	<th>
		TestCases, count:
	</th>
	<th>
		Failures, count:
	</th>
	<th>
		Success rate, %:
	</th>
	<th>
		Total time, ms:
	</th>
	</tr>
</thead>
<tbody>
<tr>
	<td>
		<%= $res_short->[0] %>
	</td>
	<td style="color:#FF0000">
			<b>	<%= $res_short->[2] %> </b>
		</td>
	<td>
		%= ($res_short->[0] != 0) && sprintf ("%.3f", 100-$res_short->[2]/$res_short->[0]*100)
	</td>
	<td>
		%= sprintf ("%.3f", $res_short->[1])
	</td>
</tr>
</tbody>
</table>
<div class="row">
	<div class="span8">
	Statistic collected by package: <b>
		% if ($package ne '' ) {
			<%= $package %>
		% } else {
			!ALL
		% }
		</b> and testsuite: <b>
		%if ($testsuite ne '' ) {
			<%= $testsuite %>
		% } else {
			!ALL
		% }
		</b>
	</div>
	<div class="span3 offset6">
		<a id="show_hide_noerrors" href="#" class="btn">Hide passed testcases</a>
	</div>
</div>

<script type="text/javascript">

$(document).ready(function(){

var filter = 0;

$("#show_hide_noerrors").live( "click", function(event) {
    event.preventDefault();
    $('#show_hide_noerrors').html('...');
    if (filter == 1) {
        $('.no_error').show();
        filter = 0;
        $('#show_hide_noerrors').html('Hide passed testcases');
    }
    else {
    	$('.no_error').hide();
        filter = 1;
        $('#show_hide_noerrors').html('Show passed testcases');
    }
});

});
</script>



<%# --------------------------------------------------------- %>
@@ errors_report.html.ep



	% my $id = 0;
	% foreach my $ts_name (sort keys %{$reserr}) {
		% my $error_logs = 0;

		% foreach my $item (@{$reserr->{$ts_name}}) {
			% if ($item->{'f_cdata'} ne '-') {
			%	$error_logs++;
			% }
		% }
		% if ($error_logs == 0) {
			<div class="row no_error">
				<div class="span8">
					<br><h4><%= $ts_name %></h4>
				</div>
			</div>
			<div class="row no_error" style="text-align: center;"> <h5>
				<div class="span1">
					Build:
				</div>
				<div class="span1">
					Date:
				</div>
				<div class="span4">
					Testcase name
				</div>

				<div class="span1">
					Status:
				</div>
				<div class="span2">
					Log:
				</div></h5>
			</div>
		% } else {
			<div class="row">
				<div class="span8">
					<br><h4><%= $ts_name %></h4>
				</div>
			</div>
			<div class="row" style="text-align: center;"> <h5>
				<div class="span1">
					Build:
				</div>
				<div class="span1">
					Date:
				</div>
				<div class="span4">
					Testcase name:
				</div>

				<div class="span1">
					Status:
				</div>
				<div class="span2">
					Log:
				</div>
			</div></h5>
		% }



			% my $color_id = 0;
		% foreach my $item (@{$reserr->{$ts_name}}) {
			% my @colors = ('#E8E8E8', '#E0E0E0');
			% if ($item->{'f_cdata'} eq '-') {
				  <div class="row no_error" style="background: <%== $colors[$color_id % 2] %> ;">
			% } else {
				  <div class="row" style="background: <%== $colors[$color_id % 2] %> ;">
			% }
			% $color_id++;
				<div class="span1">
					<%= $item->{'r_buildname'} %>
				</div>
				<div class="span1">
					<%= $item->{'r_date'} %>
				</div>
				<div class="span4">
					<%= $item->{'tc_name'} %>
				</div>
				<div class="span1" style="text-align: center;">
					<%# $item->{'f_type'} %>
					<b>
					% if ($item->{'f_type'} eq '') {
						<div style="color: #4CBB17; ">
							PASSED
						</div>
					% } else {
						<div style="color: #EE2C2C; ">
							FAILED
						</div>
					% }
					</b>
				</div>
				% if ($item->{'f_cdata'} ne '-') {
				<%# my $id = $ts_name; %>
				<%# $id =~ s/ /_/g; %>

				<div class="span2" style="text-align: center;">
					<div class="modal hide fade" id="<%= $id %>">
						<div class="modal-header">
							<button type="button" class="close" data-dismiss="modal">&times;</button>
							<h3>Error Log</h3>
						</div>

							<div class="modal-body" style="text-align: left;">
								<%== $item->{'f_cdata'} %>
							</div>

						<div class="modal-footer">
							<a href="#" class="btn btn-success" data-dismiss="modal">Close</a>
						</div>
					</div>
					<a class="btn  btn-primary" data-toggle="modal" href="#<%= $id %>">View Log</a>
				</div>
				% }
			</div>
		% }

		% $id++;
	% }




<%# --------------------------------------------------------- %>
@@ form.html.ep

<form name="myform" action="<%= url_for 'report' %>" method="POST">

Select a project:

<select name="package">

% foreach my $a (@$pack) {
	<option value="<%= $a->[0] %>"><%= $a->[0] %></option>
% }
</select></p>

Enter date between <%= $startdate %> and <%= $enddate %>:
<input name="userdate" type="text" size=25 value="2012-05-18">

<input type="submit" value="send">

</form>





<%# --------------------------------------------------------- %>
@@ error.html.ep
% layout 'main';


<h1> You input wrong date </h1>
<br>
<a href="<%= url_for '/' %>"> Click here for return to start page</a>




<%# --------------------------------------------------------- %>
@@ layouts/main.html.ep
<!DOCTYPE html>
<html>
  <head>
  <title><%= title %></title>
  <meta http-equiv="X-UA-Compatible" content="IE=Edge" />
  <link href="/css/bootstrap.css" rel="stylesheet">
  <link href="/css/pepper-grinder/jquery-ui-1.8.21.custom.css" rel="stylesheet">
  <script type="text/javascript" src="js/jquery-1.7.2.min.js"></script>
  <script type="text/javascript" src="js/jquery-ui-1.8.21.custom.min.js"></script>
  <script>
	$(function() {
		$( "#from" ).datepicker({

			changeMonth: true,
			numberOfMonths: 1,
			dateFormat: "yy-mm-dd",
			firstDay: 1,
			gotoCurrent: true,
			showAnim: 'slideDown',
			changeYear: true,
			onSelect: function( selectedDate ) {
				$( "#to" ).datepicker( "option", "minDate", selectedDate );
			}
		});
		$( "#to" ).datepicker({

			changeMonth: true,
			numberOfMonths: 1,
			dateFormat: "yy-mm-dd",
			firstDay: 1,
			gotoCurrent: true,
			showAnim: 'slideDown',
			changeYear: true,
			onSelect: function( selectedDate ) {
				$( "#from" ).datepicker( "option", "maxDate", selectedDate );
			}
		});
	});
	</script>
	<style type="text/css">
		html { overflow-y: scroll; }
		pre {
 			 	overflow: auto;
  				word-wrap: normal;
  				white-space: pre;
			}
		.modal pre {
				max-height: 320px;
			}
		.modal {
			left: 35%;
			width: 950px;
		}

	</style>

 </head>
 <body>
	<div class="container">
	<div class="row" style="margin-bottom: 10px">
		<div class="span12">
			<a href="/"><img src="logo.gif" style="border: 0px" alt="Alstom ASF test framework" /></a>
		</div>
	</div>
	<div class="row" style="margin-bottom: 10px">
		<div class="span12">
			<h2> <span class="hhead">ASF Testing report framework</span></h2>
		</div>

	</div>


  <%= content %>

	</div> <!-- conteiner -->

<script src="js/bootstrap-modal.js"></script>




  </body>
</html>