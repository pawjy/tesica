use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $c = shift;
  return run (
    files => {
      'def.txt' => {perl_test => 1},
    },
    args => ['.'],
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 0;
      is 0+@{$json->{files}}, 0;
      is $json->{result}->{exit_code}, 0;
      ok $json->{result}->{ok};
      is $json->{result}->{fail}, 0;
      is $json->{result}->{pass}, 0;
      is 0+keys %{$json->{file_results}}, 0;
    } $c;
  });
} n => 7, name => ['no match (argument directory specified)'];

Test {
  my $c = shift;
  return run (
    files => {
      't/def.txt' => {perl_test => 1},
    },
    args => [],
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 0;
      is 0+@{$json->{files}}, 0;
      is $json->{result}->{exit_code}, 0;
      ok $json->{result}->{ok};
      is $json->{result}->{fail}, 0;
      is $json->{result}->{pass}, 0;
      is 0+keys %{$json->{file_results}}, 0;
    } $c;
  });
} n => 7, name => ['no match (no argument)'];

Test {
  my $c = shift;
  return run (
    files => {
      't/def.txt' => {perl_test => 1},
      't/abc.t' => {perl_test => 1},
    },
    args => [],
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 0;
      is 0+@{$json->{files}}, 1;
      is $json->{result}->{exit_code}, 0;
      ok $json->{result}->{ok};
      is $json->{result}->{fail}, 0;
      is $json->{result}->{pass}, 1;
      is 0+keys %{$json->{file_results}}, 1;
    } $c;
  });
} n => 7, name => ['match and non-match'];

Test {
  my $c = shift;
  return run (
    files => {
      't/def.txt' => {perl_test => 1},
      't/abc.t' => {perl_test => 1},
    },
    args => [qw(t/abc.t t/def.txt)],
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 2;
      is $json->{result}->{exit_code}, 1;
      ok ! $json->{result}->{ok};
      is $json->{result}->{fail}, 1;
      is $json->{result}->{pass}, 1;
      is 0+keys %{$json->{file_results}}, 2;
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{executor}->{type}, 'perl';
      ok ! $json->{file_results}->{'t/def.txt'}->{result}->{ok};
      is $json->{file_results}->{'t/def.txt'}->{executor}, undef;
      is $json->{file_results}->{'t/def.txt'}->{error}->{message}, 'No test executor found';
    } $c;
  });
} n => 12, name => ['executor found and not found'];

run_tests;

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
