#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';
use Time::HiRes 'gettimeofday';

use_ok('Event::Lite::Server');
use_ok('Event::Lite::Publisher');
use_ok('Event::Lite::Subscriber');

my $server = Event::Lite::Server->new(
  address => '127.0.0.1',
  port    => 34343,
);

$server->run();
sleep(1);

my @subs = ( );
my $max_subscribers = 10;
for( 1..$max_subscribers )
{
  my $subscriber = Event::Lite::Subscriber->new(
    address => '127.0.0.1',
    port    => 34343,
  );
  $subscriber->subscribe(
    event => 'test-event',
    callback  => sub {
      my $evt = shift;
#      warn "Subscriber #$_ was notified of $evt->{event}: ($evt->{number})\n"
#      warn "#$_:$evt->{event}:$evt->{number}\n";
    }
  );
  push @subs, $subscriber;
}# end for()
sleep(1);

my $publisher = Event::Lite::Publisher->new(
  address => '127.0.0.1',
  port    => 34343,
);
sleep(1);

my $start = gettimeofday();
my $max = 5_000;
$publisher->publish(
  event => 'test-event',
  number  => $_,
) for 1..$max;

my $diff = gettimeofday() - $start;
my $each = $max / $diff;
warn "\n=========== BENCHMARK ==================\n";
warn "\tBroadcast $max events to $max_subscribers subscribers in $diff seconds ($each/sec)\n";
warn "\n=========== /BENCHMARK ==================\n";

sleep(5);

$_->stop() foreach @subs;
$publisher->stop();
$server->stop();

