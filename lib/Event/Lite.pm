
package Event::Lite;

use strict;
use warnings 'all';

our $VERSION = '0.002';

1;# return true:

=pod

=head1 NAME

Event::Lite - Distributed Event Broadcast System for Perl

=head1 SYNOPSIS

B<NOTE:> - The synopses are subject to drastic change, as this code is still alpha.

=head2 Server

  package MyServer;
  use base 'Event::Lite::Server';
  use Carp 'confess';
  
  my $s = __PACKAGE__->new( ... );
  
  eval { $s->run() };
  confess "Error: $@";

=head2 Publisher

  my $pub = Event::Lite::Publisher->new( ... );
  $pub->notify(
    source  => $self,
    event   => 'name-of-event',
    ...
    # Anything else is passed along as properties of the event
  );

=head2 Subscriber

  package MySubscriber;
  use base 'Event::Lite::Subscriber';
  use Carp 'confess';
  
  my $s = __PACKAGE__->new( ... );
  while( my $event = eval { $s->event('name-of-event') } )
  {
    # Process our event:
  }# end while()
  
  confess "Fell out of loop: $@";

=head1 DESCRIPTION

C<Event::Lite> aims to provide a distributed event broadcast system for Perl.

This means that an event (i.e. Price of Tea in China (PTC) changes) can occur
in one system, and any number of "subscriber" systems can be instantly notified,
regardless of whether they are on the same system or network.

=head2 Architecture

C<Event::Lite> basically has 4 components:

=over 4

=item * Server

The part responsible for connecting the other 3 parts together.

=item * Publisher

The where events are generated.

=item * Event

An object that describes the Who, What, When, Where, Why and How of what happened.

=item * Subscriber

Something that cares about a specific kind of event.  It can expect the server
to let it know when that kind of event happens.

=back

=head2 Protocol

Because this is supposed to be lightweight and entirely focused on just the event
broadcast aspect, a simple text-based protocol will be used.  While XMPP might
be much more robust, this module is designed with simplicity in mind - first and 
foremost.

=head2 Limitations

One of the goals of C<Event::Lite> is to not have any arbitrary limitations.

I fully expect C<Event::Lite> to scale to thousands of events, thousands of subscribers
and to perform on par with any commercial system currently out there.

I also fully expect C<Event::Lite> to be satisfactory for use in mission-critical
systems like stock trading platforms, nuclear missile silos and garage door openers.

If you think garage door openers are not mission-critical, think again.

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

