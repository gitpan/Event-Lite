#!/usr/bin/perl -w

use strict;
use warnings 'all';
use Test::More 'no_plan';

use Event::Lite::Server;
use Event::Lite;
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

Event::Lite->server( "127.0.0.1:$::port" );


#my %events : shared = ( );
my %events = ( );

my $max_listeners = 1;
my $max_events    = 1000;
my @subs          = ( );

for my $h ( 1..$max_listeners )
{
  push @subs, addEventListener(
    event     => 'test-event',
    callback  => sub {
      my $evt = shift;
      my $name = "h$h" . "e$evt->{number}";
      $::SUBSCRIBER->stop if $evt->{number} == $max_events;
#      warn "$name\n";
    },
  );
}# end for()

#warn "\n\tDispatching events...\n";

my $start = gettimeofday();
for( 1..$max_events )
{
  dispatchEvent(
    event   => 'test-event',
    number  => $_,
  );
}# end for()

#warn "\n\tWaiting for events to finish...\n";
map { $_->stop } @subs;
while( grep { $_->running } @subs )
{
  warn "Waiting...\n";
  usleep( 1_000 );
}# end while()
my $diff = gettimeofday() - $start;
my $persec = ( $max_listeners * $max_events ) / $diff;
warn "\n\t" . ( $max_listeners * $max_events ) . " events at a rate of $persec/second\n";

sleep(3);
$server->stop();



