use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $c = shift;
  return run (
    envs => {
      CIRCLE_NODE_TOTAL => 2,
      CIRCLE_NODE_INDEX => 0,
    },
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
      't/ghi.t' => {perl_test => 1},
      't/jkl.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 2;
      is $json->{rule}->{circle_node_total}, 2;
      is $json->{rule}->{circle_node_index}, 0;
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      ok $json->{file_results}->{'t/def.t'}->{error}->{ignored};
      ok $json->{file_results}->{'t/ghi.t'}->{result}->{ok};
      is $json->{file_results}->{'t/jkl.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      ok $json->{file_results}->{'t/jkl.t'}->{error}->{ignored};
    } $c;
  });
} n => 12, name => 'node 0 of 2';

Test {
  my $c = shift;
  return run (
    envs => {
      CIRCLE_NODE_TOTAL => 2,
      CIRCLE_NODE_INDEX => 1,
    },
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
      't/ghi.t' => {perl_test => 1},
      't/jkl.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 2;
      is $json->{rule}->{circle_node_total}, 2;
      is $json->{rule}->{circle_node_index}, 1;
      is $json->{file_results}->{'t/abc.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      ok $json->{file_results}->{'t/abc.t'}->{error}->{ignored};
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
      is $json->{file_results}->{'t/ghi.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      ok $json->{file_results}->{'t/ghi.t'}->{error}->{ignored};
      ok $json->{file_results}->{'t/jkl.t'}->{result}->{ok};
    } $c;
  });
} n => 12, name => 'node 1 of 2';

Test {
  my $c = shift;
  return run (
    envs => {
      CIRCLE_NODE_TOTAL => 3,
      CIRCLE_NODE_INDEX => 1,
    },
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
      't/ghi.t' => {perl_test => 1},
      't/jkl.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 1;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 3;
      is $json->{rule}->{circle_node_total}, 3;
      is $json->{rule}->{circle_node_index}, 1;
      is $json->{file_results}->{'t/abc.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
      is $json->{file_results}->{'t/ghi.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      is $json->{file_results}->{'t/jkl.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
    } $c;
  });
} n => 10, name => 'node 1 of 3';

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{rule}->{circle_node_total}, undef;
      is $json->{rule}->{circle_node_index}, undef;
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
    } $c;
  });
} n => 8, name => 'no node env vars';

Test {
  my $c = shift;
  return run (
    envs => {
      CIRCLE_NODE_TOTAL => 1,
      CIRCLE_NODE_INDEX => 0,
    },
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{rule}->{circle_node_total}, undef;
      is $json->{rule}->{circle_node_index}, undef;
    } $c;
  });
} n => 6, name => 'node total 1 - no splitting';

Test {
  my $c = shift;
  return run (
    manifest => 'manifest.json',
    envs => {
      CIRCLE_NODE_TOTAL => 2,
      CIRCLE_NODE_INDEX => 0,
    },
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
      't/ghi.t' => {perl_test => 1},
      'manifest.json' => {json => {
        skip => ['./t/def.t'],
      }},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 1;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 2;
      is $json->{rule}->{circle_node_total}, 2;
      is $json->{rule}->{circle_node_index}, 0;
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      is $json->{file_results}->{'t/def.t'}->{error}->{message}, 'Skipped by request';
      is $json->{file_results}->{'t/ghi.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
    } $c;
  });
} n => 9, name => 'combined with manifest skip';

Test {
  my $c = shift;
  return run (
    envs => {
      CIRCLE_NODE_TOTAL => 2,
      CIRCLE_NODE_INDEX => 2,
    },
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
      't/ghi.t' => {perl_test => 1},
      't/jkl.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 0;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 4;
      is $json->{rule}->{circle_node_total}, 2;
      is $json->{rule}->{circle_node_index}, 2;
      is $json->{file_results}->{'t/abc.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      ok $json->{file_results}->{'t/abc.t'}->{error}->{ignored};
      is $json->{file_results}->{'t/def.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      ok $json->{file_results}->{'t/def.t'}->{error}->{ignored};
      is $json->{file_results}->{'t/ghi.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      ok $json->{file_results}->{'t/ghi.t'}->{error}->{ignored};
      is $json->{file_results}->{'t/jkl.t'}->{error}->{message}, 'Skipped by CIRCLE_NODE_INDEX';
      ok $json->{file_results}->{'t/jkl.t'}->{error}->{ignored};
    } $c;
  });
} n => 14, name => 'node index >= total';

Test {
  my $c = shift;
  return run (
    envs => {
      CIRCLE_NODE_INDEX => 0,
    },
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{rule}->{circle_node_total}, undef;
      is $json->{rule}->{circle_node_index}, undef;
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
    } $c;
  });
} n => 8, name => 'index only, no total';

Test {
  my $c = shift;
  return run (
    envs => {
      CIRCLE_NODE_TOTAL => 2,
    },
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{rule}->{circle_node_total}, undef;
      is $json->{rule}->{circle_node_index}, undef;
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
    } $c;
  });
} n => 8, name => 'total only, no index';

Test {
  my $c = shift;
  return run (
    envs => {
      CIRCLE_NODE_TOTAL => 0,
      CIRCLE_NODE_INDEX => 0,
    },
    files => {
      't/abc.t' => {perl_test => 1},
      't/def.t' => {perl_test => 1},
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{result}->{exit_code}, 0;
      is $json->{result}->{pass}, 2;
      is $json->{result}->{fail}, 0;
      is $json->{result}->{skipped}, 0;
      is $json->{rule}->{circle_node_total}, undef;
      is $json->{rule}->{circle_node_index}, undef;
      ok $json->{file_results}->{'t/abc.t'}->{result}->{ok};
      ok $json->{file_results}->{'t/def.t'}->{result}->{ok};
    } $c;
  });
} n => 8, name => 'total is 0';

run_tests;

=head1 LICENSE

Copyright 2018-2026 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
