use strict;
use warnings;
use Path::Tiny;
use Time::HiRes qw(time);
use Promise;
use Promised::Flow;
use Promised::File;
use JSON::PS;

sub _files ($$$$$);
sub _files ($$$$$) {
  my ($base, $names, $name_pattern, $next_name_pattern, $files) = @_;
  return promised_for {
    my $name = $_[0];
    my $path = path ($name)->absolute ($base);
    my $file = Promised::File->new_from_path ($path);
    return $file->is_file->then (sub {
      if ($_[0]) {
        push @$files, $path if $name =~ /$name_pattern/;
      } else {
        return $file->is_directory->then (sub {
          if ($_[0]) {
            return $file->get_child_names->then (sub {
              return _files $path, [sort { $a cmp $b } @{$_[0]}], $next_name_pattern, $next_name_pattern, $files;
            });
          } else {
            die "|$path| is not a test script\n";
          }
        });
      }
    });
  } $names;
} # _files

sub expand_files ($) {
  my $rule = $_[0];

  unless (defined $rule->{files} and
          ref $rule->{files} eq 'ARRAY') {
    $rule->{files} = ['t'];
  }

  my $files = [];
  return _files ($rule->{base_dir}, $rule->{files}, qr/./, qr/\.t\z/, $files)->then (sub {
    return $files;
  });
} # expand_files

sub main () {
  my $rule;
  my $result = {result => {exit_code => 1}, times => {start => time}};
  return Promise->resolve->then (sub {
    $rule = {
      type => 'perl',
      result_json_file => 'local/test/result.json',
    };
    $rule->{base_dir} = '.' unless defined $rule->{base_dir};
    $result->{rule}->{base_dir} = path ($rule->{base_dir})->absolute;
    $result->{rule}->{type} = $rule->{type};
    my $result_json_path = path ($rule->{result_json_file})->absolute
        ($result->{rule}->{base_dir});
    $result->{result}->{json_file} = $result_json_path->absolute;

    return expand_files $rule;
  })->then (sub {
    $result->{files} = $_[0];
    
    $result->{result}->{exit_code} = 0;
  })->catch (sub {
    my $error = $_[0];
    $result->{result}->{error} = '' . $error;
    $result->{result}->{exit_code} = 1;
    warn "ERROR: $error\n";
  })->then (sub {
    $result->{times}->{end} = time;
    my $result_json_file = Promised::File->new_from_path
        ($result->{result}->{json_file});
    return $result_json_file->write_byte_string (perl2json_bytes $result);
  })->then (sub {
    return $result;
  });
} # main

my $result = main ()->to_cv->recv; # or die
exit $result->{result}->{exit_code};

=head1 NAME

tesica

=head1 SYNOPSIS

  $ tesica

=head1 TESTING

The B<base directory> is the current directory.

A B<test script> is a file containing a set of tests.  The files whose
name ends by C<.t> contained directly or indirectly, without following
symlinks, in the C<t> directory under the base directory are the test
scripts to be used.

=head1 RESULT FILE

The result is written to the C<local/test/result.json>, which is a
JSON file of a JSON object with following name/value pairs:

=over 4

=item rule

A JSON object with following name/value pairs:

=over 4

=item type

A string C<perl>.

=item base_dir

The absolute path of the base directory.

=back

=item files

A JSON array of absolute paths of the test scripts.

=item result

A JSON object with following name/value pairs:

=over 4

=item exit_code

The exit code of the testing.  Zero if there is no problem detected.

=item json_file

The absolute path to the result JSON file.

=back

=back

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 LICENSE

Copyright 2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
