use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use File::Temp;
use Promised::Command;
use JSON::PS;

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
      my $result_path = $temp_path->child ('local/test/result.json');
      my $result = json_bytes2perl $result_path->slurp;
      is $result->{result}->{exit_code}, 0;
      is $result->{result}->{json_file}, $result_path->absolute->stringify;
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
} n => 2, name => 'No arguments, empty directory';

run_tests;

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
