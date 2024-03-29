use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {bytes => 'print STDOUT "abc\x0A"; print STDERR "x"'},
      't/def.t' => {bytes => 'print STDERR "xyz\x0AAAA"'},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{file_results}->{'t/abc.t'}->{output_file},
          'files/t_2Fabc_2Et.txt';
      is $json->{file_results}->{'t/def.t'}->{output_file},
          'files/t_2Fdef_2Et.txt';
      {
        my $f = $return->{result_file_bytes}->('t/abc.t');
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
        is $s->{1}, "abc\x0A";
        is $s->{2}, "x";
        is $x->{1}->[-1], -1;
        is $x->{2}->[-1], -1;
      }
      {
        my $f = $return->{result_file_bytes}->('t/def.t');
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
        is $s->{1}, "";
        is $s->{2}, "xyz\x0AAAA";
        is $x->{1}->[-1], -1;
        is $x->{2}->[-1], -1;
      }
      ok $json->{times}->{start};
      ok $json->{times}->{start} < $json->{times}->{end};
      ok $json->{times}->{start} < $json->{times}->{now};
    } $c;
  });
} n => 15, name => ['test output result files'];

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {bytes => 'print STDOUT "abc\x0A"; print STDERR "x"'},
      't/def.t' => {bytes => 'sleep 5; print STDERR "xyz\x0AAAA"'},
    },
    kill_after => 2,
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{file_results}->{'t/abc.t'}->{output_file},
          'files/t_2Fabc_2Et.txt';
      is $json->{file_results}->{'t/abc.t'}->{result}->{exit_code}, 0;
      ok $json->{file_results}->{'t/abc.t'}->{result}->{completed};
      ok $json->{file_results}->{'t/abc.t'}->{times}->{start};
      ok $json->{file_results}->{'t/abc.t'}->{times}->{end};
      is $json->{file_results}->{'t/def.t'}->{result}->{exit_code}, undef;
      ok ! $json->{file_results}->{'t/def.t'}->{result}->{completed};
      is $json->{file_results}->{'t/def.t'}->{output_file}, undef;
      is $json->{file_results}->{'t/def.t'}->{times}->{start}, undef;
      is $json->{file_results}->{'t/def.t'}->{times}->{end}, undef;
      {
        my $f = $return->{result_file_bytes}->('t/abc.t');
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
        is $s->{1}, "abc\x0A";
        is $s->{2}, "x";
        is $x->{1}->[-1], -1;
        is $x->{2}->[-1], -1;
      }
      is $json->{result}->{pass}, 1;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{exit_code}, 1;
      ok ! $json->{result}->{completed};
      ok $json->{times}->{start};
      ok $json->{times}->{start} < $json->{times}->{now};
      ok $json->{times}->{now};
      is $json->{times}->{end}, undef;
    } $c;
  });
} n => 23, name => ['test output result files, incomplete'];

run_tests;

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
