
package Event::Lite::Server;

use strict;
use warnings 'all';
use Carp 'confess';
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
    confess "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
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
    while( $RUNNING ) {
      my ($readable_handles) = IO::Select->select($read_set, undef, undef, 0.25);
      unless( $readable_handles )
      {
        usleep( 10000 );
        next;
      }# end unless()
      foreach my $rh ( @$readable_handles )
      {
        if( $rh == $server )
        {
          # New socket:
          $read_set->add( $rh->accept() );
        }
        else
        {
          # Message from existing socket:
          my $buffer;
          $rh->recv($buffer, 1024 ** 2);
          if( defined($buffer) )
          {
            unless( length($buffer) )
            {
              next;
            }# end unless()
            
            # Got input:
#            warn "Received [[$buffer]]";
            $rh->send('ok');
            
            # Now handle the message:
            my ($type) = $buffer =~ m{^(\w+)/};
            if( $type eq 'subscribe' )
            {
              # Remember the handle for later:
              my (undef, $event_type) = split /\//, $buffer;
              chomp($event_type);
              handle_subscribe( $rh, $event_type );
            }
            elsif( $type eq 'publish' )
            {
              # Tell all the subscribers that their event has happened:
              my ($header, $body) = split /\n\n/, $buffer;
              my (undef, $event_type) = split /\//, $header;
              chomp($event_type);
              my @writable = $read_set->can_write();
              my %can_write = map { $_ => 1 } @writable;
#use Data::Dumper;
#warn "Event type '$event_type' subscribers: " . Dumper( $subscribers{$event_type} );

              foreach my $subs ( @{$subscribers{$event_type}} )
              {
                next unless grep { $_ eq $subs } keys %can_write;
#                warn "Telling $subs about the $event_type event";
                $subs->send( $body );
              }# end foreach()
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
        }# end if()
      }# end foreach()
    }# end while()
  }; warn $@ if $@;});
}# end run()


#==============================================================================
sub handle_subscribe
{
  my ($handle, $event_type) = @_;
  
  $subscribers{$event_type} ||= [ ];
  push @{$subscribers{$event_type}}, $handle;
}# end handle_subscribe()


#==============================================================================
sub stop
{
  my $s = shift;
  
  $RUNNING = 0;
  warn "Shutting down...\n";
  $s->{worker}->join;
}# end stop()

1;# return true:

