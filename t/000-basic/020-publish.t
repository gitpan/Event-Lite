#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';

use_ok('Event::Lite::Server');
use_ok('Event::Lite::Publisher');

$::port = int( rand() * 10000 ) until $::port && $::port > 1024;

my $server = Event::Lite::Server->new(
  address => '127.0.0.1',
  port    => $::port,
);

$server->run();

my $publisher = Event::Lite::Publisher->new(
  address => '127.0.0.1',
  port    => $::port,
);

$publisher->publish(
  event => 'test-event',
);

sleep(5);

$publisher->stop();
$server->stop();

