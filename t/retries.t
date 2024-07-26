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
      't/abc.t' => {perl_test => 1},
      'manifest.json' => {json => {
        max_retries => 2,
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is 0+@{$json->{files}}, 1;
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{error}, undef;
      is $json->{file_results}->{'t/abc.t'}->{tries}, undef;
    } $c;
  });
} n => 5, name => 'No retry';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 'ok'},
      't/def.t' => {perl_test => 'ng'},
      't/ghi.t' => {perl_test => 'ok'},
      'manifest.json' => {json => {
        max_retries => 2,
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 1;
      is 0+@{$json->{files}}, 3;
      is $json->{rule}->{max_retries}, 2;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 1;
      is $json->{result}->{skipped}, 0;
      is $json->{result}->{failure_ignored}, 0;
      is $json->{result}->{pass_after_retry}, 0;
      
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{error}, undef;
      is $json->{file_results}->{'t/abc.t'}->{tries}, undef;

      is $json->{file_results}->{'t/def.t'}->{executor}->{type}, 'perl';
      ok ! $json->{file_results}->{'t/def.t'}->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{error}->{message}, 'Command |perl|: Exit code 1';
      is 0+@{$json->{file_results}->{'t/def.t'}->{tries}}, 2;
      is $json->{file_results}->{'t/def.t'}->{tries}->[0]->{executor}->{type}, 'perl';
      ok ! $json->{file_results}->{'t/def.t'}->{tries}->[0]->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{tries}->[0]->{error}->{message}, 'Command |perl|: Exit code 1';
      is $json->{file_results}->{'t/def.t'}->{tries}->[0]->{tries}, undef;
      is $json->{file_results}->{'t/def.t'}->{tries}->[1]->{executor}->{type}, 'perl';
      ok ! $json->{file_results}->{'t/def.t'}->{tries}->[1]->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{tries}->[1]->{error}->{message}, 'Command |perl|: Exit code 1';
      is $json->{file_results}->{'t/def.t'}->{tries}->[1]->{tries}, undef;
      
      ok $json->{file_results}->{'t/ghi.t'}->{result}->{ok};
      is $json->{file_results}->{'t/ghi.t'}->{error}, undef;
      is $json->{file_results}->{'t/ghi.t'}->{tries}, undef;
    } $c;
  });
} n => 26, name => 'permanent failure';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 'ok'},
      't/def.t' => {bytes => q{
        if (-f "a.txt") {
          exit 0;
        } else {
          open my $file, '>', 'a.txt';
          exit 1;
        }
      }},
      't/ghi.t' => {perl_test => 'ok'},
      'manifest.json' => {json => {
        max_retries => 1,
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is 0+@{$json->{files}}, 3;
      is $json->{rule}->{max_retries}, 1;
      is $json->{result}->{pass}, 3;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{result}->{failure_ignored}, 0;
      is $json->{result}->{pass_after_retry}, 1;
      
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{error}, undef;
      is $json->{file_results}->{'t/abc.t'}->{tries}, undef;

      is $json->{file_results}->{'t/def.t'}->{executor}->{type}, 'perl';
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{error}, undef;
      is 0+@{$json->{file_results}->{'t/def.t'}->{tries}}, 1;
      is $json->{file_results}->{'t/def.t'}->{tries}->[0]->{executor}->{type}, 'perl';
      ok ! $json->{file_results}->{'t/def.t'}->{tries}->[0]->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{tries}->[0]->{error}->{message}, 'Command |perl|: Exit code 1';
      is $json->{file_results}->{'t/def.t'}->{tries}->[0]->{tries}, undef;
      is $json->{file_results}->{'t/def.t'}->{tries}->[0]->{current_try_count}, 1;
      is $json->{file_results}->{'t/def.t'}->{tries}->[0]->{max_try_count}, 2;
      is $json->{file_results}->{'t/def.t'}->{current_try_count}, 2;
      is $json->{file_results}->{'t/def.t'}->{max_try_count}, 2;
      
      ok $json->{file_results}->{'t/ghi.t'}->{result}->{ok};
      is $json->{file_results}->{'t/ghi.t'}->{error}, undef;
      is $json->{file_results}->{'t/ghi.t'}->{tries}, undef;
      is $json->{file_results}->{'t/ghi.t'}->{current_try_count}, 1;
      is $json->{file_results}->{'t/ghi.t'}->{max_try_count}, 2;
    } $c;
  });
} n => 28, name => 'one-time failure';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 'ok'},
      't/def.t' => {perl_test => 'ng'},
      't/ghi.t' => {perl_test => 'ng'},
      't/jkl.t' => {perl_test => 'ng'},
      't/mno.t' => {perl_test => 'ok'},
      'manifest.json' => {json => {
        max_retries => 2,
        max_consecutive_failures => 2,
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 1;
      is 0+@{$json->{files}}, 5;
      is $json->{rule}->{max_retries}, 2;
      is $json->{rule}->{max_consecutive_failures}, 2;
      is $json->{result}->{pass}, 1;
      is $json->{result}->{fail}, 3;
      is $json->{result}->{skipped}, 1;
      is $json->{result}->{failure_ignored}, 0;
      is $json->{result}->{pass_after_retry}, 0;
      
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{error}, undef;
      is $json->{file_results}->{'t/abc.t'}->{tries}, undef;
      is $json->{file_results}->{'t/abc.t'}->{current_try_count}, 1;
      is $json->{file_results}->{'t/abc.t'}->{max_try_count}, 3;

      ok ! $json->{file_results}->{'t/def.t'}->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{error}->{message}, 'Command |perl|: Exit code 1';
      is 0+@{$json->{file_results}->{'t/def.t'}->{tries}}, 2;

      ok ! $json->{file_results}->{'t/ghi.t'}->{result}->{ok};
      is $json->{file_results}->{'t/ghi.t'}->{error}->{message}, 'Command |perl|: Exit code 1';
      is 0+@{$json->{file_results}->{'t/ghi.t'}->{tries}}, 2;

      ok ! $json->{file_results}->{'t/jkl.t'}->{result}->{ok};
      is $json->{file_results}->{'t/jkl.t'}->{error}->{message}, 'Command |perl|: Exit code 1';
      is 0+@{$json->{file_results}->{'t/jkl.t'}->{tries}}, 2;
      
      ok ! $json->{file_results}->{'t/mno.t'}->{result}->{ok};
      is $json->{file_results}->{'t/mno.t'}->{error}->{message}, 'Too many failures before this test';
      is $json->{file_results}->{'t/mno.t'}->{tries}, undef;
    } $c;
  });
} n => 26, name => 'permanent failure and consecutive errors';

run_tests;

=head1 LICENSE

Copyright 2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
