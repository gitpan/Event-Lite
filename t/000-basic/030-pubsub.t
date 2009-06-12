#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';
use Time::HiRes qw( gettimeofday usleep );


use Event::Lite::Server;
use Event::Lite::Publisher;
use Event::Lite::Subscriber;

use forks::shared;

my $server = Event::Lite::Server->new(
  address => '127.0.0.1',
  port    => 34343,
);

my %events : shared = ( );

$server->run();

my @subs = ( );
my $max_subscribers = 10;
for my $subs ( 1..$max_subscribers )
{
  my $subscriber = Event::Lite::Subscriber->new(
    address => '127.0.0.1',
    port    => 34343,
  );
  $subscriber->subscribe(
    event => 'test-event',
    callback  => sub {
      my $evt = shift;
      print STDERR ".";
      my $name = "h$subs:e$evt->{number}";
      lock(%events);
      $events{$name}++;
#      warn "Subscriber #$subs was notified of $evt->{event}: ($evt->{number})\n"
#      warn "#$_:$evt->{event}:$evt->{number}\n";
    }
  );
  push @subs, $subscriber;
}# end for()

my $publisher = Event::Lite::Publisher->new(
  address => '127.0.0.1',
  port    => 34343,
);

#my $start = gettimeofday();
my $max = 50;
$publisher->publish(
  event => 'test-event',
  number  => $_,
) for 1..$max;

while( scalar(keys(%events)) < ( $max * $max_subscribers ) )
{
#  warn "Waiting..." . scalar(keys(%events));
  usleep(10_000);
}# end while()


#my $diff = gettimeofday() - $start;
#my $each = $max / $diff;
#warn "\n=========== BENCHMARK ==================\n";
#warn "\tBroadcasted $max events to $max_subscribers subscribers in $diff seconds ($each/sec)\n";
#warn "\n=========== /BENCHMARK ==================\n";

for my $subs ( 1..$max_subscribers )
{
  for my $ev ( 1..$max )
  {
    my $name = "h$subs:e$ev";
    ok($events{$name}, $name);
  }# end for()
}# end for()

$_->stop() foreach @subs;
$publisher->stop();
$server->stop();

