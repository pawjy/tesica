package Main;
use strict;
use warnings;
use Path::Tiny;
use Time::HiRes qw(time);
use ArrayBuffer;
use DataView;
use Promise;
use Promised::Flow;
use Promised::File;
use Promised::Command;
use JSON::PS;

my $Executors = {
  perl => {
    exts => [qw(t)],
  },
}; # $Executors
my $Ext2Executors = {};
for my $xtype (sort { $a cmp $b } keys %$Executors) {
  for (@{$Executors->{$xtype}->{exts} or []}) {
    $Ext2Executors->{$_} = $xtype;
  }
}

sub _files ($$$$);
sub _files ($$$$) {
  my ($base, $names, $files, $is_sub) = @_;
  my $in_names = {};
  if (not $is_sub) {
    $in_names->{$_} = 1 for @$names;
  }
  my $files2 = [];
  return ((promised_for {
    my $name = $_[0];
    my $path = path ($name)->absolute ($base);
    my $file = Promised::File->new_from_path ($path);
    return $file->is_file->then (sub {
      if ($_[0]) {
        push @$files, {path => $path, file_name => $name,
                       specified => $in_names->{$name}};
      } else {
        return $file->is_directory->then (sub {
          if ($_[0]) {
            return $file->get_child_names->then (sub {
              return _files $path, [sort { $a cmp $b } @{$_[0]}], $files2, 1;
            }, sub {
              my $e = shift;
              my $msg;
              if (UNIVERSAL::can ($e, 'message')) {
                if (UNIVERSAL::can ($e, 'name')) {
                  $msg = $e->name . ': ' . $e->message;
                } else {
                  $msg = '' . $e->message;
                }
              } else {
                $msg = '' . $e;
              }
              push @$files, {path => $path,
                             file_name => $name,
                             specified => $in_names->{$name},
                             time => time,
                             error => {
                               message => $msg,
                             }};
            });
          } else {
            push @$files, {path => $path,
                           file_name => $name,
                           specified => $in_names->{$name},
                           time => time,
                           error => {
                             message => "Failed to read a file or directory",
                           }};
          }
        });
      }
    });
  } $names)->then (sub {
    push @$files, @$files2;
  }));
} # _files

sub expand_files ($$) {
  my ($rule, $args) = @_;

  if (@$args) {
    $rule->{files} = $args;
  }

  unless (defined $rule->{files} and
          ref $rule->{files} eq 'ARRAY') {
    ## Default for Perl
    $rule->{files} = ['t'];
  }

  my $files = [];
  return _files ($rule->{base_dir}, $rule->{files}, $files, 0)->then (sub {
    return $files;
  });
} # expand_files

sub filter_files ($) {
  my $in_files = shift;
  my $out_files = [];
  my $found = {};
  for my $file (@$in_files) {
    next if $found->{$file->{path}}++;
    if ($file->{error}) {
      push @$out_files, $file;
    } else {
      my $ext = undef;
      $ext = $1 if $file->{file_name} =~ /\.([^\.]+)\z/;
      my $xtype = $Ext2Executors->{$ext};
      if (defined $xtype) {
        $file->{executor} = {type => $xtype};
        push @$out_files, $file;
      } else {
        if ($file->{specified}) {
          $file->{error} = {message => "No test executor found"};
          push @$out_files, $file;
        }
      }
    }
  }
  $out_files = [sort { $a->{path} cmp $b->{path} } @$out_files];
  return $out_files;
} # filter_files

sub load_executors ($$) {
  my ($env, $result) = @_;
  return promised_for {
    my $xtype = shift;
    my $xenv = $env->{executors}->{$xtype};
    if ($xtype eq 'perl') {
      my $perl_path = $env->{base_dir_path}->child ('perl');
      my $perl_file = Promised::File->new_from_path ($perl_path);
      return $perl_file->is_executable->then (sub {
        if ($_[0]) {
          $xenv->{perl_command} = [$perl_path->absolute];
        } else {
          $xenv->{perl_command} = ['perl'];
        }
        $result->{executors}->{$xtype}->{perl_command} = [map { '' . $_ } @{$xenv->{perl_command}}];
      });
    } # $xtype
  } [keys %{$env->{executors}}];
} # load_executors

