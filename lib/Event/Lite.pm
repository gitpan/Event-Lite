
package Event::Lite;

use strict;
use warnings 'all';
use base 'Exporter';
use Event::Lite::Subscriber;
use Event::Lite::Publisher;
our $VERSION = '1.010';
our @EXPORT = qw( addEventListener dispatchEvent );

my $publisher;
my $server_address;
my $server_port;
my $username;
my $password;
my @subscribers = ( );

my $instance;

#==============================================================================
sub server
{
  my ($class, $server, $user, $pass) = @_;
  
  my ($addr,$port) = split /:/, $server;
  warn "Usage: $class\->server( 'hostname:port' [, username, password ] )"
    unless $addr && $port;
  $username = $user;
  $password = $pass;
  
  if( $publisher )
  {
    eval {
      $publisher->stop();
      undef($publisher);
    };
  }# end if()
  
  $server_address = $addr;
  $server_port    = $port;
  
  $instance = bless {subs => [ ]}, $class;
}# end server()


#==============================================================================
sub addEventListener
{
  my %args = @_;
  
  $args{event} && ( ref($args{callback}) eq 'CODE' )
    or die "Usage: addEventListener( event => 'event-name', callback => sub {...} )";
  
  my $sub = Event::Lite::Subscriber->new(
    address   => $server_address,
    port      => $server_port,
    username  => $username,
    password  => $password,
  );
  $sub->subscribe(
    event     => $args{event},
    callback  => $args{callback},
  );
  push @{$instance->{subs}}, $sub;
  return $sub;
}# end addEventListener()


#==============================================================================
sub dispatchEvent
{
  my %args = @_;
  
  $args{event} or die "Usage: dispatchEvent( event => 'event-name, [ \%other_args ] )";
  
  $publisher ||= Event::Lite::Publisher->new(
    address   => $server_address,
    port      => $server_port,
    username  => $username,
    password  => $password,
  );
  $publisher->publish(
    %args
  );
}# end dispatchEvent()


#==============================================================================
sub DESTROY
{
  my $s = shift;
  map { eval { $_->DESTROY } } @{$s->{subs}};
  $publisher->stop
    if $publisher;
  undef(%$s);
}# end DESTROY()


1;# return true:

=pod

=head1 NAME

Event::Lite - Distributed Event Broadcast System for Perl

=head1 SYNOPSIS

B<NOTE:> - The synopses are subject to drastic change, as this code is still alpha.

B<WARNING:> - More extensive testing is still underway.  For example, repeated
subscribe/disconnect scenarios have not been thoroughly tested yet.

=head2 Server

  use Event::Lite::Server;
  
  my $server = Event::Lite::Server->new(
    # Required params:
    address => '127.0.0.1',
    port    => 34343,
    
    # Optional params:
    on_authenticate_publisher => sub {
      my ($socket, $event_type, $username, $password) = @_;
      
      # If the publisher is ok, then return true:
      return 1;
    },
    on_authenticate_subscriber => sub {
      my ($socket, $event_type, $username, $password) = @_;
      
      # If the subscriber is ok, then return true:
      return 1;
    },
  );
  
  # Install some signal handlers:
  $SIG{INT} = $SIG{TERM} = sub {
    return unless $server->running;
    warn "Shutting down...\n";
    $server->stop();
  };
  
  $SIG{HUP} = sub {
    warn "Restarting server on port $port...\n";
    $server->stop();
    $server->run();
  };
  
  warn "Starting server on port $port...\n";
  
  $server->run();
  
  sleep(1) while 1;
  
  # Fell out of loop:
  $server->stop();

=head2 Subscribing to Events

  # Import the addEventListener and dispatchEvent functions:
  use Event::Lite;
  
  # Just tell Event::Lite where the server is:
  Event::Lite->server( '127.0.0.1:34343', 'username', 'password' );
  
  addEventListener(
    event     => 'foo',
    callback  => sub { 
      my $event = shift;
      warn "$event->{event} happened: $event->{bar}"; # 'foo happened: Hello World'
    }
  );

