#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';

use_ok('Event::Lite::Server');
use_ok('Event::Lite::Publisher');

my $server = Event::Lite::Server->new(
  address => '127.0.0.1',
  port    => 34343,
);

$server->run();

my $publisher = Event::Lite::Publisher->new(
  address => '127.0.0.1',
  port    => 34343,
);

$publisher->publish(
  event => 'test-event',
);

sleep(5);

$publisher->stop();
$server->stop();