sub process_files ($$$) {
  my ($env, $file_paths, $result) = @_;

  my $count = 0+@$file_paths;
  my $n = 1;
  return promised_for {
    my $file = shift;
    my $file_name = $file->{path}->relative ($env->{base_dir_path});
    my $fr = $result->{file_results}->{$file_name} = {
      result => {ok => 0},
      times => {start => time},
    };

    if ($file->{error}) {
      $fr->{times}->{end} = $fr->{times}->{start} = $file->{time};
      $fr->{error} = $file->{error};
      $result->{result}->{fail}++;
      return;
    }

    $fr->{executor} = $file->{executor};

    print STDERR "$n/$count [$fr->{executor}->{type}] $file_name...";
    $n++;

    #$fr->{executor}->{type} eq 'perl'
    my $xenv = $env->{executors}->{$fr->{executor}->{type}};

    my $cmd = Promised::Command->new ([
      @{$xenv->{perl_command}},
      $file->{path},
    ]);

    my $escaped_name = $file_name;
    $escaped_name =~ s{([^A-Za-z0-9])}{sprintf '_%02X', ord $1}ge;
    my $output_path = $env->{result_dir_path}->child ('files')
        ->child ($escaped_name . '.txt');
    $fr->{output_file} = '' . $output_path->relative ($env->{result_dir_path});
    my $output_ws = Promised::File->new_from_path ($output_path)->write_bytes;
    my $output_w = $output_ws->get_writer;
    my $output_chunk = sub {
      my ($h, $chunk) = @_;
      print STDERR ".";
      my $v = sprintf "\x0A&%d %d %.9f\x0A",
          $h,
          $chunk->byte_length,
          time;
      $output_w->write (DataView->new (ArrayBuffer->new_from_scalarref (\$v)));
      return $output_w->write ($chunk);
    };
    my $closed = sub {
      my ($h) = @_;
      my $v = sprintf "\x0A&%d -1 %.9f\x0A",
          $h,
          time;
      return $output_w->write (DataView->new (ArrayBuffer->new_from_scalarref (\$v)));
    };
    my @wait;
    my $so_rs = $cmd->get_stdout_stream;
    my $so_r = $so_rs->get_reader ('byob');
    push @wait, promised_until {
      return $so_r->read (DataView->new (ArrayBuffer->new (1024)))->then (sub {
        if ($_[0]->{done}) {
          push @wait, $closed->(1);
          return 'done';
        }
        return $output_chunk->(1, $_[0]->{value})->then (sub {
          return not 'done';
        });
      });
    };
    my $se_rs = $cmd->get_stderr_stream;
    my $se_r = $se_rs->get_reader ('byob');
    push @wait, promised_until {
      return $se_r->read (DataView->new (ArrayBuffer->new (1024)))->then (sub {
        if ($_[0]->{done}) {
          push @wait, $closed->(2);
          return 'done';
        }
        return $output_chunk->(2, $_[0]->{value})->then (sub {
          return not 'done';
        });
      });
    };
    return $cmd->run->then (sub {
      return $cmd->wait;
    })->then (sub {
      my $cr = $_[0];
      $fr->{times}->{end} = time;
      $fr->{result}->{exit_code} = $cr->exit_code;
      die $cr unless $cr->exit_code == 0;
      $fr->{result}->{ok} = 1;
      $fr->{result}->{completed} = 1;
      $result->{result}->{pass}++;
      warn " PASS\n";
    })->catch (sub {
      my $e = $_[0];
      $fr->{times}->{end} //= time;
      $fr->{error}->{message} = ''.$e;
      $fr->{result}->{completed} = 1;
      $result->{result}->{fail}++;
      warn " FAIL\n";
    })->finally (sub {
      return $output_w->close;
    })->finally (sub {
      return Promise->all (\@wait);
    })->then (sub {
      $env->{write_result}->();
      return undef;
    });
  } $file_paths;
} # process_files

sub main ($@) {
  my ($class, @args) = @_;
  
  my $rule = {};
  my $env = {executors => {}};

  my $result = {result => {exit_code => 1, pass => 0, fail => 0},
                times => {start => time},
                file_results => {}, executors => {}};
  
  return Promise->resolve->then (sub {
    $rule->{base_dir} = '.' unless defined $rule->{base_dir};
    $env->{base_dir_path} = path ($rule->{base_dir})->absolute;
    $result->{rule}->{base_dir} = '' . $env->{base_dir_path};

    my $ca = $ENV{CIRCLE_ARTIFACTS} // '';
    if (length $ca) {
      $env->{result_dir_path} = path ($ca)->absolute;
    } else {
      $env->{result_dir_path} = $env->{base_dir_path}->child ('local/test');
    }
    $result->{rule}->{result_dir} = '' . $env->{result_dir_path};

    $env->{result_json_path} = $env->{result_dir_path}->child ('result.json');
    $result->{result}->{json_file} = '' . $env->{result_json_path}->relative ($env->{result_dir_path});
    my $result_json_file = Promised::File->new_from_path
        ($env->{result_json_path});
    $env->{write_result} = sub {
      $result->{times}->{now} = time;
      return $result_json_file->write_byte_string (perl2json_bytes $result);
    }; # write_result

    return expand_files $rule, \@args;
  })->then (sub {
    my $files = $_[0];
    return filter_files $files;
  })->then (sub {
    my $files = $_[0];
    $result->{files} = [map {
      $env->{executors}->{$_->{executor}->{type}} = {} if defined $_->{executor};
      {file_name_path => '' . $_->{path}->relative ($env->{base_dir_path})};
    } @$files];
    return load_executors ($env, $result)->then (sub {
      $env->{write_result}->();
      return process_files $env, $files => $result;
    });
  })->then (sub {
    if ($result->{result}->{fail}) {
      #$result->{result}->{exit_code} = 1;
    } else {
      $result->{result}->{exit_code} = 0;
      $result->{result}->{ok} = 1;
    }
    $result->{result}->{completed} = 1;
  })->catch (sub {
    my $error = $_[0];
    $result->{result}->{error} = '' . $error;
    $result->{result}->{exit_code} = 1;
    $result->{result}->{completed} = 1;
    warn "ERROR: $error\n";
  })->then (sub {
    $result->{times}->{end} = time;
    return $env->{write_result}->();
  })->then (sub {
    warn sprintf "Result: |%s|\n",
        $env->{result_json_path};
    warn sprintf "Pass: %d, Fail: %d\n",
        $result->{result}->{pass}, $result->{result}->{fail};
    if ($result->{result}->{exit_code} == 0) {
      warn "Test passed\n";
    } else {
      warn "Test failed\n";
    }
    return $result;
  });
} # main

1;

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
