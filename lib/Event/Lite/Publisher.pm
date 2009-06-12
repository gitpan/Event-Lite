
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
  
  my $sock = Socket::Class->new(
    remote_addr => $args{address},
    remote_port => $args{port},
    proto       => 'tcp',
  ) or die "Cannot connect: $!";
  sleep(2);
  return bless {
    %args,
    sock        => $sock,
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
  sleep(2) unless $s->{initialized}++;
  $s->{sock}->send($msg, 0x8);
  my $buffer;
  my $got = $s->{sock}->read($buffer, 1024 ** 2 );
  if( $buffer ne 'ok' )
  {
    warn "Unexpected response '$buffer' from server";
  }# end if()
}# end publish()


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

