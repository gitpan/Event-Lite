
package Event::Lite::Subscriber;

use strict;
use warnings 'all';
#use Carp 'confess';
use Socket::Class;
use forks;
use forks::shared;
#use Storable 'thaw';
use JSON::XS;
use MIME::Base64;

our $SUBSCRIBED : shared = 1;


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
  
  my $credentials = '|';
  if( $s->{username} && $s->{password} )
  {
    $credentials = join '|', ( $s->{username}, $s->{password} );
  }# end if()
  
  $s->{worker} = threads->create(sub {
    my $sock = Socket::Class->new(
      remote_addr => $s->{address},
      remote_port => $s->{port},
      proto       => 'tcp',
    ) or die "Cannot connect: $!";
    $sock->send("subscribe/$args{event}:$credentials");
    
    LOOP: while( 1 ) {
      last unless $SUBSCRIBED;
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
        if( $buffer eq 'ok' )
        {
          # Yay - connected and authenticated.
        }
        elsif( $buffer eq 'permission denied' )
        {
          # Denied access:
          warn "Permission denied";
          lock($SUBSCRIBED);
          $SUBSCRIBED = 0;
          last LOOP;
        }
        else
        {
          foreach my $msg ( grep { $_ } split /\n\n/, $buffer )
          {
            $args{callback}->( $s->{json}->decode( decode_base64( $msg ) ) );
          }# end foreach()
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


#==============================================================================
sub DESTROY
{
  my $s = shift;
  eval { $s->stop() } if $s->{worker};
  undef(%$s);
}# end DESTROY()

1;# return true:

