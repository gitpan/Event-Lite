#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';

use Event::Lite::Server;
use Event::Lite::Publisher;
use Event::Lite::Subscriber;
use Time::HiRes qw( usleep gettimeofday );

$::port = int( rand() * 10000 ) until $::port && $::port > 1024;

ok(
  my $server = Event::Lite::Server->new(
    address => '127.0.0.1',
    port    => $::port,
  ),
  'server.new'
);

$server->run();


my $subs = Event::Lite::Subscriber->new(
  address => '127.0.0.1',
  port    => $::port,
);
my $subs2 = Event::Lite::Subscriber->new(
  address => '127.0.0.1',
  port    => $::port,
);

my ($count, $max_events) = ( 0, 1_000 );
{
  sub handle_event {
    my $evt = shift;
    $count++;
    $::SUBSCRIBER->{running} = 0
      if $evt->{num} == $max_events;
  }
}
$subs->subscribe(
  event => 'test.event',
  callback  => \&handle_event,
);
$subs2->subscribe(
  event => 'test.event',
  callback  => \&handle_event,
);


my $pub = Event::Lite::Publisher->new(
  address => '127.0.0.1',
  port    => $::port,
);

my $start = gettimeofday();
$pub->publish(
  event => 'test.event',
  num   => $_
) for 1..$max_events;
do{ usleep(1_000) } while grep { $_->running } ( $subs, $subs2 );
my $diff = gettimeofday() - $start;
my $rate = $max_events / $diff;
warn "\n\t@{[ $max_events ]} handled in $diff seconds: rate = $rate/second\n";

sleep(2);
$pub->stop();

$subs->stop();
$subs2->stop();

$server->stop();

