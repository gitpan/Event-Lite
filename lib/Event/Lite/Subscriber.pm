
package Event::Lite::Subscriber;

use strict;
use warnings 'all';
use Socket::Class;
use JSON::XS;
use MIME::Base64;
use Time::HiRes qw( ualarm usleep );

# If you have a better idea, please let me know:
local $SIG{CHLD} = 'IGNORE';


#==============================================================================
sub new
{
  my ($class, %args) = @_;
  
  foreach(qw( address port ))
  {
    die "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  $args{json} = JSON::XS->new->utf8->pretty;
  return bless \%args, $class;
}# end new()


#==============================================================================
sub subscribe
{
  my ($s, %args) = @_;
  
  foreach(qw( event callback ))
  {
    die "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  map { $s->{$_} = $args{$_} } keys %args;
  
  if( my $pid = open( my $child, "|-") )
  {
    # Parent process - write to child:
    $s->{child} = $child;
    $s->{running} = 1;
    return;
  }
  else
  {
    # Child process - read from parent:
    die "cannot fork: $!" unless defined $pid;
    $s->child_loop();
    exit;
  }# end if()
}# end subscribe()


#==============================================================================
sub child_loop
{
  my $s = shift;

  my $credentials = '|';
  if( $s->{username} && $s->{password} )
  {
    $credentials = join '|', ( $s->{username}, $s->{password} );
  }# end if()
  
  LOOP: while( $s->{running} )
  {
    eval {
      $s->{sock} = $s->connect( $s->{event}, $credentials )
        unless $s->{sock} && $s->{sock}->remote_addr();
    };
    if( $@ )
    {
      warn $@;
      last LOOP;
    }# end if()

    my $buffer;
    my $got = $s->{sock}->read( $buffer, 1024 ** 2 );
    if( ! defined($got) )
    {
      # We are disconnected:
      last;
    }
    elsif( ! $got )
    {
      # No input yet - just wait:
      $s->{sock}->wait( 50 );
      next;
    }
    else
    {
      chomp($buffer);
      if( $buffer eq 'ok' )
      {
        # Yay - connected and authenticated.
      }
      elsif( $buffer eq 'permission denied' )
      {
        # Denied access:
        warn "Permission denied";
        last LOOP;
      }
      else
      {
        foreach my $msg ( grep { $_ } split /\n\n/, $buffer )
        {
          $s->call_callback( $s->{callback}, $s->{json}->decode( decode_base64( $msg ) ) );
        }# end foreach()
      }# end if()
    }# end if()
  }# end while()
}# end child_loop()


#==============================================================================
sub call_callback
{
  my ($s, $callback, $event) = @_;
  
  local $::SUBSCRIBER = $s;
  $callback->( $event );
}# end call_callback()


#==============================================================================
sub running
{
  my $s = shift;
  
  return unless $s->{child};
  return kill( 0 => $s->{child} );
}# end running()


#==============================================================================
sub stop
{
  my $s = shift;
  
  return unless $s->{child};
  kill( SIGTERM => $s->{child} );
}# end stop()


#==============================================================================
sub connect
{
  my ($s, $event, $credentials) = @_;

  my $sock = Socket::Class->new(
    remote_addr => $s->{address},
    remote_port => $s->{port},
    proto       => 'tcp',
  ) or die "Cannot connect: $!";
  $sock->send("subscribe/$event:$credentials");
  
  return $sock;
}# end connect()


#==============================================================================
sub DESTROY
{
  my $s = shift;
  $s->stop;
  undef(%$s);
}# end DESTROY()

1;# return true:

=pod

=head1 NAME

Event::Lite::Subscriber - Event listener with callback

=head1 SYNOPSIS

  use Event::Lite::Subscriber;
  
  my $subscriber = Event::Lite::Subscriber->new(
    address => 'your.server.com',
    port    => 34343,
  );
  
  $subscriber->subscribe(
    event     => 'name_of_the_event_to_subscribe_to',
    callback  => sub {
      my $event = shift;
      # This code is executed in a separate process.
      warn "The event named '$event->{event}' has happened";
    },
    
    # The username/password are only necessary if your server requires them:
    username  => 'admin',
    password  => 'swordfish',
  );
  
  # Do stuff...
  calculate_pi() while 1;
  
  # Finally:
  $subscriber->stop();

=head1 DESCRIPTION

C<Event::Lite::Subscriber> provides low-level (yet simple) access to events that
are broadcast by an L<Event::Lite::Publisher> through a L<Event::Lite::Server>.

B<NOTE:> The subscriber object runs its event loop in a separate process.  That means your
callback code won't have any effect over variables in the parent process.  You
also cannot share database handles, open sockets or file handles between the
parent process and your callback code.

If this is a limitation you just can't deal with, check out L<Event::Lite::Subscriber::NoFork>
because it does not have the same issue (because it does not fork).

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

