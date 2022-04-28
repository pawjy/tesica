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
      't/def.t' => {perl_test => 1},
      'manifest.json' => {json => {
        skip => [],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{result}->{failure_ignored}, 0;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 't/abc.t';
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{files}->[1]->{file_name_path}, 't/def.t';
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
    } $c;
  });
} n => 10, name => 'skipped none';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 0},
      't/def.t' => {perl_test => 1},
      'manifest.json' => {json => {
        skip => ['./t/abc.t', 'def.t'],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 1;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 1;
      is $json->{result}->{failure_ignored}, 0;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 't/abc.t';
      ok ! $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{error}->{message}, 'Skipped by request';
      ok $json->{file_results}->{'t/abc.t'}->{error}->{ignored};
      is $json->{files}->[1]->{file_name_path}, 't/def.t';
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
    } $c;
  });
} n => 12, name => 'skipped some';

Test {
  my $c = shift;
  return run (
    manifest => 'foo/bar/manifest.json',
    files => {
      't/abc.t' => {perl_test => 0},
      't/def.t' => {perl_test => 1},
      'foo/bar/manifest.json' => {json => {
        skip => ['../../t/abc.t', 'def.t', 'foo/bar.t'],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 1;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 1;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 't/abc.t';
      ok ! $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{error}->{message}, 'Skipped by request';
      is $json->{files}->[1]->{file_name_path}, 't/def.t';
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
      unlike $return->{stderr}, qr{Failed tests:.+t/abc.t}s;
    } $c;
  });
} n => 11, name => 'skipped some';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
      'manifest.json' => {json => {
        skip => [''],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{result}->{failure_ignored}, 0;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 't/abc.t';
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{files}->[1]->{file_name_path}, 't/def.t';
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
    } $c;
  });
} n => 10, name => 'skipped empty string';

run_tests;

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
