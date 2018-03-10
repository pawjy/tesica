use strict;
use warnings;
use Path::Tiny;
use Promised::File;
use JSON::PS;

sub main () {
  my $rule = {
    type => 'perl',
    result_json_file => 'local/test/result.json',
  };

  my $result = {};
  $result->{rule}->{type} = $rule->{type};
  $result->{result}->{exit_code} = 0;

  my $result_json_path = path ($rule->{result_json_file});
  $result->{result}->{json_file} = $result_json_path->absolute;
  my $result_json_file = Promised::File->new_from_path ($result_json_path);
  return $result_json_file->write_byte_string (perl2json_bytes $result)->then (sub {
    return $result;
  });
} # main

my $result = main ()->to_cv->recv; # or die
exit $result->{result}->{exit_code};

=head1 NAME

tesica

=head1 SYNOPSIS

  $ tesica

=head1 RESULT FILE

The result is written to the C<local/test/result.json>, which is a
JSON file of a JSON object with following name/value pairs:

=over 4

=item rule

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
