
package Event::Lite::Publisher;

use strict;
use warnings 'all';
use Socket::Class;
use JSON::XS;
use MIME::Base64;



#==============================================================================
sub new
{
  my ($class, %args) = @_;
  
  foreach(qw( address port ))
  {
    die "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  my $credentials = '|';
  if( $args{username} && $args{password} )
  {
    $credentials = join '|', ( $args{username}, $args{password} );
  }# end if()
  
  return bless {
    %args,
    initialized => 0,
    json        => JSON::XS->new->utf8->pretty,
    credentials => $credentials,
  }, $class;
}# end new()


#==============================================================================
sub publish
{
  my ($s, %args) = @_;
  
  foreach(qw( event ))
  {
    die "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  my $data = encode_base64( $s->{json}->encode( \%args ) );
  my $msg = "publish/$args{event}:$s->{credentials}\n\n$data";

  unless( eval { $s->{sock} && $s->{sock}->remote_addr } )
  {
    $s->reconnect() or return;
  }# end unless()
  
  $s->{sock}->send($msg, 0x8);
  my $buffer;
  
  TRY: {
    my $got = $s->{sock}->read($buffer, 1024 ** 2 );
    unless( defined $got )
    {
      return;
    }# end unless()
    unless( $got )
    {
      $s->{sock}->wait( 50 );
      next TRY;
    }# end unless()
    
    if( $buffer ne 'ok' )
    {
      warn "Unexpected response '$buffer' from server";
    }# end if()
  }# end TRY
}# end publish()


#==============================================================================
sub reconnect
{
  my $s = shift;
  
  eval { $s->{sock}->close() };
  $s->{sock} = Socket::Class->new(
    remote_addr => $s->{address},
    remote_port => $s->{port},
    proto       => 'tcp',
  );
}# end reconnect()


#==============================================================================
sub stop
{
  my $s = shift;
  
  eval { $s->{sock}->close() } if $s->{sock};
}# end stop()


#==============================================================================
sub DESTROY
{
  my $s = shift;
  
  eval { $s->stop() };
  undef(%$s);
}# end DESTROY()

1;# return true:

=pod

=head1 NAME

Event::Lite::Publisher - Send events to listeners

=head1 SYNOPSIS

  use Event::Lite::Publisher;
  
  my $publisher = Event::Lite::Publisher->new(
    address => 'server.address.com',
    port    => 34343,
    
    # The username/password are only necessary if required by the event server:
    username  => 'admin',
    password  => 'swordfish',
  );
  
  $publisher->publish(
    event => 'the.event.name.here',
    
    # Anything else is just passed along:
    foo           => 'bar',
    some_numbers  => [ 1..10 ],
    a_hash        => { hello => 'world' },
    nested        => {
      even  => [ 2, 4, 6, 8 ],
      odd   => [ 1, 3, 5, 7 ],
      more  => [ ['a','b'], { a => 'word' } ],
    },
  );
  
  # Not ok:
  $publisher->publish(
    event       => 'event-name-here',
    object      => CGI->new(),  # No
    filehandle  => $ofh,        # No
    db_handle   => $dbh,        # No
    socket      => $sock,       # No
  );
  
  # Works, but is not recommended:
  $publisher->publish(
    event => 'war-and-peace',
    text  => "It was the best of times, it was the worst of times\n"x1_000_000
  );
  
  # When you tire of publishing:
  $publisher->stop();

=head1 DESCRIPTION

C<Event::Lite::Publisher> connects to an L<Event::Lite::Server> and sends your
events to it.

Operative word here is B<events>, not B<huge chunks of data>.  While it is possible
to send enourmous chunks of data, it's not recommended.  Performance will degrade.

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

