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

## For fatpack
Promised::Command->load_modules;

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

sub set_result_rule ($) {
  my $result = $_[0];

  my $envs = $result->{rule}->{envs};
  if ($envs->{CI}) {
    if ($envs->{GITHUB_ACTIONS}) {
      $result->{rule}->{repo}->{url} = sprintf q<%s/%s>,
          $envs->{GITHUB_SERVER_URL}, $envs->{GITHUB_REPOSITORY}
          if defined $envs->{GITHUB_SERVER_URL} and
             defined $envs->{GITHUB_REPOSITORY};
      $result->{rule}->{repo}->{commit} = $envs->{GITHUB_SHA}
          if defined $envs->{GITHUB_SHA};
      $result->{rule}->{repo}->{branch} = $envs->{GITHUB_REF_NAME}
          if defined $envs->{GITHUB_REF_NAME} and
             defined $envs->{GITHUB_REF_TYPE} and
             $envs->{GITHUB_REF_TYPE} eq 'branch'; # or tag
      $result->{rule}->{ci}->{url} = sprintf q<%s/%s/actions/runs/%s>,
          $envs->{GITHUB_SERVER_URL}, $envs->{GITHUB_REPOSITORY},
          $envs->{GITHUB_RUN_ID}
          if defined $envs->{GITHUB_SERVER_URL} and
             defined $envs->{GITHUB_REPOSITORY} and
             defined $envs->{GITHUB_RUN_ID};
    } elsif ($envs->{DRONE}) {
      $result->{rule}->{repo}->{url} = $envs->{DRONE_REPO_LINK}
          if defined $envs->{DRONE_REPO_LINK};
      $result->{rule}->{repo}->{commit} = $envs->{DRONE_COMMIT_SHA}
          if defined $envs->{DRONE_COMMIT_SHA};
      $result->{rule}->{repo}->{branch} = $envs->{DRONE_COMMIT_BRANCH}
          if defined $envs->{DRONE_COMMIT_BRANCH};
      $result->{rule}->{ci}->{url} = $envs->{DRONE_BUILD_LINK}
          if defined $envs->{DRONE_BUILD_LINK};
    } elsif ($envs->{CIRCLECI}) {
      $result->{rule}->{repo}->{url} = $envs->{CIRCLE_REPOSITORY_URL}
          if defined $envs->{CIRCLE_REPOSITORY_URL};
      $result->{rule}->{repo}->{commit} = $envs->{CIRCLE_SHA1}
          if defined $envs->{CIRCLE_SHA1};
      $result->{rule}->{repo}->{branch} = $envs->{CIRCLE_BRANCH}
          if defined $envs->{CIRCLE_BRANCH};
      $result->{rule}->{ci}->{url} = $envs->{CIRCLE_BUILD_URL}
          if defined $envs->{CIRCLE_BUILD_URL};
    }
  }
} # set_result_rule

sub path_full ($) {
  my $path = shift;
  return eval { $path->realpath } || $path->absolute;
} # path_full

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
    if (not length $name) {
      push @$files, {path => path ($base),
                     file_name => '',
                     specified => $in_names->{$name},
                     time => time,
                     error => {
                       message => "File not found",
                     }};
      return;
    }
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

