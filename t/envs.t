use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/lib');
use Tests;

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {perl_test => 1},
    },
    envs => {
      FOO => 'bar',
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{rule}->{envs}->{FOO}, 'bar';
    } $c;
  });
} n => 1, name => 'No retry';

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {perl_test => 1},
    },
    envs => {
      CI => 'true',
      'GITHUB_ACTIONS' => 'true',
      'GITHUB_SERVER_URL' => 'https://github.com',
      'GITHUB_REPOSITORY' => 'pawjy/tesica-test',
      'GITHUB_RUN_ID' => '12144',
      'GITHUB_SHA' => 'agseefewe',
      'GITHUB_REF_NAME' => 'abcdde',
      'GITHUB_REF_TYPE' => 'branch', # or tag
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{rule}->{envs}->{CI}, 'true';
      is $json->{rule}->{repo}->{url}, 'https://github.com/pawjy/tesica-test';
      is $json->{rule}->{repo}->{commit}, 'agseefewe';
      is $json->{rule}->{repo}->{branch}, 'abcdde';
      ## e.g.
      ## <https://github.com/pawjy/tesica/actions/runs/2237299879>
      is $json->{rule}->{ci}->{url}, 'https://github.com/pawjy/tesica-test/actions/runs/12144';
    } $c;
  });
} n => 5, name => 'GitHub Actions';

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {perl_test => 1},
    },
    envs => {
      CI => 'true',
      'DRONE' => 'true',
      'DRONE_REPO_LINK' => 'https://github.com/pawjy/tesica-test',
      'DRONE_BUILD_LINK' => 'https://drone/12144',
      'DRONE_COMMIT_SHA' => 'agseefewe',
      'DRONE_COMMIT_BRANCH' => 'abcdde',
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{rule}->{envs}->{CI}, 'true';
      is $json->{rule}->{repo}->{url}, 'https://github.com/pawjy/tesica-test';
      is $json->{rule}->{repo}->{commit}, 'agseefewe';
      is $json->{rule}->{repo}->{branch}, 'abcdde';
      is $json->{rule}->{ci}->{url}, 'https://drone/12144';
    } $c;
  });
} n => 5, name => 'Drone CI';

Test {
  my $c = shift;
  return run (
    files => {
      't/abc.t' => {perl_test => 1},
    },
    envs => {
      CI => 'true',
      'CIRCLECI' => 'true',
      'CIRCLE_REPOSITORY_URL' => 'https://github.com/pawjy/tesica-test',
      'CIRCLE_BUILD_URL' => 'https://drone/12144',
      'CIRCLE_SHA1' => 'agseefewe',
      'CIRCLE_BRANCH' => 'abcdde',
    },
  )->then (sub {
    my $return = $_[0];
    test {
      my $json = $return->{json};
      is $json->{rule}->{envs}->{CI}, 'true';
      is $json->{rule}->{repo}->{url}, 'https://github.com/pawjy/tesica-test';
      is $json->{rule}->{repo}->{commit}, 'agseefewe';
      is $json->{rule}->{repo}->{branch}, 'abcdde';
      is $json->{rule}->{ci}->{url}, 'https://drone/12144';
    } $c;
  });
} n => 5, name => 'CircleCI';

run_tests;

=head1 LICENSE

Copyright 2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
