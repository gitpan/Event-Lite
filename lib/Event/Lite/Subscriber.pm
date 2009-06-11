
package Event::Lite::Subscriber;

use strict;
use warnings 'all';
use Carp 'confess';
use Socket::Class;
use forks;
use forks::shared;
use Storable 'thaw';
use MIME::Base64;

our $SUBSCRIBED : shared = 1;


#==============================================================================
sub new
{
  my ($class, %args) = @_;
  
  foreach(qw( address port ))
  {
    confess "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  return bless \%args, $class;
}# end new()


#==============================================================================
sub subscribe
{
  my ($s, %args) = @_;
  
  foreach(qw( event callback ))
  {
    confess "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  $s->{worker} = threads->create(sub {
    my $sock = Socket::Class->new(
      remote_addr => $s->{address},
      remote_port => $s->{port},
      proto       => 'tcp',
    ) or die "Cannot connect: $!";
    $sock->send("subscribe/$args{event}");
    
    while( 1 ) {
      last unless $SUBSCRIBED;
#warn "Running: [$SUBSCRIBED]";
      my $buffer;
      my $got = $sock->read( $buffer, 1024 ** 2 );
      if( ! defined($got) )
      {
        # We are disconnected:
        $SUBSCRIBED = 0;
        last;
      }
      elsif( ! $got )
      {
        # No input yet - just wait:
        $sock->wait( 50 );
        next;
      }
      else
      {
        chomp($buffer);
#        warn "Received $got bytes: [[$buffer]]";
        if( $buffer ne 'ok' )
        {
          $args{callback}->( thaw( decode_base64( $buffer ) ) );
        }# end if()
      }# end if()
    }# end while()
  });
}# end subscribe()


#==============================================================================
sub stop
{
  my $s = shift;
  
  $SUBSCRIBED = 0;
  $s->{worker}->detach;
}# end stop()

1;# return true:

