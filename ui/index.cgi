#!/usr/bin/perl

use Mojolicious;
use DBI;
use List::MoreUtils qw (uniq);


my $g_dsn='DBI:mysql:rada_analys:rada.local';
my $g_db_user = 'test';
my $g_db_passw = 'test';
my $dbh=DBI->connect($g_dsn,$g_db_user, $g_db_passw) or die;
my $sql = qq{SET NAMES 'utf8';};
$dbh->do($sql);


get '/' => sub {
    $self = shift;
    $self->stash(title=>"Rada Analys");
    $self->stash(content=>"Rada Analys will be here");
    
} => 'index';

app->start;