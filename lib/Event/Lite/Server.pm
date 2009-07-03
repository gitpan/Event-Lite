
package Event::Lite::Server;

use strict;
use warnings 'all';
use IO::Socket::INET;
use IO::Select;
use forks;
use forks::shared;
use Time::HiRes 'usleep';

our $RUNNING : shared = 1;
our %subscribers = ( );


#==============================================================================
sub new
{
  my ($class, %args) = @_;
  
  foreach(qw( address port ))
  {
    die "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  $args{on_authenticate_subscriber} ||= sub { 1 };
  $args{on_authenticate_publisher}  ||= sub { 1 };
  
  return bless \%args, $class;
}# end new()


#==============================================================================
sub run
{
  my $s = shift;
  
  $s->{worker} = threads->create(sub {eval{
    my $server = IO::Socket::INET->new(
      LocalAddr => $s->{address},
      LocalPort => $s->{port},
      Proto     => 'tcp',
      Listen    => SOMAXCONN, # The maximum allowed by law.
      Reuse     => 1,
    ) or die "Cannot create listening socket at $s->{address}:$s->{port}: $!";
    
    my $read_set = IO::Select->new();
    $read_set->add( $server );
    LOOP: while( $RUNNING ) {
      my ($readable_handles) = IO::Select->select($read_set, undef, undef, 0.25);
      HANDLE: foreach my $rh ( @$readable_handles )
      {
        if( $rh == $server )
        {
          # New socket:
          $read_set->add( $rh->accept() );
        }# end if()
        
        SCOPE:{
          # Message from existing socket:
          my $buffer;
          $rh->recv($buffer, 1024 ** 2);
          if( defined($buffer) )
          {
            unless( length($buffer) )
            {
              usleep( 10000 );
              next HANDLE;
            }# end unless()
            
            # Got input:            
            # Now handle the message:
            my ($type) = $buffer =~ m{^(\w+)/};
            if( $type eq 'subscribe' )
            {
              # Remember the handle for later:
              my ($event_type, $credentials) = $buffer =~ m{^.*?/(.*?):(.*)$};
              chomp($credentials);
              my ($username, $password) = split /\|/, $credentials;
              if( $s->check_subscriber_credentials( $rh, $event_type, $username, $password ) )
              {
                $s->handle_subscribe( $rh, $event_type );
              }
              else
              {
                $s->deny_subscriber( $rh, $event_type, $username, $password );
                next HANDLE;
              }# end if()
            }
            elsif( $type eq 'publish' )
            {
              my ($event_type,$credentials) = $buffer =~ m{^.*?/(.*?):([^\r\n]+)};
              chomp($credentials);
              my ($username, $password) = split /\|/, $credentials;
              if( $s->check_publisher_credentials( $rh, $event_type, $username, $password ) )
              {
                $s->publish_event( $rh, $buffer, $read_set );
              }
              else
              {
                $s->deny_publisher( $rh, $event_type, $username, $password );
                next HANDLE;
              }# end if()
            }
            else
            {
              warn "Unknown message type: '$type'";
            }# end if()
          }
          else
          {
            # Dead handle:
            $read_set->remove( $rh );
            close($rh);
          }# end if()
        };
      }# end foreach()
      
    }# end while()
  }; warn $@ if $@;});
  
  sleep(1);
}# end run()


#==============================================================================
sub handle_subscribe
{
  my ($s, $handle, $event_type) = @_;
  
  $subscribers{$event_type} ||= [ ];
  push @{$subscribers{$event_type}}, $handle;
  
  $handle->send('ok');
}# end handle_subscribe()


#==============================================================================
sub check_publisher_credentials
{
  my ($s, $socket, $event_type, $username, $password) = @_;
  
  return $s->{on_authenticate_publisher}->( $socket, $event_type, $username, $password );
}# end check_publisher_credentials()


#==============================================================================
sub deny_publisher
{
  my ($s, $socket, $event_type, $username, $password) = @_;
  
  $socket->send( 'permission denied' );
  
  return 1;
}# end deny_publisher()


#==============================================================================
sub check_subscriber_credentials
{
  my ($s, $socket, $event_type, $username, $password) = @_;
  
  return $s->{on_authenticate_subscriber}->( $socket, $event_type, $username, $password );
}# end check_subscriber_credentials()


#==============================================================================
sub deny_subscriber
{
  my ($s, $socket, $event_type, $username, $password) = @_;
  
  $socket->send( 'permission denied' );
  return 1;
}# end deny_subscriber()


#==============================================================================
sub publish_event
{
  my ($s, $socket, $buffer, $read_set) = @_;
  
  $socket->send( 'ok' );
  
  # Tell all the subscribers that their event has happened:
  my ($header, @body) = split /\n\n/, $buffer;
  my (undef, $event_type) = split /\//, $header;
  ($event_type) = split /:/, $event_type;
  chomp($event_type);
  my @writable = $read_set->can_write();
  my %can_write = map { $_ => 1 } @writable;
  my $body = join "\n\n", @body;
  foreach my $subs ( @{$subscribers{$event_type}} )
  {
    next unless grep { $_ eq $subs } keys %can_write;
    $subs->send( "$body\n\n" );
  }# end foreach()  
}# end publish_event()


#==============================================================================
sub stop
{
  my $s = shift;
  
  SCOPE: {
    lock($RUNNING);
    $RUNNING = 0;
  };
  eval { $s->{worker}->join };
}# end stop()


#==============================================================================
sub running { {lock($RUNNING); return $RUNNING } }


#==============================================================================
sub DESTROY
{
  my $s = shift;
  
  eval { $s->stop } if $s->{worker};
  undef(%$s);
}# end DESTROY()

1;# return true:

=pod

=head1 NAME

Event::Lite::Server - Event dispatch server

=head1 SYNOPSIS

=head2 Basic Server

  use Event::Lite::Server;
  
  my $server = Event::Lite::Server->new(
    address => '127.0.0.1',
    port    => 34343,
  );
  $server->run();
  
  # Do stuff...
  think();
  
  # Or even:
  $SIG{TERM} = $SIG{INT} = sub {
    $server->stop();
  };
  
  #Finally:
  $server->stop();

=head2 More Secure Server

  use Event::Lite::Server;
  
  my $server = Event::Lite::Server->new(
    address                     => '127.0.0.1',
    port                        => 34343,
    on_authenticate_subscriber  => \&check_subscriber,
    on_authenticate_publisher   => \&check_publisher,
  );
  $server->run();
  
  # Do stuff...
  think();
  
  # Or even:
  $SIG{TERM} = $SIG{INT} = sub {
    $server->stop();
  };
  
  #Finally:
  $server->stop();
  
  sub check_subscriber {
    my ($socket, $event_type, $username, $password) = @_;
    
    # Return a true value to authorize:
    if( $username eq 'admin' && $password eq 'swordfish' )
    {
      # Permission granted:
      return 1;
    }
    else
    {
      # Permission denied:
      return 0;
    }# end if()
  }
  
  sub check_publisher {
    my ($socket, $event_type, $username, $password) = @_;
    
    # Return a true value to authorize:
    if( $username eq 'admin' && $password eq 'swordfish' )
    {
      # Permission granted:
      return 1;
    }
    else
    {
      # Permission denied:
      return 0;
    }# end if()
  }

=head1 DESCRIPTION

C<Event::Lite::Server> does only one thing: Dispatch events from "publishers"
to "subscribers" - nothing more, nothing less.

The other details (i.e. security) are left up to you, the user.

=head1 TECH SPECS

=head2 Performance

Depending on the size of the event, the number of subscribers and network latency,
performance could range anywhere from 100 to 1,000 events per second.  YMMV.

"Patches Welcome"

=head2 Protocol

C<Event::Lite> uses a simple text-based protocol.  The event body is base64-encoded
JSON.  Internaly, L<JSON::XS> is used to encode and decode the data.

=head3 Subscribe

A subscribe request looks like this:

  subscribe/event-name:username|password

So, to subscribe to events named "foo" you would send:

  subscribe/foo:admin|swordfish

=head3 Publish

A publish request looks like this:

  publish/event-name:username|password
  
  <base64-encoded JSON>

So, to publish an event named "foo" you would send:

  publish/foo:admin|swordfish
  
  AB384dsd93jk4j2h3g4jh23g4jh2g34jhg234jhg23jh4g==

=head3 Receiving an Event

When a subscriber receives an event that it has subscribed to, that event is just
the base64-encoded JSON.

  AB384dsd93jk4j2h3g4jh23g4jh2g34jhg234jhg23jh4g==

Decoding it and parsing the resulting JSON will result in the event object itself.

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

