#!/usr/bin/perl
use Data::Dumper;
use Mojo::UserAgent;
use Mojo::Message::Request;

use encoding 'utf8';
use utf8;
use Encode;
use DBI;
use common::sense;


#$Data::Dumper::Maxdepth=2;

my $g_dsn='DBI:mysql:rada_analys:rada.local';
my $g_db_user = 'test';
my $g_db_passw = 'test';
my $dbh=DBI->connect($g_dsn,$g_db_user, $g_db_passw) or die;
my $sql = qq{SET NAMES 'utf8';};
$dbh->do($sql);
#
my $Domain = "http://w1.c1.rada.gov.ua";


my $ua = Mojo::UserAgent->new;

my $i=0;

sub test_decode_utf8 {
	my $ret = $_[0];
	if (!utf8::is_utf8($ret)) {
		$ret = decode('cp1251', $ret);
	}
	return $ret;
}

sub fixdate {
	my $ret = shift;
	$ret =~ s/\s//g;
	$ret =~ s/(\d{2}).(\d{2}).(\d{4})/\3-\2-\1/;
	return $ret;
}

sub fixdatetime {
	my $ret = shift;
	$ret =~ s/\s//g;
	$ret =~ s/(\d{2}).(\d{2}).(\d{4})/\3-\2-\1 /;
	$ret =~ s/[^\d\.\:\- ]//g;
	$ret =~ s/(\d{2}).(\d{2}).(\d{4})\s(\d{2}).(\d{2}).(\d{2})/\3-\2-\1 \4:\5:\6/;
	return $ret;
}

