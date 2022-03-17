use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, $json->{result}->{exit_code};
      is $json->{rule}->{base_dir}, $return->{base_path}->absolute->stringify;
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{json_file}, 'local/test/result.json';
      is 0+@{$json->{files}}, 1;
      is $json->{files}->[0]->{file_name_path}, 't/abc.t';
    } $c;
  });
} n => 6, name => 'No arguments';

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {perl_test => 'ok'},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, $json->{result}->{exit_code};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 1, 'result.pass';
      is $json->{result}->{fail}, 0, 'result.fail';
      is $json->{file_results}->{'t/abc.t'}->{result}->{exit_code}, 0;
      is $json->{file_results}->{'t/abc.t'}->{result}->{ok}, 1;
      is $json->{file_results}->{'t/abc.t'}->{error}, undef;

      ok $json->{result}->{ok};
    } $c;
  });
} n => 8, name => ['success'];

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {perl_test => 'ok'},
      't/def.t' => {perl_test => 'ng'},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, $json->{result}->{exit_code};
      is $json->{result}->{exit_code}, 1;
      is $json->{result}->{pass}, 1, 'result.pass';
      is $json->{result}->{fail}, 1, 'result.fail';
      
      is $json->{file_results}->{'t/abc.t'}->{result}->{exit_code}, 0;
      is $json->{file_results}->{'t/abc.t'}->{result}->{ok}, 1;
      is $json->{file_results}->{'t/abc.t'}->{error}, undef;
      
      is $json->{file_results}->{'t/def.t'}->{result}->{exit_code}, 1;
      ok ! $json->{file_results}->{'t/def.t'}->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{error}->{message}, 'Exit code 1';

      ok ! $json->{result}->{ok};
    } $c;
  });
} n => 11, name => ['success and failure'];

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {bytes => 'exit 2'},
      't/def.t' => {perl_test => 'ng'},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, $json->{result}->{exit_code};
      is $json->{result}->{exit_code}, 1;
      is $json->{result}->{pass}, 0, 'result.pass';
      is $json->{result}->{fail}, 2, 'result.fail';
      
      is $json->{file_results}->{'t/abc.t'}->{result}->{exit_code}, 2;
      ok ! $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{error}->{message}, 'Exit code 2';
      
      is $json->{file_results}->{'t/def.t'}->{result}->{exit_code}, 1;
      ok ! $json->{file_results}->{'t/def.t'}->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{error}->{message}, 'Exit code 1';

      ok ! $json->{result}->{ok};
    } $c;
  });
} n => 11, name => ['fails'];

run_tests;

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
