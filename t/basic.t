use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use File::Temp;
use Promised::Command;

test {
  my $c = shift;

  my $RootPath = path (__FILE__)->parent->parent;

  my $temp = File::Temp->newdir;
  my $temp_path = path ($temp);
  
  my $cmd = Promised::Command->new ([
    $RootPath->child ('perl')->absolute,
    $RootPath->child ('bin/tesica.pl')->absolute,
  ]);
  $cmd->wd ($temp_path);

  return $cmd->run->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    die $result unless $result->exit_code == 0;
    test {
      ok 1;
    } $c;
  })->catch (sub {
    my $e = $_[0];
    test {
      ok 0, 'No exception';
      is $e, undef;
    } $c;
  })->then (sub {
    done $c;
    undef $c;
    undef $temp;
  });
} n => 1, name => 'No arguments, empty directory';

run_tests;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
