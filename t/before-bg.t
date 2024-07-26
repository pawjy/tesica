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
          {
            run => ['perl', '-e', 'use Time::HiRes qw(time); $| = 1; print time, qq{\x0A}; $SIG{TERM} = sub { print qq{SIGTERM\x0A}, time, qq{\x0A}; }; sleep 10; while (1) { sleep 5 }'],
            background => 1,
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
      is 0+keys %{$json->{other_results}}, 3;
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
        my $r = $json->{other_results}->{'before-2'};
        is $r->{type}, 'before';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/before-2.txt';
        ok $r->{result}->{completed};
        is $r->{result}->{exit_code}, 0;
        ok $r->{result}->{ok};
        is $r->{command}->[0], 'bash';
        is $r->{command}->[1], '-c';
        push @x, $return->{file_out}->(1, $r->{output_file});
      }
      {
        my $r = $json->{other_results}->{'background-1'};
        is $r->{type}, 'background';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/background-1.txt';
        ok $r->{result}->{completed};
        isnt $r->{result}->{exit_code}, 0;
        ok ! $r->{result}->{ok};
        is $r->{error}->{message}, 'Command |perl|: Exit with signal 9';
        is $r->{command}->[0], 'perl';
        is $r->{command}->[1], '-e';
        my $f = $return->{file_out}->(1, $r->{output_file});
        like $f, qr/^\s*([0-9.]+)\s+SIGTERM\s+([0-9.]+)\s*$/s;
        $f =~ /^\s*([0-9.]+)\s+SIGTERM\s+([0-9.]+)\s*$/s;
        push @x, $1, $2;
      }
      push @x, $return->{file_out}->(1, $json->{file_results}->{'t/abc.t'}->{output_file});
      ok $x[0] < $x[2], $x[0];
      ok $x[2] < $x[1], $x[1];
      ok $x[1] < $x[4], $x[2];
      ok $x[4] < $x[3], $x[3];
    } $c;
  });
} n => 43, name => 'ok';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {bytes => q{ use Time::HiRes qw(time); print time }},
      'manifest.json' => {json => {
        before => [
          'perl -e "use Time::HiRes qw(time); print time"',
          {
            run => "command-not-found",
            background => 1,
          },
          'perl -e "use Time::HiRes qw(time); print time"',
        ],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      isnt $return->{result}->exit_code, 0;
      is $json->{result}->{exit_code}, $return->{result}->exit_code;
      is $json->{result}->{pass}, 0;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{result}->{failure_ignored}, 0;
      is $json->{result}->{pass_after_retry}, 0;
      ok $json->{result}->{completed};
      is 0+keys %{$json->{other_results}}, 3;
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
        my $r = $json->{other_results}->{'before-2'};
        is $r->{type}, 'before';
        is $r->{command}->[0], 'bash';
        is $r->{command}->[1], '-c';
      }
      {
        my $r = $json->{other_results}->{'background-1'};
        is $r->{type}, 'background';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/background-1.txt';
        ok $r->{result}->{completed};
        isnt $r->{result}->{exit_code}, 0;
        ok ! $r->{result}->{ok};
        is $r->{error}->{message}, 'Command |bash|: Exit code 127';
        is $r->{command}->[0], 'bash';
        is $r->{command}->[1], '-c';
        ok ! $return->{file_out}->(1, $r->{output_file});
      }
    } $c;
  });
} n => 32, name => 'bad command';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {bytes => q{ use Time::HiRes qw(time); print time }},
      'manifest.json' => {json => {
        before => [
          'perl -e "use Time::HiRes qw(time); print time"',
          {
            run => ['perl', '-e', 'use Time::HiRes qw(time); $| = 1; print time, qq{\x0A}; $SIG{TERM} = sub { print qq{SIGTERM\x0A}, time, qq{\x0A}; }; sleep 10; while (1) { sleep 5 }'],
            background => 1,
          },
        ],
        after => [
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
      is 0+keys %{$json->{other_results}}, 3;
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
        my $r = $json->{other_results}->{'after-0'};
        is $r->{type}, 'after';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/after-0.txt';
        ok $r->{result}->{completed};
        is $r->{result}->{exit_code}, 0;
        ok $r->{result}->{ok};
        is $r->{command}->[0], 'bash';
        is $r->{command}->[1], '-c';
        push @x, $return->{file_out}->(1, $r->{output_file});
      }
      {
        my $r = $json->{other_results}->{'background-1'};
        is $r->{type}, 'background';
        ok $r->{times}->{start};
        ok $r->{times}->{end};
        ok $r->{times}->{start} < $r->{times}->{end};
        is $r->{output_file}, 'files/background-1.txt';
        ok $r->{result}->{completed};
        isnt $r->{result}->{exit_code}, 0;
        ok ! $r->{result}->{ok};
        is $r->{error}->{message}, 'Command |perl|: Exit with signal 9';
        is $r->{command}->[0], 'perl';
        is $r->{command}->[1], '-e';
        my $f = $return->{file_out}->(1, $r->{output_file});
        like $f, qr/^\s*([0-9.]+)\s+SIGTERM\s+([0-9.]+)\s*$/s;
        $f =~ /^\s*([0-9.]+)\s+SIGTERM\s+([0-9.]+)\s*$/s;
        push @x, $1, $2;
      }
      push @x, $return->{file_out}->(1, $json->{file_results}->{'t/abc.t'}->{output_file});
      ok $x[0] < $x[2], $x[0];
      ok $x[2] < $x[4], $x[1];
      ok $x[4] < $x[3], $x[2];
      ok $x[3] < $x[1], $x[3];
    } $c;
  });
} n => 43, name => 'after';

run_tests;

=head1 LICENSE

Copyright 2018-2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
