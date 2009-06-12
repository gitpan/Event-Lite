use strict;
use warnings;
use inc::Module::Install;
use 5.008005;

name 'Event-Lite';
perl_version '5.008001';
license 'perl';
all_from 'lib/Event/Lite.pm';

requires      'forks'               => '0.33';
requires      'forks::shared'       => '0.33';
requires      'Socket::Class'       => '2.21';
requires      'MIME::Base64'        => '3.00';
requires      'JSON::XS'            => '2.24';
test_requires 'Test::More'          => '0.77';

install_script 'sbin/eventlited';

tests_recursive();
WriteAll();

