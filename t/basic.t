use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::More;
use Test::X1;
use File::Temp;
use Promise;
use Promised::Flow;
use Promised::File;
use Promised::Command;
use JSON::PS;

sub run (%) {
  my %args = @_;
  
  my $RootPath = path (__FILE__)->parent->parent;

  my $temp = File::Temp->newdir;
  my $temp_path = path ($temp);
  
  my $cmd = Promised::Command->new ([
    $RootPath->child ('perl')->absolute,
    $RootPath->child ('bin/tesica.pl')->absolute,
  ]);
  $cmd->wd ($temp_path);

  my $files = $args{files} || {};
  return Promise->resolve->then (sub {
    return promised_for {
      my $name = $_[0];
      my $path = $temp_path->child ($name);
      my $file = Promised::File->new_from_path ($path);
      my $def = $files->{$name};
      my $data = '';
      if (defined $def->{bytes}) {
        $data = $def->{bytes};
      } elsif ($def->{perl_test}) {
        if ($def->{perl_test} eq 'ok') {
          $data = 'exit 0';
        } elsif ($def->{perl_test} eq 'ng') {
          $data = 'exit 1';
        } else {
          #
        }
      }
      return $file->write_byte_string ($data);
    } [keys %$files];
  })->then (sub {
    return $cmd->run;
  })->then (sub {
    return $cmd->wait;
  })->then (sub {
    my $result = $_[0];
    my $return = {
      result => $result,
      base_path => $temp_path, _temp => $temp,
      file_bytes => sub {
        return path ($_[0])->absolute ($temp_path)->slurp;
      },
    };
    
    my $json_path = $temp_path->child ('local/test/result.json');
    my $json_file = Promised::File->new_from_path ($json_path);
    return $json_file->read_byte_string->then (sub {
      my $json = json_bytes2perl $_[0];
      $return->{json} = $json;
    }, sub {
      #
    })->then (sub { return $return });
  });
} # run

sub Test (&;%) {
  my $code = shift;
  my %args = @_;
  test {
    my $c = shift;
    Promise->resolve ($c)->then ($code)->catch (sub {
      my $e = $_[0];
      test {
        ok 0, 'No exception';
        is $e, undef;
      } $c;
    })->then (sub {
      done $c;
      undef $c;
    });
  } %args;
} # Test

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
      is $json->{rule}->{type}, 'perl';
      is $json->{rule}->{base_dir}, $return->{base_path}->absolute->stringify;
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{json_file}, 'local/test/result.json';
      is 0+@{$json->{files}}, 1;
      is $json->{files}->[0], 't/abc.t';
    } $c;
  });
} n => 7, name => 'No arguments';

for (
  [{
    't/abc.t' => {perl_test => 1},
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
        is $json->{rule}->{type}, 'perl';
        is join ($;, @{$json->{files}}),
           join ($;, @$expected);
        ok $json->{times}->{start};
        ok $json->{times}->{end};
        ok $json->{times}->{start} < $json->{times}->{end};
      } $c;
    });
  } n => 7, name => ['files', @$expected];
}

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
    } $c;
  });
} n => 7, name => ['success'];

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
    } $c;
  });
} n => 10, name => ['success and failure'];

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
    } $c;
  });
} n => 10, name => ['fails'];

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {bytes => 'print STDOUT "abc\x0A"'},
      't/def.t' => {bytes => 'print STDERR "xyz\x0AAAA"'},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{file_results}->{'t/abc.t'}->{output_file},
          'local/test/files/t_2Fabc_2Et.txt';
      is $json->{file_results}->{'t/def.t'}->{output_file},
          'local/test/files/t_2Fdef_2Et.txt';
      is $return->{file_bytes}->('local/test/files/t_2Fabc_2Et.txt'), "abc\x0A";
      is $return->{file_bytes}->('local/test/files/t_2Fdef_2Et.txt'), "xyz\x0AAAA";
    } $c;
  });
} n => 4, name => ['test output result files'];

run_tests;

=head1 LICENSE

Copyright 2018-2019 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
