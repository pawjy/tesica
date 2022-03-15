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

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
