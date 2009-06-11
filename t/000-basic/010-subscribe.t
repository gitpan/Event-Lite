#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';

use_ok('Event::Lite::Server');
use_ok('Event::Lite::Subscriber');

my $server = Event::Lite::Server->new(
  address => '127.0.0.1',
  port    => 34343,
);

$server->run();

my $subscriber = Event::Lite::Subscriber->new(
  address => '127.0.0.1',
  port    => 34343,
);
sleep(1);

$subscriber->subscribe(
  event => 'yay',
  callback  => sub { warn "Hello world" }
);

sleep(5);

$subscriber->stop();
$server->stop();

