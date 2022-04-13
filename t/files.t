use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

for (
  [{
    't/abc.t' => {perl_test => 1},
  }, [qw(t/abc.t)]],
  [{
    't/abc.t' => {perl_test => 1},
    'abc.t' => {perl_test => 1},
  }, [qw(t/abc.t)]],
  [{
    't/abc.t' => {perl_test => 1},
    'x/t/abc.t' => {perl_test => 1},
  }, [qw(t/abc.t)]],
  [{
    't/abc.t' => {perl_test => 1},
    't/xyz.t' => {perl_test => 1},
  }, [qw(t/abc.t t/xyz.t)]],
  [{
    't/abc.t' => {perl_test => 1},
    't/aa/xyz.t' => {perl_test => 1},
  }, [qw(t/aa/xyz.t t/abc.t)]],
  [{
    't/zz/abc.t' => {perl_test => 1},
    't/aa/xyz.t' => {perl_test => 1},
  }, [qw(t/aa/xyz.t t/zz/abc.t)]],
  [{
    't/abc.t' => {perl_test => 1},
    't/xyz.txt' => {perl_test => 1},
  }, [qw(t/abc.t)]],
  [{
    't/abc' => {perl_test => 1},
    't/xyz.txt' => {perl_test => 1},
  }, []],
  [{
    't/abc.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t/abc.t)]],
  [{
    't/abc.t' => {perl_test => 1},
    't/foo.t/xyz.txt' => {perl_test => 1},
  }, [qw(t/abc.t)]],
  [{
    't/abc.t' => {perl_test => 1},
    't/foo.t/xyz.t' => {perl_test => 1},
  }, [qw(t/abc.t t/foo.t/xyz.t)]],
) {
  my ($files, $expected) = @$_;
  Test {
    my $c = shift;
    return run (
      files => $files,
    )->then (sub {
      my $return = $_[0];
      test {
        my $json = $return->{json};
        is $return->{result}->exit_code, $json->{result}->{exit_code};
        is $json->{result}->{exit_code}, 0;
        ok $json->{result}->{completed};
        is join ($;, map { $_->{file_name_path} } @{$json->{files}}),
           join ($;, sort { $a cmp $b } @$expected);
        ok $json->{times}->{start};
        ok $json->{times}->{end};
        ok $json->{times}->{start} < $json->{times}->{end};
      } $c;
    });
  } n => 7, name => ['no argument default', @$expected];
}

for (
  [{
    't/abc.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t2)], ['t2'], 1],
  [{
    't/abc.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t2.t)], ['t2.t'], 1],
  [{
    't/abc.t' => {perl_test => 1},
    't2/abc.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t2)], [qw(t2/abc.t)], 0],
  [{
    't/abc.t' => {perl_test => 1},
    't2/abc.t' => {directory => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t2)], [], 0],
  [{
    't/abc.t' => {perl_test => 1},
    't2/abc.t' => {perl_test => 1},
    't2/def.t' => {perl_test => 1},
    't2/ab/c.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t2)], [qw(t2/abc.t t2/def.t t2/ab/c.t)], 0],
  [{
    't/abc.t' => {perl_test => 1},
    't2/abc.t' => {perl_test => 1},
    't2/def.t' => {perl_test => 1},
    't2/ab/c.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t2/*.t)], [qw(t2/*.t)], 1],
  [{
    't/abc.t' => {perl_test => 1},
    't2/abc.t' => {perl_test => 1},
    't2/def.t' => {perl_test => 1},
    't2/ab/c.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t2/abc.t)], ['t2/abc.t'], 0],
  [{
    't/abc.t' => {perl_test => 1},
    't2/abc.t' => {perl_test => 1},
    't2/def.t' => {perl_test => 1},
    't2/ab/c.t' => {perl_test => 1},
    't2/ab/x.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t2/abc.t t2/ab)], [qw(t2/abc.t t2/ab/c.t t2/ab/x.t)], 0],
  [{
    't/abc.t' => {perl_test => 1},
    't.t/abc.pl' => {perl_test => 1},
    't2/abc.t' => {perl_test => 1},
    't2/def.t' => {perl_test => 1},
    't2/ab/c.t' => {perl_test => 1},
    't2/ab/c.txt' => {perl_test => 1},
    't2/ab/x.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
    'foo.t' => {perl_test => 1},
  }, [qw(.)], [qw(t2/abc.t t2/ab/c.t t2/ab/x.t t/abc.t t_deps/xyz.t t2/def.t
                  foo.t)], 0],
  [{
    't/abc.t' => {perl_test => 1},
    't2/xyz.t' => {perl_test => 1},
    't2/t/xyz.t' => {perl_test => 1},
  }, [qw(t2)], [qw(t2/xyz.t t2/t/xyz.t)], 0],
  [{
    't/abc.t' => {perl_test => 1},
    't_deps/xyz.t' => {perl_test => 1},
  }, [qw(t/abc.t t/abc.t)], [qw(t/abc.t)], 0],
  [{
    't/abc.t' => {perl_test => 1},
    't/def.t' => {perl_test => 'ng'},
  }, [qw(t/abc.t t/def.t t/def.t t/abc.t)], [qw(t/abc.t t/def.t)], 1],
  [{
    'u/abc.t' => {perl_test => 1},
    'u/def.t' => {perl_test => 'ng'},
  }, [qw(u u/def.t)], [qw(u/abc.t u/def.t)], 1],
) {
  my ($files, $args, $expected, $fail_count) = @$_;
  Test {
    my $c = shift;
    return run (
      files => $files,
      args => $args,
    )->then (sub {
      my $return = $_[0];
      test {
        my $json = $return->{json};
        is $return->{result}->exit_code, $fail_count ? 1 : 0;
        is $json->{result}->{fail}, $fail_count;
        is join ($;, map { $_->{file_name_path} } @{$json->{files}}),
           join ($;, sort { $a cmp $b } @$expected);
      } $c;
    });
  } n => 3, name => ['with file name args', @$args, @$expected];
}

Test {
  my $c = shift;
  return run (
    files => {
    },
    args => ['abc.t'],
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 1;
      is $json->{files}->[0]->{file_name_path}, 'abc.t';
      is $json->{result}->{exit_code}, 1;
      ok ! $json->{result}->{ok};
      is $json->{result}->{fail}, 1;
      is $json->{result}->{pass}, 0;
      is 0+keys %{$json->{file_results}}, 1;
      ok ! $json->{file_results}->{'abc.t'}->{result}->{ok};
      is $json->{file_results}->{'abc.t'}->{result}->{fail}, undef;
      is $json->{file_results}->{'abc.t'}->{result}->{pass}, undef;
      ok $json->{file_results}->{'abc.t'}->{times}->{start};
      is $json->{file_results}->{'abc.t'}->{times}->{start},
         $json->{file_results}->{'abc.t'}->{times}->{end};
    } $c;
  });
} n => 13, name => ['specified file not found'];

Test {
  my $c = shift;
  return run (
    files => {
      'def.t' => {perl_test => 1},
    },
    args => ['abc.t', 'def.t'],
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 'abc.t';
      is $json->{files}->[1]->{file_name_path}, 'def.t';
      is $json->{result}->{exit_code}, 1;
      ok $json->{result}->{completed};
      ok ! $json->{result}->{ok};
      is $json->{result}->{fail}, 1;
      is $json->{result}->{pass}, 1;
      is 0+keys %{$json->{file_results}}, 2;
      ok ! $json->{file_results}->{'abc.t'}->{result}->{ok};
      is $json->{file_results}->{'abc.t'}->{result}->{fail}, undef;
      is $json->{file_results}->{'abc.t'}->{result}->{pass}, undef;
      ok $json->{file_results}->{'abc.t'}->{times}->{start};
      is $json->{file_results}->{'abc.t'}->{times}->{start},
         $json->{file_results}->{'abc.t'}->{times}->{end};
      ok $json->{file_results}->{'def.t'}->{result}->{ok};
      is $json->{file_results}->{'def.t'}->{result}->{exit_code}, 0;
      ok $json->{file_results}->{'def.t'}->{times}->{start};
      ok $json->{file_results}->{'def.t'}->{times}->{start}
         < $json->{file_results}->{'def.t'}->{times}->{end};
    } $c;
  });
} n => 19, name => ['one of specified files not found'];

Test {
  my $c = shift;
  return run (
    files => {
      'abc.t' => {perl_test => 1, unreadable => 1},
      'def.t' => {perl_test => 1},
    },
    args => ['abc.t', 'def.t'],
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 'abc.t';
      is $json->{files}->[1]->{file_name_path}, 'def.t';
      is $json->{result}->{exit_code}, 1;
      ok ! $json->{result}->{ok};
      is $json->{result}->{fail}, 1;
      is $json->{result}->{pass}, 1;
      is 0+keys %{$json->{file_results}}, 2;
      ok ! $json->{file_results}->{'abc.t'}->{result}->{ok};
      ok $json->{file_results}->{'abc.t'}->{result}->{exit_code};
      is $json->{file_results}->{'abc.t'}->{result}->{fail}, undef;
      is $json->{file_results}->{'abc.t'}->{result}->{pass}, undef;
      like $json->{file_results}->{'abc.t'}->{error}->{message},
           qr{Exit code},
           $json->{file_results}->{'abc.t'}->{error}->{message};
      ok $json->{file_results}->{'abc.t'}->{times}->{start};
      ok $json->{file_results}->{'abc.t'}->{times}->{start}
         < $json->{file_results}->{'abc.t'}->{times}->{end};
      ok $json->{file_results}->{'def.t'}->{result}->{ok};
      is $json->{file_results}->{'def.t'}->{result}->{exit_code}, 0;
      ok $json->{file_results}->{'def.t'}->{times}->{start};
      ok $json->{file_results}->{'def.t'}->{times}->{start}
         < $json->{file_results}->{'def.t'}->{times}->{end};
    } $c;
  });
} n => 20, name => ['one of specified files not readable'];

Test {
  my $c = shift;
  return run (
    files => {
      'abc' => {directory => 1, unreadable => 1},
      'def.t' => {perl_test => 1},
    },
    args => ['abc/x.t', 'def.t'],
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 'abc/x.t';
      is $json->{files}->[1]->{file_name_path}, 'def.t';
      is $json->{result}->{exit_code}, 1;
      ok ! $json->{result}->{ok};
      is $json->{result}->{fail}, 1;
      is $json->{result}->{pass}, 1;
      is 0+keys %{$json->{file_results}}, 2;
      ok ! $json->{file_results}->{'abc/x.t'}->{result}->{ok};
      is $json->{file_results}->{'abc/x.t'}->{result}->{exit_code}, undef;
      is $json->{file_results}->{'abc/x.t'}->{result}->{fail}, undef;
      is $json->{file_results}->{'abc/x.t'}->{result}->{pass}, undef;
      ok $json->{file_results}->{'abc/x.t'}->{times}->{start};
      is $json->{file_results}->{'abc/x.t'}->{times}->{start},
         $json->{file_results}->{'abc/x.t'}->{times}->{end};
      is $json->{file_results}->{'abc/x.t'}->{error}->{message},
         'Failed to read a file or directory',
         $json->{file_results}->{'abc/x.t'}->{error}->{message};
      ok $json->{file_results}->{'def.t'}->{result}->{ok};
      is $json->{file_results}->{'def.t'}->{result}->{exit_code}, 0;
      ok $json->{file_results}->{'def.t'}->{times}->{start};
      ok $json->{file_results}->{'def.t'}->{times}->{start}
         < $json->{file_results}->{'def.t'}->{times}->{end};
    } $c;
  });
} n => 20, name => ['one of specified files directory not readable'];

Test {
  my $c = shift;
  return run (
    files => {
      'abc' => {directory => 1, unreadable => 1},
      'def.t' => {perl_test => 1},
    },
    args => ['.'],
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $return->{result}->exit_code, 1;
      is 0+@{$json->{files}}, 2;
      is $json->{files}->[0]->{file_name_path}, 'abc';
      is $json->{files}->[1]->{file_name_path}, 'def.t';
      is $json->{result}->{exit_code}, 1;
      ok ! $json->{result}->{ok};
      is $json->{result}->{fail}, 1;
      is $json->{result}->{pass}, 1;
      is 0+keys %{$json->{file_results}}, 2;
      ok ! $json->{file_results}->{'abc'}->{result}->{ok};
      is $json->{file_results}->{'abc'}->{result}->{exit_code}, undef;
      is $json->{file_results}->{'abc'}->{result}->{fail}, undef;
      is $json->{file_results}->{'abc'}->{result}->{pass}, undef;
      ok $json->{file_results}->{'abc'}->{times}->{start};
      is $json->{file_results}->{'abc'}->{times}->{start},
         $json->{file_results}->{'abc'}->{times}->{end};
      like $json->{file_results}->{'abc'}->{error}->{message}, qr{^Perl I/O error: },
         $json->{file_results}->{'abc'}->{error}->{message};
      ok $json->{file_results}->{'def.t'}->{result}->{ok};
      is $json->{file_results}->{'def.t'}->{result}->{exit_code}, 0;
      ok $json->{file_results}->{'def.t'}->{times}->{start};
      ok $json->{file_results}->{'def.t'}->{times}->{start}
         < $json->{file_results}->{'def.t'}->{times}->{end};
      ok $json->{file_results}->{'def.t'}->{result}->{completed};
    } $c;
  });
} n => 21, name => ['one of directory not readable'];

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {bytes => 'print "ABC"'},
      't/def.t' => {bytes => 'print "DEF"'},
    },
    has_artifact_path => 1,
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{rule}->{base_dir}, $return->{base_path}->absolute->stringify;
      is $json->{rule}->{result_dir}, $return->{artifact_path}->absolute->stringify;
      is $json->{file_results}->{'t/abc.t'}->{output_file},
          'files/t_2Fabc_2Et.txt';
      is $json->{file_results}->{'t/def.t'}->{output_file},
          'files/t_2Fdef_2Et.txt';
      {
        my $f = $return->{result_file_bytes}->('t/abc.t');
        my $x = {1 => [], 2 => []};
        my $s = {1 => '', 2 => ''};
        while ($f =~ s{^\x0A&([12]) (-?[0-9]+) ([0-9]+\.[0-9]+)\x0A}{}) {
          push @{$x->{$1}}, $2;
          if ($2 >= 0) {
            $s->{$1} .= substr $f, 0, $x->{$1}->[-1];
            substr ($f, 0, $x->{$1}->[-1]) = '';
          }
        }
        is $f, '';
        is $s->{1}, "ABC";
        is $s->{2}, "";
        is $x->{1}->[-1], -1;
        is $x->{2}->[-1], -1;
      }
      {
        my $f = $return->{result_file_bytes}->('t/def.t');
        my $x = {1 => [], 2 => []};
        my $s = {1 => '', 2 => ''};
        while ($f =~ s{^\x0A&([12]) (-?[0-9]+) ([0-9]+\.[0-9]+)\x0A}{}) {
          push @{$x->{$1}}, $2;
          if ($2 >= 0) {
            $s->{$1} .= substr $f, 0, $x->{$1}->[-1];
            substr ($f, 0, $x->{$1}->[-1]) = '';
          }
        }
        is $f, '';
        is $s->{1}, "DEF";
        is $s->{2}, "";
        is $x->{1}->[-1], -1;
        is $x->{2}->[-1], -1;
      }
    } $c;
  });
} n => 14, name => ['artifacts'];

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
    } $c;
  });
} n => 10, name => 'skipped some';

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
      is $json->{file_results}->{'t/abc.t'}->{error}->{message}, 'Exit code 1';
      ok $json->{file_results}->{'t/abc.t'}->{error}->{ignored};
      is $json->{files}->[1]->{file_name_path}, 't/def.t';
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
      like $return->{stderr}, qr{FAIL \(ignored\)};
      like $return->{stderr}, qr{Allowed failures: 1};
    } $c;
  });
} n => 14, name => 'allow_failure some';

run_tests;

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
