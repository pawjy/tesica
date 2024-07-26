use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {bytes => q{ use Time::HiRes qw(time); print time }},
      'manifest.json' => {json => {
        before => [
          {
            run => ['perl', '-e', "use Time::HiRes qw(time); print time; exit 0 if -f 'x'; open \$x, '>x'; exit 1 "],
            check => 1,
            interval => 2,
          },
          'perl -e "use Time::HiRes qw(time); print time"',
        ],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 0;
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 1;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{result}->{failure_ignored}, 0;
      is $json->{result}->{pass_after_retry}, 0;
      ok $json->{result}->{completed};
      is 0+keys %{$json->{other_results}}, 2;
      my @x;
      {
        my $r = $json->{other_results}->{'check-0'};
        is $r->{type}, 'check';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/check-0.txt';
        ok $r->{result}->{completed};
        is $r->{result}->{exit_code}, 0;
        ok $r->{result}->{ok};
        is $r->{error}, undef;
        is $r->{current_try_count}, 2;
        is $r->{max_try_count}, 100;
        push @x, $return->{file_out}->(1, $r->{output_file});
      }
      {
        my $r = $json->{other_results}->{'before-1'};
        is $r->{type}, 'before';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/before-1.txt';
        ok $r->{result}->{completed};
        is $r->{result}->{exit_code}, 0;
        ok $r->{result}->{ok};
        is $r->{command}->[0], 'bash';
        is $r->{command}->[1], '-c';
        is $r->{current_try_count}, 1;
        is $r->{max_try_count}, 1;
        push @x, $return->{file_out}->(1, $r->{output_file});
      }
      push @x, $return->{file_out}->(1, $json->{file_results}->{'t/abc.t'}->{output_file});
      ok $x[0] - $json->{times}->{start} > 2;
      ok $x[0] < $x[1], $x[0];
      ok $x[1] < $x[2], $x[1];
      ok $x[2], $x[2];
    } $c;
  });
} n => 36, name => 'ok';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {bytes => q{ use Time::HiRes qw(time); print time }},
      'manifest.json' => {json => {
        before => [
          {
            run => ['perl', '-e', "use Time::HiRes qw(time); print time; exit 13 "],
            check => 1,
            interval => 2,
            max_retries => 10,
          },
          'perl -e "use Time::HiRes qw(time); print time"',
        ],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is $json->{result}->{exit_code}, 1;
      is $json->{result}->{pass}, 0;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{result}->{failure_ignored}, 0;
      is $json->{result}->{pass_after_retry}, 0;
      ok $json->{result}->{completed};
      is 0+keys %{$json->{other_results}}, 2;
      my @x;
      {
        my $r = $json->{other_results}->{'check-0'};
        is $r->{type}, 'check';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/check-0.txt';
        ok $r->{result}->{completed};
        is $r->{result}->{exit_code}, 13;
        ok ! $r->{result}->{ok};
        is $r->{error}->{message}, "Command |perl|: Exit code 13";
        is $r->{current_try_count}, 11;
        is $r->{max_try_count}, 11;
        push @x, $return->{file_out}->(1, $r->{output_file});
      }
      {
        my $r = $json->{other_results}->{'before-1'};
        is $r->{type}, 'before';
        ok ! $r->{result}->{completed};
        is $r->{result}->{exit_code}, undef;
        ok ! $r->{result}->{ok};
      }
      ok $x[0] - $json->{times}->{start} > 20;
      is 0+keys %{$json->{file_results}}, 0;
    } $c;
  });
} n => 26, name => 'permanent failure';

run_tests;

=head1 LICENSE

Copyright 2018-2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
