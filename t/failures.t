use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $c = shift;
  return run (
    manifest => 'foo/bar/manifest.json',
    files => {
      't/abc.t' => {perl_test => 'ng'},
      't/def.t' => {perl_test => 1},
      'foo/bar/manifest.json' => {json => {
        allow_failure => ['../../t/abc.t', 'def.t', 'foo/bar.t'],
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
      is $json->{result}->{failure_ignored}, 1;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 't/abc.t';
      ok ! $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{error}->{message}, 'Command |perl|: Exit code 1';
      ok $json->{file_results}->{'t/abc.t'}->{error}->{ignored};
      is $json->{files}->[1]->{file_name_path}, 't/def.t';
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
      like $return->{stderr}, qr{FAIL \([0-9]+ s, ignored\)};
      like $return->{stderr}, qr{Allowed failures: 1};
      like $return->{stderr}, qr{Failure-ignored tests:.+t/abc.t}s;
      unlike $return->{stderr}, qr{Failed tests:.+t/abc.t}s;
      #warn $return->{stderr};
    } $c;
  });
} n => 16, name => 'allow_failure some';

Test {
  my $c = shift;
  return run (
    manifest => 'foo/bar/manifest.json',
    files => {
      't/abc.t' => {perl_test => 'ng'},
      't/def.t' => {perl_test => 1},
      'foo/bar/manifest.json' => {json => {
        allow_failure => ['../../t/abc.t', '', 'def.t', 'foo/bar.t'],
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
      is $json->{result}->{failure_ignored}, 1;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 't/abc.t';
      ok ! $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc.t'}->{error}->{message}, 'Command |perl|: Exit code 1';
      ok $json->{file_results}->{'t/abc.t'}->{error}->{ignored};
      is $json->{files}->[1]->{file_name_path}, 't/def.t';
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
      like $return->{stderr}, qr{FAIL \([0-9]+ s, ignored\)};
      like $return->{stderr}, qr{Allowed failures: 1};
      like $return->{stderr}, qr{Failure-ignored tests:.+t/abc.t}s;
      unlike $return->{stderr}, qr{Failed tests:.+t/abc.t}s;
      #warn $return->{stderr};
    } $c;
  });
} n => 16, name => 'allow_failure empty string';

Test {
  my $c = shift;
  return run (
    files => {
      't/abc1.t' => {perl_test => 'ok'},
      't/abc2.t' => {perl_test => 'ng'},
      't/abc3.t' => {perl_test => 'ng'},
      't/abc4.t' => {perl_test => 'ok'},
      'manifest.json' => {json => {
        max_consecutive_failures => 2,
      }},
    },
    manifest => 'manifest.json',
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 4;
      ok $json->{file_results}->{'t/abc1.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc2.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc3.t'}->{result}->{ok};
      ok $json->{file_results}->{'t/abc4.t'}->{result}->{ok};
      is $json->{rule}->{max_consecutive_failures}, 2;
    } $c;
  });
} n => 7, name => 'max_consecutive_failures specified but not more';

Test {
  my $c = shift;
  return run (
    files => {
      't/abc1.t' => {perl_test => 'ok'},
      't/abc2.t' => {perl_test => 'ng'},
      't/abc3.t' => {perl_test => 'ng'},
      't/abc4.t' => {perl_test => 'ng'},
      't/abc5.t' => {perl_test => 'ok'},
      'manifest.json' => {json => {
        max_consecutive_failures => 2,
      }},
    },
    manifest => 'manifest.json',
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 5;
      ok $json->{file_results}->{'t/abc1.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc2.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc3.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc4.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc5.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc5.t'}->{error}->{message}, 'Too many failures before this test';
      ok ! $json->{file_results}->{'t/abc5.t'}->{error}->{ignored};
      is $json->{result}->{pass}, 1;
      is $json->{result}->{fail}, 3;
      is $json->{result}->{skipped}, 1;
      is $json->{result}->{failure_ignored}, 0;
      is $json->{rule}->{max_consecutive_failures}, 2;
      unlike $return->{stderr}, qr{Failed tests:.+t/abc5.t}s;
    } $c;
  });
} n => 15, name => 'max_consecutive_failures ';

Test {
  my $c = shift;
  return run (
    files => {
      't/abc1.t' => {perl_test => 'ok'},
      't/abc2.t' => {perl_test => 'ng'},
      't/abc3.t' => {perl_test => 'ng'},
      't/abc4.t' => {perl_test => 'ok'},
      't/abc5.t' => {perl_test => 'ng'},
      't/abc6.t' => {perl_test => 'ok'},
      'manifest.json' => {json => {
        max_consecutive_failures => 2,
      }},
    },
    manifest => 'manifest.json',
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 6;
      ok $json->{file_results}->{'t/abc1.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc2.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc3.t'}->{result}->{ok};
      ok $json->{file_results}->{'t/abc4.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc5.t'}->{result}->{ok};
      ok $json->{file_results}->{'t/abc6.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc5.t'}->{error}->{message}, 'Command |perl|: Exit code 1';
      is $json->{result}->{pass}, 3;
      is $json->{result}->{fail}, 3;
      is $json->{result}->{skipped}, 0;
      is $json->{result}->{failure_ignored}, 0;
      is $json->{rule}->{max_consecutive_failures}, 2;
    } $c;
  });
} n => 14, name => 'max_consecutive_failures less';

Test {
  my $c = shift;
  return run (
    files => {
      't/abc1.t' => {perl_test => 'ok'},
      't/abc2.t' => {perl_test => 'ng'},
      't/abc3.t' => {perl_test => 'ng'},
      't/abc4.t' => {perl_test => 'ng'},
      't/abc5.t' => {perl_test => 'ok'},
      'manifest.json' => {json => {
        max_consecutive_failures => 0,
      }},
    },
    manifest => 'manifest.json',
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 5;
      ok $json->{file_results}->{'t/abc1.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc2.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc3.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc4.t'}->{result}->{ok};
      ok ! $json->{file_results}->{'t/abc5.t'}->{result}->{ok};
      is $json->{file_results}->{'t/abc2.t'}->{error}->{message}, 'Command |perl|: Exit code 1';
      is $json->{file_results}->{'t/abc3.t'}->{error}->{message}, 'Too many failures before this test';
      is $json->{result}->{pass}, 1;
      is $json->{result}->{fail}, 1;
      is $json->{result}->{skipped}, 3;
      is $json->{result}->{failure_ignored}, 0;
      is $json->{rule}->{max_consecutive_failures}, 0;
      unlike $return->{stderr}, qr{Failed tests:.+t/abc3.t}s;
    } $c;
  });
} n => 15, name => 'max_consecutive_failures 1';

run_tests;

=head1 LICENSE

Copyright 2022-2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
