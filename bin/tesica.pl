use strict;
use warnings;

use Main;

my $result = Main->main (@ARGV)->to_cv->recv; # or die
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

=item base_dir : String

The absolute path of the base directory.

=back

=item executors : Object<String, Object>

An Object whose names are the executor types and values are
corresponding properties of them, with following name/value pair:

=over 4

=item perl_command : Array<String>?

The command of Perl, if the executor type is C<perl>.

If there is an executable file C<perl> in the base directory, it is
used.  Otherwise, C<perl> in the platform's path is used.

=back

=item files : Array<File>

An Array of the files of the test scripts.

=item file_results : Object<Path, Object>

An Object whose names are the paths of the test scripts and values are
corresponding results, with following name/value pairs:

=over 4

=item executor : Executor?

The description of the test executor used for the file, if any.

=item times : Times

The timestamps of the process of the test script.

=item result : Result

The result of the process of the test script, referred to as "file
result".

=back

=item result : Result

The result of the entire test, referred to as "global result".

=back

=head2 Data types

The data types used to describe result file content are as follows:

=over 4

=item Array<I<T>>

A JSON array whose members are of I<T>.

=item Boolean

A boolean value.  False is represented by one of: a JSON number 0, an
empty String, a JSON false value, a JSON null value, or omission of
the name/value pair if the context is the value of a name/value pair
of an Object.  True is represented by a non-false value.

=item Executor

An Object representing an executor, with following name/value pair:

=over 4

=item type : String

The executor type.  A String C<perl> for now.

=back

=item File

An Object representing a file, with following name/value pair:

=over 4

=item file_name_path : Path

The path to the file.

=back

=item Integer

A JSON number representing an integer value.

=item Object

A JSON object.

=item Object<I<T>, I<U>>

A JSON object whose names are of I<T> and values are of I<U>.

=item Path

A String representing a Unix-style file or directory path, which can
be resolved relative to the |rule|'s |base_dir|.

=item String

A JSON string or a number representing its string value.

=item Times

An Object representing timestamps related to a process, with following
name/value pairs:

=over 4

=item end : Timestamp

The end time of the process.

=item start : Timestamp

The start time of the process.

=back

=item Timestamp

A JSON number representing a Unix time.

=item Result

An Object representing a result of the process, with following
name/value pairs:

=over 4

=item exit_code : Integer?

The exit code of the process, if a process is executed.  The exit code
of the Unix process, if the process is a Unix process.  E.g. zero if
there is no problem detected.

=item fail : Integer?

The number of the failed tests within the process, if known.

=item json_file : Path (global result only)

The path to the result JSON file.

=item ok : Boolean

Whether the process is success or not.

=item output_file : Path (file result only)

The path to the output file, which contains standard output and
standard error output of the test script.

The output file is stored under the C<local/test/files> directory
within the base directory.

An output file is a sequence of one or more data chunks.  A chunk is a
chunk header followed by a chunk body.  A chunk header is a sequence
of the followings:

  0x0A byte;
  ASCII "&" byte;
  descriptor integer;
  0x20 byte;
  size integer;
  0x20 byte;
  timestamp; and
  0x0A byte.

Where a descriptor integer is C<1> (the standard output) or C<2> (the
standard error output); A size integer is either a non-zero ASCII
digit followed by zero or more ASCII digits, C<0>, or C<-1>; A
timestamp is one or more ASCII digits followed by an ASCII "." byte
followed by one or more ASCII digits.

The timestamp represents the time the chunk was received, in decimal
number of the Unix time.  The timestamp of a chunk is always equal to
or greater than that of any previous chunk.

the size integer represents the number of the bytes in the chunk body,
in decimal integer, when the number is zero or greater, or represents
the end of the file when the number is C<-1>.

A chunk body is the bytes that belongs to the file identified by the
descriptor integer.

=item pass : Integer?

The number of the passed tests within the process, if known.

=back


=back

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 HISTORY

This Git repository was located at <https://github.com/wakaba/tesica>
until 14 March, 2022.

=head1 LICENSE

Copyright 2018-2022 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
