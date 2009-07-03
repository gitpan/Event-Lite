
package Event::Lite::Subscriber::NoFork;

use strict;
use warnings 'all';
use base 'Event::Lite::Subscriber';

sub subscribe {
  my ($s, %args) = @_;
  
  foreach(qw( event callback ))
  {
    die "Required param '$_' was not provided"
      unless defined($args{$_});
  }# end foreach()
  
  map { $s->{$_} = $args{$_} } keys %args;
  
  $s->{running} = 1;
  $s->child_loop();
}


# Probably unnecessary:
sub running { 1 }
sub stop { shift->{running} = 0; }
sub DESTROY { my $s = shift; $s->{sock}->close() if $s->{sock}; undef(%$s); }

1;# return true:

=pod

=head1 NAME

Event::Lite::Subscriber::NoFork - Execute event callbacks in the current process

=head1 SYNOPSIS

  use Event::Lite::Subscriber::NoFork;
  
Everything else is the same as L<Event::Lite::Subscriber>

=head1 DESCRIPTION

Sometimes you want your event callbacks to be executed in the same process as
the surrounding code.  C<Event::Lite::Subscriber::NoFork> does just that.

Sometimes you don't want your callbacks to be executed in the same process as the
surrounding code.  Use L<Event::Lite::Subscriber> instead in that case.

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

