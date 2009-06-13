#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';

use_ok('Event::Lite::Server');
use_ok('Event::Lite::Subscriber');

$::port = int( rand() * 10000 ) until $::port && $::port > 1024;

my $server = Event::Lite::Server->new(
  address => '127.0.0.1',
  port    => $::port,
);

$server->run();

my $subscriber = Event::Lite::Subscriber->new(
  address => '127.0.0.1',
  port    => $::port,
);

$subscriber->subscribe(
  event => 'yay',
  callback  => sub { warn "Hello world" }
);


$subscriber->stop();
$server->stop();

