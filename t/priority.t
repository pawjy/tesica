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
      't/xyz.t' => {perl_test => 1},
      'manifest.json' => {json => {
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, $json->{result}->{exit_code};
      is 0+@{$json->{files}}, 2; 
      is $json->{files}->[0]->{file_name_path}, 't/abc.t';
      is $json->{files}->[1]->{file_name_path}, 't/xyz.t';
      ok $json->{file_results}->{'t/abc.t'}->{times}->{start} < $json->{file_results}->{'t/xyz.t'}->{times}->{end};
    } $c;
  });
} n => 5, name => 'default order';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 1},
      't/abc/1.t' => {perl_test => 1},
      't/xyz.t' => {perl_test => 1},
      'manifest.json' => {json => {
        priority => [qw(
          t/xyz.t
          t/bbb.t
        )],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, $json->{result}->{exit_code};
      is 0+@{$json->{files}}, 3;
      is $json->{files}->[0]->{file_name_path}, 't/xyz.t';
      is $json->{files}->[1]->{file_name_path}, 't/abc.t';
      is $json->{files}->[2]->{file_name_path}, 't/abc/1.t';
      ok $json->{file_results}->{'t/abc.t'}->{times}->{start} > $json->{file_results}->{'t/xyz.t'}->{times}->{end};
      ok $json->{file_results}->{'t/abc/1.t'}->{times}->{start} > $json->{file_results}->{'t/xyz.t'}->{times}->{end};
      ok $json->{file_results}->{'t/abc.t'}->{times}->{start} < $json->{file_results}->{'t/abc/1.t'}->{times}->{end};
    } $c;
  });
} n => 8, name => 'order specified 1';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 1},
      't/abc/1.t' => {perl_test => 1},
      't/foo.t' => {perl_test => 1},
      't/xyz.t' => {perl_test => 1},
      'manifest.json' => {json => {
        priority => [qw(
          t/xyz.t
          t/bbb.t
          t/foo.t
        )],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, $json->{result}->{exit_code};
      is 0+@{$json->{files}}, 4;
      is $json->{files}->[0]->{file_name_path}, 't/xyz.t';
      is $json->{files}->[1]->{file_name_path}, 't/foo.t';
      is $json->{files}->[2]->{file_name_path}, 't/abc.t';
      is $json->{files}->[3]->{file_name_path}, 't/abc/1.t';
    } $c;
  });
} n => 6, name => 'order specified 2';

Test {
  my $c = shift;
  return run (
    manifest => 'foo/bar/manifest.json',
    files => {
      't/abc.t' => {perl_test => 1},
      't/abc/1.t' => {perl_test => 1},
      't/foo.t' => {perl_test => 1},
      't/xyz.t' => {perl_test => 1},
      'foo/bar/manifest.json' => {json => {
        priority => [qw(
          ../../t/xyz.t
          ../../t/bbb.t
          ../../t/foo.t
        )],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, $json->{result}->{exit_code};
      is 0+@{$json->{files}}, 4;
      is $json->{files}->[0]->{file_name_path}, 't/xyz.t';
      is $json->{files}->[1]->{file_name_path}, 't/foo.t';
      is $json->{files}->[2]->{file_name_path}, 't/abc.t';
      is $json->{files}->[3]->{file_name_path}, 't/abc/1.t';
    } $c;
  });
} n => 6, name => 'another directory';

run_tests;

=head1 LICENSE

Copyright 2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
