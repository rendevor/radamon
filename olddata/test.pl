#!/usr/bin/perl
use Data::Dumper;
use Mojo::UserAgent;
use Mojo::Message::Request;

use encoding 'utf8';
use utf8;
use Encode;
use DBI;
use common::sense;



my $url = 'http://w1.c1.rada.gov.ua/pls/radan_gs09/ns_dep_gol_list?startDate=12.12.2012&endDate=06.03.2013&kod=317';
#my $url = 'http://google.com';
my $ua = Mojo::UserAgent->new();
#say $ENV{'http_proxy'};
$ua=$ua->http_proxy($ENV{'http_proxy'});
$ua = $ua->get($url);

# say Dumper $ua->res->content;
foreach my $ul ($ua->res->dom->find('div#list_g ul.pd li')->each) {
	
	say $ul->all_text;
}

