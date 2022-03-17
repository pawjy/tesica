use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $c = shift;
  return run (
    files => {
      'perl' => {bytes => qq{#!/bin/bash\necho "xyz"}, executable => 1},
      't/abc.t' => {bytes => 'print "abc"'},
      't/def.t' => {bytes => 'print "def"'},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{file_results}->{'t/abc.t'}->{output_file},
          'local/test/files/t_2Fabc_2Et.txt';
      {
        my $f = $return->{file_bytes}->('local/test/files/t_2Fabc_2Et.txt');
        my $x = {1 => [], 2 => []};
        my $s = {1 => '', 2 => ''};
        while ($f =~ s{^\x0A&([12]) (-?[0-9]+) ([0-9]+\.[0-9]+)\x0A}{}) {
          push @{$x->{$1}}, $2;
          if ($2 >= 0) {
            $s->{$1} .= substr $f, 0, $x->{$1}->[-1];
            substr ($f, 0, $x->{$1}->[-1]) = '';
          }
        }
        is $f, '';
        is $s->{1}, "xyz\x0A";
        is $s->{2}, "";
        is $x->{1}->[-1], -1;
        is $x->{2}->[-1], -1;
      }
      is 0+@{$json->{executors}->{perl}->{perl_command}}, 1;
      is $json->{executors}->{perl}->{perl_command}->[0], '' . $return->{base_path}->child ('perl')->absolute;
    } $c;
  });
} n => 8, name => ['perl'];

run_tests;

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