=head2 Publishing Events

  # Import the addEventListener and dispatchEvent functions:
  use Event::Lite;
  
  # Just tell Event::Lite where the server is:
  Event::Lite->server( '127.0.0.1:34343', 'username', 'password' );
  
  # Then, someplace else, in the same program, different program, same machine or different machine:
  dispatchEvent(
    event => 'foo',
    bar   => 'Hello World'.
  );

=head1 DESCRIPTION

C<Event::Lite> aims to provide a distributed event broadcast system for Perl.

This means that an event (i.e. Price of Tea in China (PTC) changes) can occur
in one system, and any number of "subscriber" systems can be instantly notified,
regardless of whether they are on the same system or network (or even written in Perl).

Since sending and receiving events requires only sockets, base64-encoding/decoding and JSON,
C<Event::Lite> is language-agnostic.

=head2 Architecture

C<Event::Lite> basically has 4 components:

=over 4

=item * Server

The part responsible for connecting subscribers and publishers.

=item * Publisher

The where events are generated.

=item * Subscriber

Something that cares about a specific kind of event.  It can expect the server
to let it know when that kind of event happens.

=item * Event

An object that describes the Who, What, When, Where, Why and How of what happened.

Events are just simple hashrefs - not even blessed.  Do not attempt to pass blessed
objects, filehandles, sockets or database connections inside of the event.

=back

=head1 PERFORMANCE

Depending on the size of the event, the number of subscribers and network latency,
performance could range anywhere from 100 to 1,000 events per second.  YMMV.

=head1 BEST PRACTICES

=head2 Use Small Events

Try to keep your events - when serialized - less than 1024**2 bytes.

=head2 Send Events, Not Data

Event::Lite B<is intended for> near-real-time message broadcasts, B<not multicast of large datasets>.

=head2 Security

By default, all events go over the wire encoded, but not encrypted.  Don't send sensitive data
within the arguments of an event.

=head1 AUTHENTICATION

You can grant or deny access to publishers and subscribers.

The two authenticated types - publishers and subscribers - can be authenticated
separately.  Authentication can be based on the username, password and event type.

=head2 Authenticating Publishers and Subscribers

When the Server is instantiated, one of the optional arguments is C<on_authenticate_publisher> which
whould be a code reference.

An example of how to do this is as follows:

  my $server = Event::Lite::Server->new(
    address => '127.0.0.1',
    port    => '34343',
    on_authenticate_publisher   => \&authenticate_publisher,
    on_authenticate_subscriber  => \&authenticate_subscriber,
  );
  
  # Authenticate a publisher:
  sub authenticate_publisher {
    my ($socket, $event_type, $username, $password) = @_;
    
    if( is authenticated ) {
      return 1;
    }
    else {
      return 0;
    }
  }
  
  # Authenticate a subscriber:
  sub authenticate_subscriber {
    my ($socket, $event_type, $username, $password) = @_;
    
    if( is authenticated ) {
      return 1;
    }
    else {
      return 0;
    }
  }

Once the server is configured as shown above, publishers and subscribers will always be authenticated.

=head1 PUBLIC METHODS

=head2 Event::Lite->server( address:port, [username, password ])

See synopsis for usage examples.

Defines the connection to the event server.

=head1 EXPORTED FUNCTIONS

=head2 addEventListener( event => event_name, callback => sub {...} )

See the synopsis for usage examples.

B<NOTE:> The callback will be executed in a B<separate thread or process> and may not have
access to variables in the local context.

Using L<forks::shared> to share variables will get around this limitation.

=head2 dispatchEvent( event => event_name, %misc_args )

The only required parameter is C<event>.

Any other parameters in the hash will be sent just as they are.

B<NOTE:> - Sending of blessed objects, sockets or file handles is not supported.

=head1 SUPPORT

Visit L<http://www.devstack.com/contact/> or email the author at <jdrago_999@yahoo.com>

Commercial support and installation is available.

=head1 AUTHOR

John Drago <jdrago_999@yahoo.com>
 
=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008 by John Drago

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

