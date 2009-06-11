
package Event::Lite::Publisher;

use strict;
use warnings 'all';
use Carp 'confess';
use Socket::Class;
use Storable qw( freeze );
use MIME::Base64;



#==============================================================================
sub new
{
  my ($class, %args) = @_;
  
  foreach(qw( address port ))
  {
    confess "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  my $sock = Socket::Class->new(
    remote_addr => $args{address},
    remote_port => $args{port},
    proto       => 'tcp',
  ) or die "Cannot connect: $!";
  return bless { %args, sock => $sock }, $class;
}# end new()


#==============================================================================
sub publish
{
  my ($s, %args) = @_;
  
  foreach(qw( event ))
  {
    confess "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  my $data = encode_base64( freeze( \%args ) );
  $s->{sock}->send("publish/$args{event}\n\n$data");
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

1;# return true:

