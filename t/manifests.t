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
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, $json->{result}->{exit_code};
      is $json->{rule}->{base_dir}, $return->{base_path}->absolute->stringify;
      is $json->{rule}->{result_dir}, $return->{base_path}->child ('local/test')->absolute->stringify;
      is $json->{rule}->{manifest_file}, $return->{base_path}->child ('manifest.json')->absolute->stringify;
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{json_file}, 'result.json';
      is 0+@{$json->{files}}, 1;
      is $json->{files}->[0]->{file_name_path}, 't/abc.t';
    } $c;
  });
} n => 8, name => 'No arguments';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      is $return->{result}->exit_code, 1;
      is $return->{json}, undef;
      like $return->{stderr}, qr{ERROR: \|.+/manifest.json\|: };
    } $c;
  });
} n => 3, name => 'file not found';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 1},
      'manifest.json' => {bytes => "abc"},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      is $return->{result}->exit_code, 1;
      is $return->{json}, undef;
      like $return->{stderr}, qr{ERROR: Manifest file \|.+/manifest.json\| is not a JSON object};
    } $c;
  });
} n => 3, name => 'file not json';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      't/abc.t' => {perl_test => 1},
      'manifest.json' => {json => []},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      is $return->{result}->exit_code, 1;
      is $return->{json}, undef;
      like $return->{stderr}, qr{ERROR: Manifest file \|.+/manifest.json\| is not a JSON object};
    } $c;
  });
} n => 3, name => 'file not json object';

run_tests;

=head1 LICENSE

Copyright 2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
