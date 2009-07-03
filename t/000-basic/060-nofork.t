#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';

use Event::Lite::Server;
use Event::Lite::Publisher;
use Event::Lite::Subscriber::NoFork;
use Time::HiRes qw( usleep gettimeofday );
use forks;

$::port = int( rand() * 10000 ) until $::port && $::port > 1024;

ok(
  my $server = Event::Lite::Server->new(
    address => '127.0.0.1',
    port    => $::port,
  ),
  'server.new'
);

$server->run();



my $max_events = 1_000;
my $pub = Event::Lite::Publisher->new(
  address => '127.0.0.1',
  port    => $::port,
);

my $worker = async {
  my $subs = Event::Lite::Subscriber::NoFork->new(
    address => '127.0.0.1',
    port    => $::port,
  );
  $subs->subscribe(
    event => 'test.event',
    callback  => sub {
      my $evt = shift;
      $::SUBSCRIBER->stop
        if $evt->{num} == $max_events;
    },
  );
  $subs->stop();
};

my $start = gettimeofday();
$pub->publish(
  event => 'test.event',
  num   => $_
) for 1..$max_events;
$worker->join;
my $diff = gettimeofday() - $start;
my $rate = $max_events / $diff;
warn "\n\t$max_events handled in $diff seconds: rate = $rate/second\n";

sleep(2);
$pub->stop();

$server->stop();

