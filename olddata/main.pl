#!/usr/bin/perl
use Data::Dumper;
use Mojo::UserAgent;
use Mojo::Message::Request;

use encoding 'utf8';
use utf8;
use Encode;
use DBI;
use common::sense;


my $g_dsn='DBI:mysql:rada_analys:rada.local';
my $g_db_user = 'test';
my $g_db_passw = 'test';
my $dbh=DBI->connect($g_dsn,$g_db_user, $g_db_passw) or die;
my $sql = qq{SET NAMES 'utf8';};
$dbh->do($sql);

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
		
			$sth = $dbh->prepare("SELECT `id` FROM `selection_area` WHERE `name` = ?");
			$sth->execute($selection_area);
			$selection_area_id = $sth->fetchrow();
			if (!defined($selection_area_id)) {
				$sth=$dbh->prepare("INSERT INTO `selection_area` (`name`, `LastUpdate`) VALUES (?, NOW())");
				$sth->execute($selection_area);
				say ("Insert selection area");
				$sth = $dbh->prepare("SELECT `id` FROM `selection_area` WHERE `name` = ?");
				$sth->execute($selection_area);
				$selection_area_id = $sth->fetchrow();
			} else {
				$sth=$dbh->prepare("UPDATE `selection_area` SET `LastUpdate` = NOW()
						   WHERE `id` = ?");
				$sth->execute($selection_area_id);
				say("Update selection area.");
			}
		}
		if ($region) {
			$sth = $dbh->prepare("SELECT `id` FROM `regions` WHERE `name` = ?");
			$sth->execute($region);
			$region_id = $sth->fetchrow();
			if (!defined($region_id)) {
				$sth=$dbh->prepare("INSERT INTO `regions` (`name`, `LastUpdate`) VALUES (?, NOW())");
				$sth->execute($region);
				say ("Insert region");
				$sth = $dbh->prepare("SELECT `id` FROM `regions` WHERE `name` = ?");
				$sth->execute($region);
				$region_id = $sth->fetchrow();
			} else {
				$sth=$dbh->prepare("UPDATE `regions` SET `LastUpdate` = NOW()
						   WHERE `id` = ?");
				$sth->execute($region_id);
				say("Update party.");
			}
		}
		
		if ($party) {
			$sth = $dbh->prepare("SELECT `id` FROM `Parties` WHERE `name` = ?");
			$sth->execute($party);
			$party_id = $sth->fetchrow();
			if (!defined($party_id)) {
				$sth=$dbh->prepare("INSERT INTO `Parties` (`name`, `LastUpdate`) VALUES (?, NOW())");
				$sth->execute($party);
				say ("Insert party");
				$sth = $dbh->prepare("SELECT `id` FROM `Parties` WHERE `name` = ?");
				$sth->execute($party);
				$party_id = $sth->fetchrow();
			} else {
				$sth=$dbh->prepare("UPDATE `Parties` SET `LastUpdate` = NOW()
						   WHERE `id` = ?");
				$sth->execute($party_id);
				say("Update party.");
			}
		}
		
		$party_id = (defined($party_id)) ? $party_id : '';
		$selection_area_id = (defined($selection_area_id)) ? $selection_area_id : '';
		$region_id = (defined($region_id)) ? $region_id : '';
		
		$sth=$dbh->prepare("SELECT `name`, `profile_url` FROM deputates WHERE `name` = ? AND `profile_url` = ? ");
		$sth->execute($deputate_name, $deputate_profile_url);
		my $rowline = $sth->fetchrow();
		if (!defined($rowline)) {
			$sth=$dbh->prepare("INSERT INTO `deputates` (`Name`, `profile_url`, `party_id`, `selection_area_id`, `region_id`, `LastUpdate`)
						VALUES (?, ?, ?, ?, ?, NOW())");
			$sth->execute($deputate_name, $deputate_profile_url, $party_id, $selection_area_id, $region_id);
			say ("Inserting deputate.");
		} else {
			$sth=$dbh->prepare("UPDATE `deputates` SET `lastupdate` = NOW() , `party_id` = ?, `selection_area_id` = ?, `region_id` = ?
					   WHERE `name` = ? AND `profile_url` = ? ");
			$sth->execute($party_id, $selection_area_id, $region_id, $deputate_name, $deputate_profile_url);
			say ("updating deputate.");
		}
		
	
	}
}



# Parsging details for each deputates.
sub parsing_indernal_links {
	
	my $sth = $dbh->prepare("SELECT max(`id`) FROM `deputates` WHERE `name` IS NOT NULL");
	$sth->execute;
	my $max_dep_id = $sth->fetchrow();
	for (my $dep_id = 0; $dep_id <= $max_dep_id; $dep_id++) {
		my $sth_loc = $dbh->prepare("SELECT `profile_url` FROM `deputates` WHERE id = ?");
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
		$sth = $dbh->prepare("UPDATE `deputates` SET `lastupdate` = NOW(), `votes_url` = ?, `el_registrations_url` = ?, `hand_registrations_url` = ?,
				     `parties_movement_url` = ?, `posts_by_election_url` = ?, `chronology_speach_url` = ?, `requests_url` = ?,
				     `lawmaking_url` = ?, internal_id = ?
				     WHERE `id` = ?");
		$sth->execute($votes, $el_registration, $manual_registration, $fraction_transfer, $posts, $chronology, $requests, $lawmaking, $internal_id,
				$dep_id);
		$sth->finish;
		
	}
}

sub parsing_votes {
	my $sth = $dbh->prepare("SELECT max(`id`) FROM `deputates` WHERE `name` IS NOT NULL");
	$sth->execute;
	my $max_dep_id = $sth->fetchrow();
	for (my $dep_id = 0; $dep_id <= $max_dep_id; $dep_id++) {
		my $sth_loc = $dbh->prepare("SELECT `votes_url` FROM `deputates` WHERE id = ?");
		$sth_loc->execute($dep_id);
		my $url = $sth_loc->fetchrow();
		($url) ? '' : next;
		if ($url !~ /^http:/) {
			$url = $Domain . $url;
		}
		#http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_dep?vid=1&kod=317
		#http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_dep_gol_list?startDate=12.12.2012&endDate=06.03.2013&kod=317
		my $ua = Mojo::UserAgent->new();
		my $item = $ua->get($url)->res->dom->find('div#list_g ul.pd li');
		#say Dumper($item);
		foreach my $page1 ($item->each) {
			my $vote_date;
			my $law_url;
			my $law_text;
			my $vote;
			if ($page1->at('div.strdate')) {
				$vote_date = test_decode_utf8($page1->div->text);
			}
			if ($page1->at('div.zname')) {
				$law_text = test_decode_utf8($page1->at('div.zname')->text);
				$law_url = $page1->at('div.zname')->{'href'};
			}
			if ($page1->at('div.zrez')) {
				$vote = test_decode_utf8($page1->at('div.zrez')->text);
			}
			
		}
		
		
		my $votes;
		my $el_registration;
		my $manual_registration;
		my $fraction_transfer;
		my $posts;
		my $chronology;
		my $requests;
		my $lawmaking;
		my $internal_id;	
	}
	
}


parsing_votes;


print "hehe\n";