sub filter_files ($$) {
  my ($env, $in_files) = @_;

  my $skipped = {};
  if (ref $env->{manifest}->{skip} eq 'ARRAY') {
    for (@{$env->{manifest}->{skip}}) {
      my $path = path_full (length $_ ? path ($_)->absolute ($env->{manifest_base_path}) : $env->{manifest_base_path});
      $skipped->{$path} = 1;
    }
  }

  my $out_files = [];
  my $found = {};
  for my $file (@$in_files) {
    next if $found->{$file->{path}}++;
    if ($file->{error}) {
      push @$out_files, $file;
    } elsif ($skipped->{$file->{path}}) {
      $file->{error} = {message => 'Skipped by request', ignored => 1};
      push @$out_files, $file;
    } else {
      my $ext = undef;
      $ext = $1 if $file->{file_name} =~ /\.([^\.]+)\z/;
      my $xtype = $Ext2Executors->{$ext // ''};
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

  for (@$out_files) {
    $_->{file_name_path} = '' . $_->{path}->relative ($env->{base_dir_path});
  }
  
  my $pri = {};
  if (defined $env->{manifest}->{priority} and
      ref $env->{manifest}->{priority} eq 'ARRAY') {
    my $i = 0;
    for (reverse @{$env->{manifest}->{priority}}) {
      my $path = path_full (length $_ ? path ($_)->absolute ($env->{manifest_base_path}) : $env->{manifest_base_path});
      $pri->{$path} = ++$i;
    }
  }
  $out_files = [sort {
    ($pri->{$b->{path}} || 0) <=> ($pri->{$a->{path}} || 0) ||
    $a->{path} cmp $b->{path};
  } @$out_files];
  
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

sub start_log_watching ($$) {
  my ($env, $result) = @_;
  my @wait;

  if (ref $env->{manifest}->{entangled_log_files} eq 'ARRAY') {
    my $channel = 70000;
    for (@{$env->{manifest}->{entangled_log_files}}) {
      my $path = path ($_)->absolute ($env->{result_dir_path});

      my $el = {};
      $el->{file} = $path->relative ($env->{result_dir_path});
      my $ee = {onstdout => sub { }};
      $ee->{channel} = ++$channel;
      $result->{rule}->{entangled_logs}->{$ee->{channel}} = $el;

      $ee->{cmd} = Promised::Command->new (['tail', '-n', 0, '-F', $path]);
      $ee->{cmd}->propagate_signal (1);
      my $rs = $ee->{cmd}->get_stdout_stream;
      my $r = $rs->get_reader ('byob');
      $ee->{cmd}->stderr (\my $stderr);
      push @wait, my $run = $ee->{cmd}->run;
      my $ac = AbortController->new;
      my $wait = $ee->{cmd}->wait;
      $wait->catch (sub { $ac->abort });
      $ee->{closed} = promised_until {
        return $r->read (DataView->new (ArrayBuffer->new (1024)))->then (sub {
          if ($_[0]->{done}) {
            return 'done';
          }
          return $ee->{onstdout}->($_[0]->{value})->then (sub {
            return not 'done';
          });
        });
      } signal => $ac->signal;
      $ee->{discard} = sub {
        $ac->abort;
      };
      push @{$env->{tails}}, $ee;
    }
  }

  return Promise->all (\@wait);
} # start_log_watching

sub log_watching_failure ($$) {
  my ($env, $code) = @_;
  for my $ee (@{$env->{tails}}) {
    $ee->{cmd}->wait->catch ($code);
  }
  return undef;
} # log_watching_failure

sub stop_log_watching ($$) {
  my ($env, $result) = @_;
  my @wait;

  for my $ee (@{$env->{tails}}) {
    $ee->{cmd}->send_signal ('TERM');
    push @wait, $ee->{cmd}->wait, $ee->{closed};
    (delete $ee->{discard})->() if defined $ee->{discard};
  }

  return Promise->all ([map { $_->catch (sub { }) } @wait]);
} # stop_log_watching

sub run_command ($%) {
  my ($env, %args) = @_;

  my $try = 0;
  return promised_until {
    $try++;
    my $need_retry = 0;

      my $output_path = $args{before_try}->($try);

      my $cmd = Promised::Command->new ($args{command});
      $cmd->envs->{CIRCLE_ARTIFACTS} = $env->{result_dir_path};
      
      my $output_ws = Promised::File->new_from_path
          ($output_path)->write_bytes;
      my $output_w = $output_ws->get_writer;
      my $output_line_count = 0;
      my $output_chunk = sub {
        my ($h, $chunk) = @_;
        $output_line_count++;
        if ($output_line_count < 10) {
          print STDERR ".";
        } elsif ($output_line_count < 100 and $output_line_count % 10 == 0) {
          print STDERR ":";
        } elsif ($output_line_count < 1000 and $output_line_count % 100 == 0) {
          print STDERR "+";
        } elsif ($output_line_count % 1000 == 0) {
          print STDERR "*";
        }
        my $v = sprintf "\x0A&%d %d %.9f\x0A",
            $h,
            $chunk->byte_length,
            time;
        $output_w->write
            (DataView->new (ArrayBuffer->new_from_scalarref (\$v)));
        return $output_w->write ($chunk);
      }; # output_chunk
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
      if ($args{with_tails}) {
      for my $ee (@{$env->{tails}}) {
        $ee->{onstdout} = sub {
          $output_chunk->($ee->{channel}, $_[0]);
        };
      }
    } # with_tails
      return $cmd->run->then (sub {
        return $cmd->wait;
      })->then (sub {
        my $cr = $_[0];
        $args{pass}->($try, $cr); # or die
      })->catch (sub {
        my $e = $_[0];
        if ($args{fail}->($try, $e)) {
          $need_retry = 1;
          return;
        }
      })->finally (sub {
                     if ($args{with_tails}) {
        for my $ee (@{$env->{tails}}) {
          $ee->{onstdout} = sub { };
        }
      }
        return Promise->all (\@wait);
      })->finally (sub {
        return $output_w->close;
      })->then (sub {
        $env->{write_result}->();
        return not $need_retry;
      });
    };
} # run_command

sub process_files ($$$) {
  my ($env, $file_paths, $result) = @_;

  my $failure_allowed = {};
  if (ref $env->{manifest}->{allow_failure} eq 'ARRAY') {
    for (@{$env->{manifest}->{allow_failure}}) {
      my $path = path_full (length $_ ? path ($_)->absolute ($env->{manifest_base_path}) : $env->{manifest_base_path});
      $failure_allowed->{$path} = 1;
    }
  }

  my $max_cfailure_count = 0+($env->{manifest}->{max_consecutive_failures} || 0);
  $max_cfailure_count = 0 unless $max_cfailure_count > 0;
  $result->{rule}->{max_consecutive_failures} = $max_cfailure_count
      if $max_cfailure_count;

  my $max_retry_count = 0+($env->{manifest}->{max_retries} || 0);
  $max_retry_count = 0 unless $max_retry_count > 0;
  $result->{rule}->{max_retries} = $max_retry_count;

  my $count = 0+@$file_paths;
  my $n = 0;
  my $cfailure_count = 0;
  return promised_for {
    my $file = shift;
    my $file_name = $file->{path}->relative ($env->{base_dir_path});
    my $fr = $result->{file_results}->{$file_name} = {
      result => {ok => 0},
      times => {start => time},
    };

    $fr->{executor} = $file->{executor};

    $n++;
    if ($file->{error}) {
      $fr->{times}->{end} = $fr->{times}->{start} = $file->{time};
      $fr->{error} = $file->{error};
      if ($file->{error}->{message} eq 'Skipped by request') {
        $result->{result}->{skipped}++;
      } else {
        $result->{result}->{fail}++;
      }
      return;
    }

    if (($max_cfailure_count and $cfailure_count > $max_cfailure_count) or
        $env->{terminate}) {
      $fr->{times}->{end} = $fr->{times}->{start} = $file->{time};
      $fr->{error} = {message => 'Too many failures before this test'};
      $result->{result}->{skipped}++;
      return;
    }
    
    #$fr->{executor}->{type} eq 'perl'
    my $xenv = $env->{executors}->{$fr->{executor}->{type}};
    return run_command (
      $env,
      command => [
        @{$xenv->{perl_command}},
        $file->{path},
      ],
      with_tails => 1,
      before_try => sub {
        my ($try) = @_;
      if ($try > 1) {
        printf STDERR "%d/%d [%s] |%s| (retry %d/%s)...",
            $n, $count, $fr->{executor}->{type}, $file_name,
            $try-1, $max_retry_count;
        my $list;
        if ($try == 2) {
          $list = [$fr];
        } else {
          $list = delete $fr->{tries};
          push @$list, $fr;
        }
        $fr = $result->{file_results}->{$file_name} = {
          result => {ok => 0},
          times => {start => time},
          tries => $list,
          executor => $fr->{executor},
        };
      } else { # first time
        printf STDERR "(Pass: %d, Fail: %d)\n",
            $result->{result}->{pass},
            $result->{result}->{fail}
            if ($n % 10) == 0;
        printf STDERR "%d/%d [%s] |%s|...",
            $n, $count, $fr->{executor}->{type}, $file_name;
      }

        my $escaped_name = $file_name;
        $escaped_name =~ s{([^A-Za-z0-9])}{sprintf '_%02X', ord $1}ge;
      my $output_path = $env->{result_dir_path}->child ('files');
      if ($try > 1) {
        $output_path = $output_path->child
            ($escaped_name . '-' . $try . '.txt');
      } else {
        $output_path = $output_path->child ($escaped_name . '.txt');
      }
      $fr->{output_file} = ''.$output_path->relative ($env->{result_dir_path});

        return $output_path;
      }, # before_try
      pass => sub {
        my ($try, $cr) = @_;
        $fr->{times}->{end} = time;
        $fr->{result}->{exit_code} = $cr->exit_code;
        die $cr unless $cr->exit_code == 0;
        $fr->{result}->{ok} = 1;
        $fr->{result}->{completed} = 1;
        $result->{result}->{pass}++;
        if ($try > 1) {
          $result->{result}->{pass_after_retry}++;
        }
        warn sprintf " pass (%d s)\n",
            $fr->{times}->{end} - $fr->{times}->{start};
        $cfailure_count = 0;
      }, # pass
      fail => sub {
        my ($try, $e) = @_;
        $fr->{times}->{end} //= time;
        $fr->{error}->{message} = ''.$e;
        $fr->{result}->{completed} = 1;
        if ($failure_allowed->{$file->{path}}) {
          $result->{result}->{pass}++;
          $result->{result}->{failure_ignored}++;
          $fr->{error}->{ignored} = 1;
          warn sprintf " FAIL (%d s, ignored)\n",
              $fr->{times}->{end} - $fr->{times}->{start};
        } else {
          warn sprintf " FAIL (%d s)\n",
              $fr->{times}->{end} - $fr->{times}->{start};
          if ($try > $max_retry_count) {
            $result->{result}->{fail}++;
          } else {
            return 1; # failure, need retry
          }
        }
        $cfailure_count++;
        return 0; # permanent failure, no retry
      }, # fail
    );
  } $file_paths;
} # process_files

sub run_before ($$) {
  my ($env, $result) = @_;
  return unless (defined $env->{manifest}->{before} and
                 ref $env->{manifest}->{before} eq 'ARRAY');
  my $failed = 0;
  return Promise->resolve->then (sub {
    my $i = 0;
    return promised_for {
      my $e = (defined $_[0] and ref $_[0] eq 'HASH') ? $_[0] : {run => $_[0]};
      unless (defined $e->{run} and ref $e->{run} eq 'ARRAY') {
        $e->{run} = ['bash', '-c', $e->{run}];
      }

      my $escaped_name = "before-".$i++;
      my $fr = $result->{other_results}->{$escaped_name} = {
        type => 'before',
        result => {ok => 0},
        times => {start => time},
        run => $e->{run},
      };

      if ($failed) {
        $fr->{times}->{end} = $fr->{times}->{start};
        $fr->{error} = {message => 'Failed before this test'};
        return;
      }

      return run_command (
        $env,
        command => $e->{run},
        before_try => sub {
          my $output_path = $env->{result_dir_path}->child ('files')->child ($escaped_name . '.txt');
          $fr->{output_file} = ''.$output_path->relative ($env->{result_dir_path});
          return $output_path;
        }, # before_try
        pass => sub {
          my ($try, $cr) = @_;
          $fr->{times}->{end} = time;
          $fr->{result}->{exit_code} = $cr->exit_code;
          die $cr unless $cr->exit_code == 0;
          $fr->{result}->{ok} = 1;
          $fr->{result}->{completed} = 1;
        }, # pass
        fail => sub {
          my ($try, $e) = @_;
          $fr->{times}->{end} //= time;
          $fr->{error}->{message} = ''.$e;
          $fr->{result}->{completed} = 1;
          $failed = 1;
          return 0; # permanent failure, no retry
        }, # fail
      );
    } $env->{manifest}->{before};
  })->then (sub {
    return unless $failed;
    die "|before| command failed\n";
  });
} # run_before

sub main ($@) {
  my ($class, @args) = @_;
  my @wait;
  
  my $rule = {};
  my $env = {executors => {}, write_result => sub { },
             manifest => {}, tails => []};

  my $result = {result => {exit_code => 1, pass => 0, fail => 0,
                           skipped => 0, failure_ignored => 0,
                           pass_after_retry => 0},
                rule => {entangled_logs => {}},
                times => {start => time},
                file_results => {}, executors => {}};

  $result->{rule}->{envs} = {%ENV};
  
  return Promise->resolve->then (sub {
    set_result_rule $result;
  })->then (sub {
    my $manifest_file_name = $result->{rule}->{envs}->{TESICA_MANIFEST_FILE} // '';
    return unless length $manifest_file_name;

    my $manifest_path = path_full path ($manifest_file_name);
    $result->{rule}->{manifest_file} = $manifest_path . '';
    my $manifest_file = Promised::File->new_from_path ($manifest_path);
    return $manifest_file->read_byte_string->then (sub {
      my $json = json_bytes2perl $_[0];
      unless (defined $json and ref $json eq 'HASH') {
        die "Manifest file |$manifest_path| is not a JSON object\n";
      }
      $env->{manifest} = $json;
      $env->{manifest_base_path} = $manifest_path->parent;
    });
  })->then (sub {
    $rule->{base_dir} = '.' unless defined $rule->{base_dir};
    $env->{base_dir_path} = path_full path ($rule->{base_dir});
    $result->{rule}->{base_dir} = '' . $env->{base_dir_path};

    my $ca = $result->{rule}->{envs}->{CIRCLE_ARTIFACTS} // '';
    if (length $ca) {
      $env->{result_dir_path} = path_full path ($ca);
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
    return filter_files $env, $files;
  })->then (sub {
    my $files = $_[0];
    $result->{files} = [map {
      $env->{executors}->{$_->{executor}->{type}} = {} if defined $_->{executor};
      {file_name_path => $_->{file_name_path}};
    } @$files];
    return Promise->resolve->then (sub {
      return run_before ($env, $result);
    })->then (sub {
      return load_executors ($env, $result);
    })->then (sub {
      return start_log_watching ($env, $result);
    })->then (sub {
      $env->{write_result}->();
      warn sprintf "Result: |%s|\n",
          $env->{result_json_path};

      ## Capture rare error cases
      log_watching_failure ($env, sub {
        my $e = $_[0];
        $env->{terminate} = 1;
        $env->{global_error} //= $e;
        #XXX abort current test?
      });

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
    die $env->{global_error} if defined $env->{global_error};
  })->catch (sub {
    my $error = $_[0];
    $result->{result}->{error} = '' . $error;
    $result->{result}->{exit_code} = 1;
    $result->{result}->{completed} = 1;
    warn "ERROR: $error\n";
  })->then (sub {
    $result->{times}->{end} = time;
    return $env->{write_result}->();
  })->finally (sub {
    push @wait, stop_log_watching ($env, $result);
    return undef;
  })->then (sub {
    {
      my $files = [];
      my $afs = [];
      for my $name (keys %{$result->{file_results}}) {
        my $fr = $result->{file_results}->{$name};
        if (not $fr->{result}->{ok} and
            not $fr->{error}->{ignored} and
            not $fr->{error}->{message} eq 'Too many failures before this test') {
          push @$files, $name;
        } elsif (not $fr->{result}->{ok} and
                 $fr->{error}->{ignored}) {
          push @$afs, $name;
        }
      }
      if (@$afs) {
        warn "Failure-ignored tests:\n";
        warn join '', map { "  |$_|\n" } sort { $a cmp $b } @$afs;
      }
      if (@$files) {
        warn "Failed tests:\n";
        warn join '', map { "  |$_|\n" } sort { $a cmp $b } @$files;
      }
    }
    warn sprintf "Result: |%s|\n",
        $env->{result_json_path} if defined $env->{result_json_path};
    warn sprintf "Pass: %d, Fail: %d, Skipped: %d (%d s)\n",
        $result->{result}->{pass},
        $result->{result}->{fail},
        $result->{result}->{skipped},
        $result->{times}->{end} - $result->{times}->{start};
    if ($result->{result}->{failure_ignored} or
        $result->{result}->{pass_after_retry}) {
      warn sprintf "(Passed after retry: %d, Allowed failures: %d)\n",
          $result->{result}->{pass_after_retry},
          $result->{result}->{failure_ignored};
    }
    if ($result->{result}->{exit_code} == 0) {
      warn "Test passed\n";
    } else {
      warn "Test failed\n";
    }
    return $result;
  })->finally (sub {
    return Promise->all (\@wait);
  })->finally (sub {
    for my $ee (@{$env->{tails}}) {
      %$ee = ();
    }
  });
} # main

1;

=head1 LICENSE

Copyright 2018-2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
