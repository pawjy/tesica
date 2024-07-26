package Tests;
use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('modules/*/lib');
use Carp;
use Time::HiRes qw(time);
use Test::More;
use Test::X1;
use File::Temp;
use Promise;
use Promised::Flow;
use Promised::File;
use Promised::Command;
use Web::Encoding;
use JSON::PS;

our @EXPORT = (
  @Test::X1::EXPORT,
  (grep { not /^\$/ } @Test::More::EXPORT),
  @JSON::PS::EXPORT,
  @Web::Encoding::EXPORT,
  @Web::URL::Encoding::EXPORT,
  @Promised::Flow::EXPORT,
  'time',
);

push our @CARP_NOT, qw(Test::X1);

my $RootPath = path (__FILE__)->parent->parent->parent;

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

push @EXPORT, qw(run);
sub run (%) {
  my %args = @_;

  my $temps = [];
  my $get_temp_path = sub {
    my $temp = File::Temp->newdir (CLEANUP => !$ENV{TEST_NO_CLEANUP});
    push @$temps, $temp;
    return path ($temp);
  };
  my $temp_path = $get_temp_path->();

  my $tesica = [
    $RootPath->child ('perl')->absolute,
    $RootPath->child ('bin/tesica.pl')->absolute,
  ];
  if ($ENV{TEST_COMPILED_TESICA}) {
    $tesica = [$RootPath->child ('tesica')->absolute];
  }
  
  my $cmd = Promised::Command->new ([
    @$tesica,
    @{$args{args} or []},
  ]);
  $cmd->wd ($temp_path);

  my $artifact_path;
  $cmd->envs->{CIRCLE_ARTIFACTS} = '';
  if ($args{has_artifact_path}) {
    $cmd->envs->{CIRCLE_ARTIFACTS} = $artifact_path = $get_temp_path->();
  }
  
  $cmd->envs->{TESICA_MANIFEST_FILE} = '';
  if ($args{manifest}) {
    $cmd->envs->{TESICA_MANIFEST_FILE} = $temp_path->child ($args{manifest});
  }

  for my $n (keys %{$args{envs} or {}}) {
    $cmd->envs->{$n} = $args{envs}->{$n};
  }

  $cmd->stdout (\my $stdout);
  $cmd->stderr (\my $stderr);

  my $files = $args{files} || {};
  return Promise->resolve->then (sub {
    return promised_for {
      my $name = $_[0];
      my $path = $temp_path->child ($name);
      my $file = Promised::File->new_from_path ($path);
      my $def = $files->{$name};
      return Promise->resolve->then (sub {
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
        } elsif ($def->{json}) {
          $data = perl2json_bytes $def->{json};
        } elsif ($def->{directory}) {
          return $file->mkpath;
        }
        return $file->write_byte_string ($data);
      })->then (sub {
        return unless $def->{executable};
        my $cmd = Promised::Command->new ([
          'chmod', 'u+x', $path,
        ]);
        return $cmd->run->then (sub {
          return $cmd->wait;
        })->then (sub {
          my $result = $_[0];
          die $result unless $result->exit_code == 0;
        });
      })->then (sub {
        return unless $def->{unreadable};
        my $cmd = Promised::Command->new ([
          'chmod', '-r', $path,
        ]);
        return $cmd->run->then (sub {
          return $cmd->wait;
        })->then (sub {
          my $result = $_[0];
          die $result unless $result->exit_code == 0;
        });
      });
    } [keys %$files];
  })->then (sub {
    return $cmd->run;
  })->then (sub {
    if ($args{kill_after}) {
      promised_sleep ($args{kill_after})->then (sub {
        $cmd->send_signal ('TERM');
      });
    }
    return $cmd->wait;
  })->catch (sub {
    my $e = $_[0];
    return $e;
  })->then (sub {
    my $result = $_[0];
    my $return = {
      result => $result,
      base_path => $temp_path,
      artifact_path => $artifact_path, # or undef
      _temp => $temps,
      stdout => $stdout,
      stderr => $stderr,
    };
    if ($ENV{TEST_SHOW_OUTPUT}) {
      warn "STDOUT:\n";
      warn $stdout;
      warn "STDERR:\n";
      warn $stderr;
      warn "Result: $result\n";
    }

    $return->{file_bytes} = sub {
      my $base_path = path ($return->{json}->{rule}->{result_dir});
      return path ($_[0] // die)->absolute ($base_path)->slurp;
    };

    $return->{file_out} = sub {
      my $channel = shift;
      my $base_path = path ($return->{json}->{rule}->{result_dir});
      my $bytes = path ($_[0] // die)->absolute ($base_path)->slurp;
      my @r;
      while ($bytes =~ s/^\x0A&([0-9]+) (-?[0-9]+) ([0-9.]+)\x0A//) {
        my ($ch, $size, $time) = ($1, $2, $3);
        if ($ch == $channel) {
          last if $size == -1;
          push @r, substr $bytes, 0, $size;
          substr ($bytes, 0, $size) = '';
        }
      }
      return join '', @r;
    };

    $return->{result_file_bytes} = sub {
      my $name = $return->{json}->{file_results}->{$_[0] // die "Bad argument"}->{output_file} // die "File not found";
      return $return->{file_bytes}->($name);
    };
    
    my $json_path = defined $return->{artifact_path}
        ? $return->{artifact_path}->child ('result.json')
        : $temp_path->child ('local/test/result.json');
    my $json_file = Promised::File->new_from_path ($json_path);
    return $json_file->read_byte_string->then (sub {
      my $json = json_bytes2perl $_[0];
      $return->{json} = $json;
    }, sub {
      #
    })->then (sub { return $return });
  });
} # run

push @EXPORT, qw(Test);
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

=head1 LICENSE

Copyright 2018-2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