# Parsing Full list of depuatates
sub parsing_full_list {
	my $ua = Mojo::UserAgent->new;
	foreach my $page ( $ua->get("http://rada.local/123123.htm")->res->dom
		->html->body->ul->li->each) {
		
		my $sth;
		my $party;
		my $party_id;
		my $selection_area;
		my $selection_area_id;
		my $region;
		my $region_id;
		my $deputate_name = test_decode_utf8($page->p->[1]->a->text);
		my $deputate_profile_url = test_decode_utf8($page->p->[1]->a->{href});
		
		for (my $k = 0; $k < 4; $k++) {
			my $dt;
			my $dd;
			if ($page->dl->dt->[$k]) {
				$dt = test_decode_utf8($page->dl->dt->[$k]->text);
			} 
			if ($page->dl->dt->[$k]) {
				$dd = test_decode_utf8($page->dl->dd->[$k]->text);
			}
			if ($dt =~ /ПАРТІЯ:/i) {
				$party = $dd;
				next;
			}
			if ($dt =~ /РЕГІОН:/i) {
				$region = $dd;
				next;
			}
			if ($dd =~ /Виборчому округу/i) {
				$selection_area = $dd;
				next;
			}
			
		}
		
		if ($selection_area) {
		
			$sth = $dbh->prepare("SELECT `id` FROM `d_selection_area` WHERE `name` = ?");
			$sth->execute($selection_area);
			$selection_area_id = $sth->fetchrow();
			if (!defined($selection_area_id)) {
				$sth=$dbh->prepare("INSERT INTO `d_selection_area` (`name`, `LastUpdate`) VALUES (?, NOW())");
				$sth->execute($selection_area);
				say ("Insert selection area");
				$sth = $dbh->prepare("SELECT `id` FROM `d_selection_area` WHERE `name` = ?");
				$sth->execute($selection_area);
				$selection_area_id = $sth->fetchrow();
			} else {
				$sth=$dbh->prepare("UPDATE `d_selection_area` SET `LastUpdate` = NOW()
						   WHERE `id` = ?");
				$sth->execute($selection_area_id);
				say("Update selection area.");
			}
		}
		if ($region) {
			$sth = $dbh->prepare("SELECT `id` FROM `d_regions` WHERE `name` = ?");
			$sth->execute($region);
			$region_id = $sth->fetchrow();
			if (!defined($region_id)) {
				$sth=$dbh->prepare("INSERT INTO `d_regions` (`name`, `LastUpdate`) VALUES (?, NOW())");
				$sth->execute($region);
				say ("Insert region");
				$sth = $dbh->prepare("SELECT `id` FROM `d_regions` WHERE `name` = ?");
				$sth->execute($region);
				$region_id = $sth->fetchrow();
			} else {
				$sth=$dbh->prepare("UPDATE `d_regions` SET `LastUpdate` = NOW()
						   WHERE `id` = ?");
				$sth->execute($region_id);
				say("Update party.");
			}
		}
		
		if ($party) {
			$sth = $dbh->prepare("SELECT `id` FROM `d_Parties` WHERE `name` = ?");
			$sth->execute($party);
			$party_id = $sth->fetchrow();
			if (!defined($party_id)) {
				$sth=$dbh->prepare("INSERT INTO `d_Parties` (`name`, `LastUpdate`) VALUES (?, NOW())");
				$sth->execute($party);
				say ("Insert party");
				$sth = $dbh->prepare("SELECT `id` FROM `d_Parties` WHERE `name` = ?");
				$sth->execute($party);
				$party_id = $sth->fetchrow();
			} else {
				$sth=$dbh->prepare("UPDATE `d_Parties` SET `LastUpdate` = NOW()
						   WHERE `id` = ?");
				$sth->execute($party_id);
				say("Update party.");
			}
		}
		
		$party_id = (defined($party_id)) ? $party_id : '';
		$selection_area_id = (defined($selection_area_id)) ? $selection_area_id : '';
		$region_id = (defined($region_id)) ? $region_id : '';
		
		$sth=$dbh->prepare("SELECT `name`, `profile_url` FROM `d_deputates` WHERE `name` = ? AND `profile_url` = ? ");
		$sth->execute($deputate_name, $deputate_profile_url);
		my $rowline = $sth->fetchrow();
		if (!defined($rowline)) {
			$sth=$dbh->prepare("INSERT INTO `d_deputates` (`Name`, `profile_url`, `party_id`, `selection_area_id`, `region_id`, `LastUpdate`)
						VALUES (?, ?, ?, ?, ?, NOW())");
			$sth->execute($deputate_name, $deputate_profile_url, $party_id, $selection_area_id, $region_id);
			say ("Inserting deputate.");
		} else {
			$sth=$dbh->prepare("UPDATE `d_deputates` SET `lastupdate` = NOW() , `party_id` = ?, `selection_area_id` = ?, `region_id` = ?
					   WHERE `name` = ? AND `profile_url` = ? ");
			$sth->execute($party_id, $selection_area_id, $region_id, $deputate_name, $deputate_profile_url);
			say ("updating deputate.");
		}
		
	
	}
}



# Parsging details for each deputates.
sub parsing_indernal_links {
	
	my $sth = $dbh->prepare("SELECT max(`id`) FROM `d_deputates` WHERE `name` IS NOT NULL");
	$sth->execute;
	my $max_dep_id = $sth->fetchrow();
	for (my $dep_id = 0; $dep_id <= $max_dep_id; $dep_id++) {
		my $sth_loc = $dbh->prepare("SELECT `profile_url` FROM `d_deputates` WHERE id = ?");
		$sth_loc->execute($dep_id);
		my $url = $sth_loc->fetchrow();
		($url) ? '' : next;
		my $ua_loc = Mojo::UserAgent->new;
		my $page;
		my $votes;
		my $el_registration;
		my $manual_registration;
		my $fraction_transfer;
		my $posts;
		my $chronology;
		my $requests;
		my $lawmaking;
		my $internal_id;
		foreach my $page1 ($ua_loc->get($url)->res->dom->find('div.topTitle a')->each) {
			#my $internal_id = $page1->{href}->query_params->to_hash->{kod};
			my $text = test_decode_utf8($page1->text);
			my $url = test_decode_utf8($page1->{href});
			my $req = Mojo::Parameters->new($url);
			$internal_id = ($internal_id ? $internal_id : $req->param('kod'));
			($text =~ /Голосування депутата/i) and $votes = $url;
			($text =~ /Реєстрація депутата за допомогою електронної системи/i) and $el_registration = $url;
			($text =~ /Письмова реєстрація депутата/i) and $manual_registration = $url;
			($text =~ /Переходи по фракціях/i) and $fraction_transfer = $url;
			($text =~ /Посади протягом скликання/i) and $posts = $url;
			($text =~ /Хронологія виступів депутата/i) and $chronology = $url;
			($text =~ /Депутатські запити/i) and $requests = $url;
			($text =~ /Законотворча діяльність/i) and $lawmaking = $url;
		}
		say ("updating dep with id = $dep_id");
		$sth = $dbh->prepare("UPDATE `d_deputates` SET `lastupdate` = NOW(), `votes_url` = ?, `el_registrations_url` = ?, `hand_registrations_url` = ?,
				     `parties_movement_url` = ?, `posts_by_election_url` = ?, `chronology_speach_url` = ?, `requests_url` = ?,
				     `lawmaking_url` = ?, internal_id = ?
				     WHERE `id` = ?");
		$sth->execute($votes, $el_registration, $manual_registration, $fraction_transfer, $posts, $chronology, $requests, $lawmaking, $internal_id,
				$dep_id);
		$sth->finish;
		
	}
}

sub parsing_votes {
	#my $law_sdate = shift;
	#my $law_edate = $law_sdate;
	my $sth = $dbh->prepare("SELECT max(`id`) FROM `d_deputates` WHERE `name` IS NOT NULL");
	$sth->execute;
	my $max_dep_id = $sth->fetchrow();
	for (my $dep_id = 0; $dep_id <= $max_dep_id; $dep_id++) {
		my $sth_loc = $dbh->prepare("SELECT `votes_url` FROM `d_deputates` WHERE id = ?");
		$sth_loc->execute($dep_id);
		say ("Deputat id: $dep_id");
		my $url = $sth_loc->fetchrow();
		($url) ? '' : next;
		if ($url !~ /^http:/) {
			$url = $Domain . $url;
		}
		say "$dep_id - $url";
		my $dep_kod;
		$url =~ /&kod=(\d+)/;
		$dep_kod = $1;
		#http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_dep?vid=1&kod=317
		#http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_dep_gol_list?startDate=12.12.2012&endDate=06.03.2013&kod=317
		my $ua = Mojo::UserAgent->new();
		$ua->on(error => sub {
			my ($ua, $err) = @_;
			say "ERROR OCURED: $err";
			die;
		});
		#my $item = $usa->get($url)->res->dom->find('div#list_g ul.pd li');
		say ("GETTING - $url");
		
		my $item = $ua->get($url)->res->dom->find('form');
		my $law_name;
		my $law_url;
		my $law_vote;
		my $law_sdate = '12.12.2012';
		my $law_edate = '24.12.2013';
		my $b_changed_url;
		if (scalar (@{$item})) {
			foreach my $itm ($item->each) {
				if ($itm->{onsubmit}) {
					say ("Found ONSUBMIT");
					#say $itm->{onsubmit};
					my $oldurl = $url;
					$url = $itm->{onsubmit};
					$url =~ s/form_data\('//;
					$url =~ s/',/?/;
					$url =~ s/this.Db.value,/startdate=$law_sdate&/;
					$url =~ s/this.De.value,/enddate=$law_edate&/;
					$url =~ s/this.kod.value.*$/kod=$dep_kod&nom_str=0/;
					$url =$Domain.$url;
					#say "$oldurl --> $url";
					$b_changed_url = 1;
				}
			}
		}
		if ($b_changed_url == 1) {
			say ("Getting changed url: $url");
			$ua = $ua->get($url)->res->dom;
		}
		
		
		my $date;
		my %records;
		#say Dumper $ua;
		foreach my $item($ua->find('ul li')->each) {
			#say Dumper $item->at('li')->all_text;
			if ($item->at('div.strdate')) {
				$date = $item->at('div.strdate')->text;
				$date =~ s/\s//g;
				$date =~ s/(\d{2}).(\d{2}).(\d{4})/\3-\2-\1/;
			} else {
				push @{$records{$date}}, $item;
			}
		}
		
		for my $date (sort keys (%records)) {
			say $date;
			for my $itm (@{$records{$date}}) {
				if ($itm->at('div.zname a')) {
					my $law_name = test_decode_utf8 $itm->at('div.zname a')->text;
					my $law_url = $itm->at('div.zname a')->{'href'};
					my $law_vote = test_decode_utf8 $itm->at('div.zrez')->text;
					my $law_vote_date = $date;
					
					
					
					#Select law draft id or insert new and select new id.
					$sth = $dbh->prepare("SELECT `id` FROM `d_laws` WHERE `name` = ? AND `url` = ? ");
					$sth->execute($law_name, $law_url);
					my $law_id = $sth->fetchrow();
					if ($law_id) {
						$sth = $dbh->prepare("UPDATE `d_laws` SET `LastUpdate` = NOW() WHERE `id` = ?");
						$sth->execute($law_id);
					} else {
						$sth = $dbh->prepare("INSERT INTO `d_laws` (`name`, `url`, `lastUpdate`) VALUES (?, ?, NOW())");
						$sth->execute($law_name, $law_url);
						$sth = $dbh->prepare("SELECT `id` FROM `d_laws` WHERE `name` = ? AND `url` = ? ");
						$sth->execute($law_name, $law_url);
						$law_id = $sth->fetchrow();
					}
					
					#select vote id or insert new or update
					$sth = $dbh->prepare("SELECT `id` FROM `d_votes` WHERE `int_dep_kod` = ? AND `law_id` = ? AND `dep_vote` = ?");
					$sth->execute($dep_kod, $law_id, $law_vote);
					my $vote_id = $sth->fetchrow();
					if ($vote_id) {
						$sth = $dbh->prepare("UPDATE `d_votes` SET `LastUpdate` = NOW(), `int_dep_kod` = ?, `law_id` = ?,
											 `dep_vote` = ?, `vote_date` = ? WHERE `id` = ?");
						$sth->execute($dep_kod, $law_id, $law_vote, $law_vote_date, $vote_id);
					} else {
						$sth = $dbh->prepare("INSERT INTO `d_votes` (`law_id`, `int_dep_kod`, `dep_vote`, `vote_date`, `lastUpdate`)
											 VALUES (?, ?, ?, ?, NOW())");
						$sth->execute($law_id, $dep_kod, $law_vote, $law_vote_date);
					}
					#say "Next law..."
					say ("Dep: $dep_kod -- VOTE: $law_vote_date -- $law_vote ");			
				}
			}
		}
	}
}


sub parsing_elregestrations {
	#my $law_sdate = shift;
	#my $law_edate = $law_sdate;
	my $sth = $dbh->prepare("SELECT max(`id`) FROM `d_deputates` WHERE `name` IS NOT NULL");
	$sth->execute;
	my $max_dep_id = $sth->fetchrow();
	for (my $dep_id = 268; $dep_id <= $max_dep_id; $dep_id++) {
		my $sth_loc = $dbh->prepare("SELECT `el_registrations_url` FROM `d_deputates` WHERE id = ?");
		$sth_loc->execute($dep_id);
		say ("Deputat id: $dep_id");
		my $url = $sth_loc->fetchrow();
		($url) ? '' : next;
		if ($url !~ /^http:/) {
			$url = $Domain . $url;
		}
		say "$dep_id - $url";
		my $dep_kod;
		$url =~ /&kod=(\d+)/;
		$dep_kod = $1;
		#http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_dep?vid=1&kod=317
		#http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_dep_gol_list?startDate=12.12.2012&endDate=06.03.2013&kod=317
		my $ua = Mojo::UserAgent->new();
		#my $item = $usa->get($url)->res->dom->find('div#list_g ul.pd li');
		my $item = $ua->get($url)->res->dom->find('form');
		my $reg_datetime;
		my $reg_type;
		my $reg_total;
		my $reg_dep;
		my $law_sdate = '12.12.2012';
		my $law_edate = '24.12.2013';
		my $b_changed_url;
		if (scalar (@{$item})) {
			foreach my $itm ($item->each) {
				if ($itm->{onsubmit}) {
					#say $itm->{onsubmit};
					my $oldurl = $url;
					$url = $itm->{onsubmit};
					$url =~ s/form_data\('//;
					$url =~ s/',/?/;
					$url =~ s/this.Db.value,/startdate=$law_sdate&/;
					$url =~ s/this.De.value,/enddate=$law_edate&/;
					$url =~ s/this.kod.value.*$/kod=$dep_kod&nom_str=0/;
					$url =$Domain.$url;
					say "$oldurl --> $url";
					$b_changed_url = 1;
				}
			}
		}
		if ($b_changed_url == 1) {
			$ua = $ua->get($url)->res->dom;
		}
		#say ($url);
		
		my $date;
		my %records;
		#say Dumper $ua;
		foreach my $item($ua->find('ul li')->each) {
			#say Dumper $item->at('li')->all_text;
			if ($item->at('div.block_pd')) {
				#say $item->at('div.strdate b')->text ;
				$date = $item->at('div.strdate b')->text;
				$date .= $item->at('div.strdate')->text;
			
			#	$date = $item->at('div.strdate')->all_text;
				
				$date =~ s/\s//g;
				$date =~ s/(\d{2}).(\d{2}).(\d{4})/\3-\2-\1 /;
				$date =~ s/[^\d\.\:\- ]//g;
				$date =~ s/(\d{2}).(\d{2}).(\d{4})\s(\d{2}).(\d{2}).(\d{2})/\3-\2-\1 \4:\5:\6/;
				#say $date;	
			
				push @{$records{$date}}, $item->at('div.block_pd');
				#say $item->at('div.zname');
			}
		}
		for my $date (sort keys (%records)) {
			say $date;
			for my $itm (@{$records{$date}}) {
				if ($itm->at('div.zname a')) {
					my $reg_datetime = $date;
					my $reg_type = test_decode_utf8 $itm->at('div.zname')->all_text;
					my $reg_total = test_decode_utf8 $itm->at('div.strvsego')->all_text;
					my $reg_dep = test_decode_utf8 $itm->at('div.zrez')->all_text;
					#Select law draft id or insert new and select new id.
					$sth = $dbh->prepare("SELECT `id` FROM `d_registrations` WHERE `int_dep_kod` = ? AND `reg_type` = ? AND `reg_dep` = ?");
					$sth->execute($dep_kod, $reg_type, $reg_dep) or die $sth->err;
					my $reg_id = $sth->fetchrow();
					if ($reg_id) {
						$sth = $dbh->prepare("UPDATE `d_registrations` SET `LastUpdate` = NOW() WHERE `id` = ?");
						$sth->execute($reg_id);
					} else {
						$sth = $dbh->prepare("INSERT INTO `d_registrations` (`int_dep_kod`, `reg_type`, `reg_date`, `reg_dep`, `lastUpdate`)
											 VALUES (?, ?, ?, ?, NOW() )");
						$sth->execute($dep_kod, $reg_type, $reg_datetime, $reg_dep);
					}
					
					#select vote id or insert new or update
					say ("Dep: $dep_kod -- REG: $reg_type -- $reg_dep ");			
				}
			}
		}
	}
}


sub parsing_handregestrations {
	#my $law_sdate = shift;
	#my $law_edate = $law_sdate;
	my $sth = $dbh->prepare("SELECT max(`id`) FROM `d_deputates` WHERE `name` IS NOT NULL");
	$sth->execute;
	my $max_dep_id = $sth->fetchrow();
	for (my $dep_id = 0; $dep_id <= $max_dep_id; $dep_id++) {
		my $sth_loc = $dbh->prepare("SELECT `hand_registrations_url` FROM `d_deputates` WHERE id = ?");
		$sth_loc->execute($dep_id);
		say ("Deputat id: $dep_id");
		my $url = $sth_loc->fetchrow();
		($url) ? '' : next;
		if ($url !~ /^http:/) {
			$url = $Domain . $url;
		}
		say "$dep_id - $url";
		my $dep_kod;
		$url =~ /&kod=(\d+)/;
		$dep_kod = $1;
		#http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_dep?vid=1&kod=317
		#http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_dep_gol_list?startDate=12.12.2012&endDate=06.03.2013&kod=317
		my $ua = Mojo::UserAgent->new();
		#my $item = $usa->get($url)->res->dom->find('div#list_g ul.pd li');
		my $item = $ua->get($url)->res->dom->find('form');
		my $session_num;
		my $reg_date;
		my $reg_status;
		my $session_name;
		my $law_sdate = '12.12.2012';
		my $law_edate = '24.12.2013';
		my $b_changed_url;
		if (scalar (@{$item})) {
			foreach my $itm ($item->each) {
				if ($itm->{onsubmit}) {
					#say $itm->{onsubmit};
					my $oldurl = $url;
					$url = $itm->{onsubmit};
					$url =~ s/form_data\('//;
					$url =~ s/',/?/;
					$url =~ s/this.Db.value,/StartDate=$law_sdate&/;
					$url =~ s/this.De.value,/EndDate=$law_edate&/;
					$url =~ s/this.kod.value.*$/kod=$dep_kod&nom_str=0/;
					$url =$Domain.$url;
					say "$oldurl --> $url";
					$b_changed_url = 1;
				}
			}
		}
		if ($b_changed_url == 1) {
			$ua = $ua->get($url)->res->dom;
		}
		#say ($url);
		
		my $date;
		my %records;
		foreach my $item($ua->find('ul li')->each) {
			if ($item->at('div.block_pd')) {
				$date = $item->at('div.strdate b')->text;
				#$date .= $item->at('div.strdate')->text;
			#	$date = $item->at('div.strdate')->all_text;
				$date =~ s/\s//g;
				$date =~ s/(\d{2}).(\d{2}).(\d{4})/\3-\2-\1 /;
				$date =~ s/[^\d\.\:\- ]//g;
				$date =~ s/(\d{2}).(\d{2}).(\d{4})\s(\d{2}).(\d{2}).(\d{2})/\3-\2-\1 \4:\5:\6/;
				push @{$records{$date}}, $item->at('div.block_pd');
				#say $item->at('div.zname');
			}
		}
		
		for my $date (sort keys (%records)) {
			say $date;
			for my $itm (@{$records{$date}}) {
				if ($itm->at('div.zname a')) {
					my $session_num = test_decode_utf8 $itm->at('div.nomses')->all_text;
					my $reg_date = $date;
					my $session_name = test_decode_utf8 $itm->at('div.zname')->all_text;
					my $reg_status = $itm->at('div.zrez')->all_text;
					$reg_status = test_decode_utf8 $reg_status;
					$reg_status =~ s/\xA0//g;
					$sth = $dbh->prepare("SELECT `id` FROM `d_hardreg`
										 WHERE `int_dep_kod` = ? AND `reg_status` = ? AND `date` = ? AND `session_num` = ? AND session_name = ?"); 
					$sth->execute($dep_kod, $reg_status, $reg_date, $session_num, $session_name) or die $sth->err ;
					say "$dep_kod, $reg_status, $reg_date, $session_num, $session_name";
					my $reg_id = $sth->fetchrow;
					
					if ($reg_id) {
						say ("data existed");
					} else {
						$sth = $dbh->prepare("INSERT INTO `d_hardreg` (`int_dep_kod`, `reg_status`, `date`, `session_num`, `session_name`, `lastupdate`)
												VALUES (?, ?, ?, ?, ?, NOW() )");
						$sth->execute($dep_kod, $reg_status, $reg_date, $session_num, $session_name);
					}
					#say "Next registation..."				
				}
			}
		}
	}	
}

sub lawdraft_parsing {
	my $sth = $dbh->prepare("SELECT max(`id`) FROM `d_deputates` WHERE `name` IS NOT NULL");
	$sth->execute;
	my $max_dep_id = $sth->fetchrow();
	for (my $dep_id = 0; $dep_id <= $max_dep_id; $dep_id++) {
		my $sth_loc = $dbh->prepare("SELECT `lawmaking_url` FROM `d_deputates` WHERE id = ?");
		$sth_loc->execute($dep_id);
		say ("Deputat id: $dep_id");
		my $url = $sth_loc->fetchrow();
		($url) ? '' : next;
		if ($url !~ /^http:/) {
			$url = $Domain . $url;
		}
		say "$dep_id - $url";
		my $dep_kod;
		$url =~ /&kod=(\d+)/;
		$dep_kod = $dep_id;
		my $ua = Mojo::UserAgent->new();
		my $items = $ua->get($url)->res->dom->find('div.information_block_ins table tr');
		#say Dumper $items;
		for my $item ($items->each) {
			if ($item->at('th')) { next; }
			
				
				#$Data::Dumper::Maxdepth = 6;
				#say Dumper $item;
				#say test_decode_utf8 $item->all_text;
				#if ($item->text) {say $item->text};
				my $draft_name;
				my $draft_url;
				my $draft_date;
				my $draft_id;
				my $draft_law_id;
				($item->at('div a')) and $draft_id = test_decode_utf8 $item->at('div a')->text;
				($item->at('div a')) and $draft_url = test_decode_utf8 $item->at('div a')->{'href'};
				$draft_date = fixdate $item->at('i')->text;
				$draft_name = test_decode_utf8 $item->find('td')->[2]->text;
				$draft_law_id = test_decode_utf8 $item->find('td')->[3]->text;
				$draft_law_id =~ s/\xA0//g;
				if ($draft_id) {
					my $sth = $dbh->prepare("SELECT `id` FROM `d_lawdrafts`
										 WHERE `dep_id` = ? AND `reg_id` = ? AND `reg_date` = ? AND `name` = ? "); 
					$sth->execute($dep_kod, $draft_id, $draft_date, $draft_name) or die $sth->err ;
					#say "$dep_kod, $reg_status, $reg_date, $session_num, $session_name";
					my $reg_id = $sth->fetchrow;
					
					if ($reg_id) {
						say ("data existed");
					} else {
						$sth = $dbh->prepare("INSERT INTO `d_lawdrafts` (`dep_id`, `reg_id`, `reg_date`, `name`, `detail_url`, `law_id`,
											 `lastupdate`)
												VALUES (?, ?, ?, ?, ?, ?, NOW() )");
						$sth->execute($dep_kod, $draft_id, $draft_date, $draft_name, $draft_url, $draft_law_id);
					}
					say ("$dep_kod -> $draft_id($draft_date) -->: $draft_law_id :");
				}
		}
	}
}

sub lawdraft_cards_parsing {
	my $sth = $dbh->prepare("SELECT max(`id`) FROM `d_lawdrafts` WHERE `name` IS NOT NULL");
	$sth->execute;
	my $max_draft_id = $sth->fetchrow();
	for (my $draft_id = 143; $draft_id <= $max_draft_id; $draft_id++) {
		my $sth_loc = $dbh->prepare("SELECT `detail_url` FROM `d_lawdrafts` WHERE id = ?");
		$sth_loc->execute($draft_id);
		say ("Lawdraft id: $draft_id");
		my $url = $sth_loc->fetchrow();
		
		$sth_loc = $dbh->prepare("SELECT `reg_id` FROM `d_lawdrafts` WHERE id = ?");
		$sth_loc->execute($draft_id);
		my $reg_id = $sth_loc->fetchrow();
		
		($url) ? '' : next;
		if ($url !~ /^http:/) {
			$url = $Domain . $url;
		}
		say $url;
		my $ua = Mojo::UserAgent->new();
		my $session_reg;
		my $owner_type;
		my $main_commitee;
		my $other_commitee;
		my $content = $ua->get($url)->res->dom;
		
		
		
		
		for my $dtdd ($content->find('div.zp-info dl')->each) {
			for (my $i = 0; $i < 10; $i++) {
			#say scalar @{$dtdd->dd->each};
			#say $dtdd->dd->[1];
			#say $dtdd->pare->at('dd')->text;
			#say Dumper $dtdd->dt->[1]->text;
			#say $dtdd->dd->text;
			
			my $dt = test_decode_utf8 $dtdd->dt->[$i]->all_text if ($dtdd->dt->[$i]);
			my $dd = test_decode_utf8 $dtdd->dd->[$i]->all_text if ($dtdd->dd->[$i]);
			say $dt;
			say $dd;
				if ($dt =~ /Сесія реєстрації/i) {
					$session_reg = $dd;
				}
				if ($dt =~ /права законодавчої ініціативи/i) {
					$owner_type = $dd;
				}
				if ($dt =~ /Головний комітет/i) {
					$main_commitee = $dd;
				}
				if ($dt =~ /Інші комітети/i) {
					$other_commitee = $dd;
				}
			}
		} 
		
		
		
		$main_commitee = ($main_commitee ne '') ? $main_commitee : 'no_comm';
		$other_commitee = ($other_commitee ne '') ? $other_commitee : 'no_comm';
		$session_reg = ($session_reg ne '') ? $session_reg : 'no_session';
		$owner_type = ($owner_type ne '') ? $owner_type : 'no_owner';
		say "$reg_id :: $session_reg :: $owner_type -> ";
		say "\t$main_commitee";
		say "\t$other_commitee";
		
		
	
		
		$sth = $dbh->prepare("INSERT INTO `d_lawdrafts_card` (`law_draft_id`, `session_reg`, `owner_type`, `main_commitee`, `other_commitee` )
							 VALUES (?, ?, ?, ?, ?) ");
		$sth->execute($draft_id, $session_reg, $owner_type, $main_commitee, $other_commitee) or die $sth->err;
		$sth = $dbh->prepare('SELECT `id` FROM `d_lawdrafts_card` WHERE `law_draft_id`=? AND `session_reg`=? AND `owner_type`=? AND `main_commitee`=? AND
							 `other_commitee` = ? ') ;
		$sth->execute($draft_id, $session_reg, $owner_type, $main_commitee, $other_commitee) or die $sth->err;
		my $draft_card_id = $sth->fetchrow();
		
		say ("GET NEW ID for draft_card_id: $draft_card_id");
		
		for my $imt ($content->find('div#kom_processing_tab table tr')->each) {
			#say Dumper($imt);
			if ($imt->at('th')) { next;}
			#say $imt->all_text;
			my $commitee = test_decode_utf8 $imt->find('td')->[0]->text;
			my $sdate =  fixdate $imt->find('td')->[1]->text;
			my $edate = fixdate $imt->find('td')->[2]->text;
			
			$sth = $dbh->prepare('SELECT `id` FROM `d_commiteets` WHERE `name` = ?');
			$sth->execute($commitee) or die $sth->err;
			my $comm_id = $sth->fetchrow();
			if ($comm_id) {
				
			} else {
				$sth=$dbh->prepare('INSERT INTO `d_commiteets` (`name`, `lastupdated`) VALUES (?, NOW())');
				$sth->execute($commitee) or die $sth->err;
				$sth->finish();
				$sth = $dbh->prepare('SELECT `id` FROM `d_commiteets` WHERE `name` = ?');
				$sth->execute($commitee) or die $sth->err;
				$comm_id = $sth->fetchrow();
			}
			$sth = $dbh->prepare('INSERT INTO `m_commiteets_x_lawdraft_cards` (`commiteet_id`, `lawdrafts_card_id`, `start_date`, `end_date`, `lastupdated`)
								 VALUES (?, ?, ?, ?, NOW() ) ');
			$sth->execute($comm_id, $draft_card_id, $sdate, $edate) or die $sth->err;
			say ("COMMITEE: $commitee\[$comm_id\] :: $sdate-$edate :: $draft_card_id");
		}
		
		for my $imt ($content->find('div#flow_tab table tr')->each) {
			#say Dumper($imt);
			if ($imt->at('th')) { next;}
			#say $imt->all_text;
			my $stage = test_decode_utf8 $imt->find('td')->[0]->text;
			my $state = test_decode_utf8 $imt->find('td')->[1]->text;
			
			$sth = $dbh->prepare('SELECT `id` FROM `d_lawdrafts_passstages` WHERE `name` = ?');
			$sth->execute($stage) or die $sth->err;
			my $stage_id = $sth->fetchrow();
			if ($stage_id) {
				
			} else {
				$sth=$dbh->prepare('INSERT INTO `d_lawdrafts_passstages` (`name`, `lastupdated`) VALUES (?, NOW())');
				$sth->execute($stage) or die $sth->err;
				$sth->finish();
				$sth = $dbh->prepare('SELECT `id` FROM `d_lawdrafts_passstages` WHERE `name` = ?');
				$sth->execute($stage) or die $sth->err;
				$stage_id = $sth->fetchrow();
			}
			
			$sth = $dbh->prepare('SELECT `id` FROM `d_lawdrafts_passstates` WHERE `name` = ?');
			$sth->execute($state) or die $sth->err;
			my $state_id = $sth->fetchrow();
			if ($state_id) {
				
			} else {
				$sth=$dbh->prepare('INSERT INTO `d_lawdrafts_passstates` (`name`, `lastupdated`) VALUES (?, NOW())');
				$sth->execute($state) or die $sth->err;
				$sth->finish();
				$sth = $dbh->prepare('SELECT `id` FROM `d_lawdrafts_passstates` WHERE `name` = ?');
				$sth->execute($state) or die $sth->err;
				$state_id = $sth->fetchrow();
			}
			unless ($state_id) {
				say $state;
				die;
			}
			$sth = $dbh->prepare('INSERT INTO `m_lawdraft_card_x_passing` (`lawdrafts_card_id`, `lawdrafts_pstages_id`, `lawdrafts_pstates_id`, `lastupdate`)
								 VALUES (?, ?, ?, NOW() ) ');
			$sth->execute($draft_card_id, $stage_id, $state_id) or die $sth->err;
			say ("STAGE: $stage\[$stage_id\] :: STATE: $state\[$state_id\] :: $draft_card_id");
		}
		
		if ($content->find('div#ui-tabs-2')) {
			#say "true";
			#say $url;
			my $url1 = 'http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_zakon_gol_dep_wohf?zn='.$reg_id;
			#say "$reg_id";
			my $ua1 = Mojo::UserAgent->new();
			$ua1 = $ua1->get($url1)->res->dom;
			foreach my $itm ($ua1->find('ul form li')->each){
				if ($itm->at('div.nomer')) {next};
				my $v_date = $itm->at('div.fr_data')->text;
				$v_date = fixdatetime $v_date;
				my $v_name = test_decode_utf8 $itm->at('div.fr_nazva a')->text;
				my $v_url = $itm->at('div.fr_nazva a')->{'href'};
				
				$sth = $dbh->prepare('SELECT `id` FROM `d_laws` WHERE `name` = ? AND `url` = ?');
				$sth->execute($v_name, $v_url) or die $sth->err;
				my $vote_law_id = $sth->fetchrow();
				
				if ($vote_law_id) {
					$sth = $dbh->prepare('UPDATE `d_laws` SET `date` = ?, `lastupdate` = NOW() WHERE `id` = ?');
					$sth->execute($v_date, $vote_law_id) or die $sth->err;
				} else {
					$sth=$dbh->prepare('INSERT INTO `d_laws` (`name`, `url`, `date`, `lastupdate`) VALUES (?, ?, ?, NOW())');
					$sth->execute($v_name, $v_url, $v_date) or die $sth->err;
					$sth->finish();
					$sth = $dbh->prepare('SELECT `id` FROM `d_laws` WHERE `name` = ? AND `url` = ?');
					$sth->execute($v_name, $v_url) or die $sth->err;
					$vote_law_id = $sth->fetchrow();
				}
				$sth = $dbh->prepare('INSERT INTO `m_lawdraft_card_x_laws` (`d_laws_id`, `d_lawdrafts_card_id`, `lastupdated`)
									 VALUES (?, ?, NOW()) ');
				$sth->execute($draft_card_id, $vote_law_id) or die $sth->err;
				say ("MIX: $draft_card_id :: $vote_law_id");
			}
		}

		
	}
}
#parsing_votes;
#parsing_elregestrations

#parsing_handregestrations

#lawdraft_parsing;
lawdraft_cards_parsing;

	


print "hehe\n";
