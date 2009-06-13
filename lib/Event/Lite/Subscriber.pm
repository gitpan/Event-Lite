
package Event::Lite::Subscriber;

use strict;
use warnings 'all';
use Socket::Class;
use JSON::XS;
use MIME::Base64;
use Time::HiRes qw( ualarm usleep );

sub reaper {
warn "Reaper...";
  my $waitpid = wait;
warn "$$: waitpid:$waitpid";
  $SIG{CHLD} = \&reaper;
}
$SIG{CHLD} = 'IGNORE';


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
  
  LOOP: while( 1 )
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
          $s->{callback}->( $s->{json}->decode( decode_base64( $msg ) ) );
        }# end foreach()
      }# end if()
    }# end if()
  }# end while()
}# end child_loop()


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

