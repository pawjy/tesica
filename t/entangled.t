use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    files => {
      'manifest.json' => {json => {
        entangled_log_files => ['log1.txt', 'log2.txt'],
      }},
      't/abc.t' => {perl_test => 'ok'},
      't/abc2.t' => {bytes => q{
        open my $file, '>', $ENV{CIRCLE_ARTIFACTS} . '/log1.txt';
        print $file "xyz";
        close $file;
        sleep 2;
        print "AAA";
        print STDERR "B";
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is 0+keys %{$json->{rule}->{entangled_logs}}, 2;
      is 0+@{$json->{files}}, 2;
      
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      {
        my $f = $return->{result_file_bytes}->('t/abc.t');
        my $s = {1 => '', 2 => '', 70001 => '', 70002 => ''};
        while ($f =~ s{^\x0A&([0-9]+) (-?[0-9]+) ([0-9]+\.[0-9]+)\x0A}{}) {
          if ($2 >= 0) {
            $s->{$1} .= substr $f, 0, $2;
            substr ($f, 0, $2) = '';
          }
        }
        is $f, '';
        is $s->{1}, "";
        is $s->{2}, "";
        is $s->{70001}, '';
        is $s->{70002}, '';
      }
      
      ok $json->{file_results}->{'t/abc2.t'}->{result}->{ok};
      {
        my $f = $return->{result_file_bytes}->('t/abc2.t');
        warn "Result file: |$f|\n"; # for debugging
        my $s = {1 => '', 2 => '', 70001 => '', 70002 => ''};
        while ($f =~ s{^\x0A&([0-9]+) (-?[0-9]+) ([0-9]+\.[0-9]+)\x0A}{}) {
          if ($2 >= 0) {
            $s->{$1} .= substr $f, 0, $2;
            substr ($f, 0, $2) = '';
          }
        }
        is $f, '';
        is $s->{1}, "AAA";
        is $s->{2}, "B";
        is $s->{70001}, 'xyz';
        is $s->{70002}, '';
      }
    } $c;
  });
} n => 15, name => 'entangled log files';

run_tests;

=head1 LICENSE

Copyright 2022-2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
