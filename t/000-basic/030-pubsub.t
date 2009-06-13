#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';
use Time::HiRes qw( gettimeofday usleep );


use Event::Lite::Server;
use Event::Lite::Publisher;
use Event::Lite::Subscriber;

$::port = int( rand() * 10000 ) until $::port && $::port > 1024;

#use forks::shared;

my $server = Event::Lite::Server->new(
  address => '127.0.0.1',
  port    => $::port,
);

my %events = ( );

$server->run();

my @subs = ( );
my $max_subscribers = 10;
for my $subs ( 1..$max_subscribers )
{
  my $subscriber = Event::Lite::Subscriber->new(
    address => '127.0.0.1',
    port    => $::port,
  );
  $subscriber->subscribe(
    event => 'test-event',
    callback  => sub {
      my $evt = shift;
      print STDERR ".";
      my $name = "h$subs:e$evt->{number}";
#      warn "$$: Subscriber #$subs was notified of $evt->{event}: ($evt->{number})\n"
    }
  );
  push @subs, $subscriber;
}# end for()

my $publisher = Event::Lite::Publisher->new(
  address => '127.0.0.1',
  port    => $::port,
);

my $max = 5;
$publisher->publish(
  event => 'test-event',
  number  => $_,
) for 1..$max;

while( grep { $_->running } @subs )
{
  usleep( 1_000 );
}# end while()

ok(1);

$_->stop() foreach @subs;
$publisher->stop();
$server->stop();

