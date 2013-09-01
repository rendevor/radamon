#!/usr/bin/perl

use Mojolicious::Lite;
use DBI;
use List::MoreUtils qw (uniq);
use common::sense;
use Encode;
use utf8;
use encoding 'utf8';


my $g_dsn='DBI:mysql:rada_analys:localhost';
my $g_db_user = 'test';
my $g_db_passw = 'test';
my $dbh=DBI->connect($g_dsn,$g_db_user, $g_db_passw) or die;
my $sql = qq{SET NAMES 'utf8';};
$dbh->do($sql);

sub GetParties {
    my $q;
    $q = "SELECT  `p`.`name` , COUNT(  `p`.`name` ) 
            FROM  `Parties` p
            INNER JOIN  `deputates` d ON  `p`.`id` =  `d`.`party_id` 
            GROUP BY  `p`.`name` ";
    my $sth = $dbh->prepare($q);
    $sth->execute;
    my %res;
    while (my @line = $sth->fetchrow_array()) {
        $res{$line[0]} = $line[1];
    }
    return \%res;
}


get '/' => sub {
    my $self = shift;
    my $parties = GetParties();
    $self->stash(parties=>$parties);
    $self->stash(title=>"Rada Analys");
    $self->stash(content=>"Rada Analys will be here");
    
} => 'index';

app->start;