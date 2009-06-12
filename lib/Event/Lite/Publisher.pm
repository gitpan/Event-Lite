
package Event::Lite::Publisher;

use strict;
use warnings 'all';
#use Carp 'confess';
use Socket::Class;
use JSON::XS;
#use Storable qw( freeze );
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
    $s->reconnect()
      or die "Cannot reconnect!";
  }# end unless()
  
  $s->{sock}->send($msg, 0x8);
  my $buffer;
  
  TRY: {
    my $got = $s->{sock}->read($buffer, 1024 ** 2 );
    unless( defined $got )
    {
      return;
#      warn "Disconnecting";
#      eval { $s->{sock}->close };
#      last TRY;
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
  ) or die "Cannot connect to $s->{address}:$s->{port}: $!";
}# end reconnect()


#==============================================================================
sub stop
{
  my $s = shift;
  
  $s->{sock}->close();
}# end stop()


#==============================================================================
sub DESTROY
{
  my $s = shift;
  
  eval { $s->stop() };
  undef(%$s);
}# end DESTROY()

1;# return true:

