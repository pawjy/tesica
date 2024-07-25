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
          'perl -e "use Time::HiRes qw(time); print time"',
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
        my $r = $json->{other_results}->{'before-0'};
        is $r->{type}, 'before';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/before-0.txt';
        ok $r->{result}->{completed};
        is $r->{result}->{exit_code}, 0;
        ok $r->{result}->{ok};
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
        is $r->{run}->[0], 'bash';
        is $r->{run}->[1], '-c';
        push @x, $return->{file_out}->(1, $r->{output_file});
      }
      push @x, $return->{file_out}->(1, $json->{file_results}->{'t/abc.t'}->{output_file});
      ok $x[0] < $x[1], $x[0];
      ok $x[1] < $x[2], $x[1];
      ok $x[2], $x[2];
    } $c;
  });
} n => 30, name => 'ok';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {bytes => q{ use Time::HiRes qw(time); print time }},
      'manifest.json' => {json => {
        before => [
          {run => ['perl', '-e', "use Time::HiRes qw(time); print time"]},
          {run => 'perl -e "use Time::HiRes qw(time); print time"'},
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
        my $r = $json->{other_results}->{'before-0'};
        is $r->{type}, 'before';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/before-0.txt';
        ok $r->{result}->{completed};
        is $r->{result}->{exit_code}, 0;
        ok $r->{result}->{ok};
        push @x, $return->{file_out}->(1, $r->{output_file});
        is $r->{run}->[0], 'perl';
        is $r->{run}->[1], '-e';
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
        is $r->{run}->[0], 'bash';
        is $r->{run}->[1], '-c';
        push @x, $return->{file_out}->(1, $r->{output_file});
      }
      push @x, $return->{file_out}->(1, $json->{file_results}->{'t/abc.t'}->{output_file});
      ok $x[0] < $x[1], $x[0];
      ok $x[1] < $x[2], $x[1];
      ok $x[2], $x[2];
    } $c;
  });
} n => 32, name => 'command array';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {bytes => q{ use Time::HiRes qw(time); print time }},
      'manifest.json' => {json => {
        before => [
          'perl -e "use Time::HiRes qw(time); print time; exit 41"',
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
        my $r = $json->{other_results}->{'before-0'};
        is $r->{type}, 'before';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/before-0.txt';
        ok $r->{result}->{completed};
        is $r->{result}->{exit_code}, 41;
        ok ! $r->{result}->{ok};
        is $r->{error}->{message}, "Command |bash|: Exit code 41";
        ok $return->{file_out}->(1, $r->{output_file});
      }
      {
        my $r = $json->{other_results}->{'before-1'};
        is $r->{type}, 'before';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        is $r->{times}->{start}, $r->{times}->{end};
        is $r->{output_file}, undef;
        ok ! $r->{result}->{completed};
        is $r->{result}->{exit_code}, undef;
        ok ! $r->{result}->{ok};
        is $r->{error}->{message}, "Failed before this test";
      }
      is 0+keys %{$json->{file_results}}, 0;
    } $c;
  });
} n => 29, name => 'not ok';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {bytes => q{ use Time::HiRes qw(time); print time }},
      'manifest.json' => {json => {
        before => [
          {run => ["command-not-found"]},
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
        my $r = $json->{other_results}->{'before-0'};
        is $r->{type}, 'before';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/before-0.txt';
        ok $r->{result}->{completed};
        isnt $r->{result}->{exit_code}, 0;
        ok ! $r->{result}->{ok};
        ok $r->{error}->{message};
        ok ! $return->{file_out}->(1, $r->{output_file});
      }
      {
        my $r = $json->{other_results}->{'before-1'};
        is $r->{type}, 'before';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        is $r->{times}->{start}, $r->{times}->{end};
        is $r->{output_file}, undef;
        ok ! $r->{result}->{completed};
        is $r->{result}->{exit_code}, undef;
        ok ! $r->{result}->{ok};
        is $r->{error}->{message}, "Failed before this test";
      }
      is 0+keys %{$json->{file_results}}, 0;
    } $c;
  });
} n => 29, name => 'bad command';

run_tests;

=head1 LICENSE

Copyright 2018-2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
