use strict;
use warnings;

use Main;

my $result = Main->main (@ARGV)->to_cv->recv; # or die
exit $result->{result}->{exit_code};

=head1 NAME

tesica

=head1 SYNOPSIS

  $ tesica

If you don't have tesica yet:

  $ curl -sSLf https://raw.githubusercontent.com/wakaba/tesica/master/tesica | perl

=head1 TESTING

The B<base directory> is the current directory.

A B<test script> is a file containing a set of tests.  The files whose
name ends by C<.t> contained directly or indirectly, without following
symlinks, in the C<t> directory under the base directory are the test
scripts to be used.

=head1 TEST MANIFEST FILE

A set of detailed test options can be specified as a test manifest
file.

The environment variable C<TESICA_MANIFEST_FILE> can be used to
specify the path to the test manifest file (relative to the current
directory).

A test manifest file is a UTF-8 encoded JSON object with following
name/value pairs:

=over 4

=item after : Array<Run>?

Commands executed after the tests.  If specified, it must be an array
of zero or more C<Run> objects, which are executed in order.

Any failure is ignored; if a command fails, any following command is
still executed.  Failure does not affect the exit code of the
C<tesica> process.

=item allow_failure : Array<String>?

The files whose failures are ignored.  If specified, it must be an
array of zero or more paths, relative to the test manifest file.

Failure-ignored tests are executed as usual but counted as passed
tests nevertheless their results.

=item before : Array<Run>?

Commands executed before the tests.  If specified, it must be an array
of zero or more C<Run> objects, which are executed in order.

If a command fails, any following command as well as tests are
skipped.

=item entangled_log_files : Array<String>?

The entangled log files, i.e. files whose contents are to be merged
into the output file.  If specified, it must be an array of zero or
more paths, relative to the test result directory.

Any addition to the specified files during the execution of a test
script is inserted into the output file for the test script.

=item max_consecutive_failures : Integer?

The number of maximum allowed consecutive failures.  If specified and
there are more consecutive failing test scripts than that number, any
following test scripts are skipped.

=item max_retries : Integer?

The maximum number of retries upon failures.  Defaulted to zero.  If a
test script fails, it is retried at most I<max_retries> times.  If one
of retries passes, the test script is marked as passed.

=item priority : Array<String>?

The order tests are executed.  If specified, it must be an array of
zero or more paths, relative to the test manifest file.

Tests are executed in order specified in the array.  Any tests not
listed in the array is executed after the listed tests.  Any listed
file not actually found is silently ignored.

=item skip : Array<String>?

The files that are skipped.  If specified, it must be an array of zero
or more paths, relative to the test manifest file.

Skipped tests are not executed at all but counted as passed tests.

=back

=head2 Run objects

A C<Run> object is a JSON object with following name/value pairs:

=over 4

=item background : Boolean

If true and the C<Run> object is used as a C<before> command, the
following C<before> commands, as well as tests, are executed without
waiting for the completion of this command.

A C<TERM> signal is sent to the command after the tests (but before
the C<after> commands), if it is running.

A C<KILL> signal is sent to the command after 10 seconds from the
C<TERM> signal, if it is still running.

=item check : Boolean

If true and the C<Run> object is used as a C<before> command, the
command is repeated until it exits with zero (0).

=item interval : Integer?

The interval between retries in seconds.  Defaulted to 1 s.  Only
applicable when C<check> is true.

=item max_retries : Integer?

The maximum number of retries upon failures.  Defaulted to zero.  Only
applicable when C<check> is true.

=item run : String | Array<String>

The command to execute.  If a string is specified, it is executed by
C<bash>.  Otherwise, the array is used as the command and the
arguments.

=back

If a C<Run> object would have only a C<run> string, it can be replaced
by the string only.

=head1 TEST RESULTS

Test results are put into the test result directory.

If the environment variable C<CIRCLE_ARTIFACTS> is specified, the test
result directory is set to that value.

Otherwise, the test result directory is set to the C<local/test>
subdirectory in the base directory, which is defaulted to the current
directory.

=head2 Result file

The summary of the test result is written to the C<result.json> file
in the test result directory (C<./local/test/result.json> by default),
which is a JSON file of a JSON object with following name/value pairs:

=over 4

=item rule

A JSON object with following name/value pairs:

=over 4

=item base_dir : String

The absolute path of the base directory.

=item ci : Object?

Information on the CI build the tests belong to.  If the test is
executed in a supported CI environment (GitHub Actions, Drone CI, and
CircleCI 2), the following name/value pair is set from the environment
variables:

=over 4

=item url : String?

The URL of the build, if known.

=back

=item envs : Object<String, String>

The environment variables of the process.  It is an Object whose
name/value pairs are the environment variable names and their values.

=item entangled_logs : Object<Channel, Object>

The list of the entangled logs.  It is an Object whose name/value
pairs are the combination of the channel ID for an entangled log and
the associated Object with following name/value pair:

=over 4

=item file : ResultPath

The path to the entangled log file.

=item repo : Object?

Information on the repository the tests belong to.  If the test is
executed in a supported CI environment (GitHub Actions, Drone CI, and
CircleCI 2), the following name/value pairs are set from the
environment variables:

=over 4

=item branch : String?

The branch name, if known.

=item commit : String?

The commit SHA value, if known.

=item url : String?

The URL of the repository, if known.

=back

=back

=item manifest_file : String?

The absolute path of the test manifest file, if any.

=item max_consecutive_failures : Integer?

The number of allowed maximum consecutive failures, if specified.

=item max_retries : Integer

The maximum number of retries.

=item result_dir : String

The absolute path of the test result directory.

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

=item file_results : Object<Path, FileResult>

An Object whose names are the paths of the test scripts and values are
corresponding results.

=item other_results : Object<String, FileResult>

An Object whose names are a short string identifying a command
execution and values are corresponding results.

Results for C<before> and C<after> commands are put into this Object.

=item result : Result

The result of the entire test, referred to as "global result".

=item tries : Array<FileResult>?

The earlier results of the test script, when it is retried one or more
times.

=back

=head2 Data types

The data types used to describe result file content are as follows:

=over 4

=item Array<I<T>>

A JSON array whose members are of I<T>.

=item BasePath

A String representing a Unix-style file or directory path, which can
be resolved relative to the |rule|'s |base_dir|.

=item Boolean

A boolean value.  False is represented by one of: a JSON number 0, an
empty String, a JSON false value, a JSON null value, or omission of
the name/value pair if the context is the value of a name/value pair
of an Object.  True is represented by a non-false value.

=item Channel

An Integer, referred to as channel ID.  Either: C<1> for a standard
output, C<2> for a standard error output, or an integer that is
associated with an entangled log file.

=item Error

An Object representing an error, with following name/value pairs:

=over 4

=item ignored : Boolean

Whether the error is ignored or not.

=item message : String

A short string that summarizes the error.

=back

=item Executor

An Object representing an executor, with following name/value pair:

=over 4

=item type : String

The executor type.  A String C<perl> for now.

=back

=item File

An Object representing a file, with following name/value pair:

=over 4

=item file_name_path : BasePath

The path to the file.

=back

=item FileResult

An Object representing a result for a test script, with following
name/value pairs:

=over 4

=item command : Array<String>

The command executed, with the arguments.

=item current_try_count : Integer

The number of executions of this command, including the current run.

=item error : Error?

The error of the process of the test script, if any.

=item executor : Executor?

The description of the test executor used for the test script, if any.

=item max_try_count : Integer

The maximum number of allowed executions of this command.

=item times : Times

The timestamps of the process of the test script.

=item result : Result

The result of the process of the test script, referred to as "file's
result".

=back

=item Integer

A JSON number representing an integer value.

=item Object

A JSON object.

=item Object<I<T>, I<U>>

A JSON object whose names are of I<T> and values are of I<U>.

=item ResultPath

A String representing a Unix-style file or directory path, which can
be resolved relative to the |rule|'s |result_dir|.

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

=item completed : Boolean

Whether the process has been completed or not.

If true, completed.  The other fields of the object renresent the
final result.

If false, not completed yet.  The other fields of the object represent
the preliminary result.  Their values might be updated later.

=item exit_code : Integer?

The exit status of the process, if a process is executed.  The exit
code of the Unix process, if the process is a Unix process.  E.g. zero
if there is no problem detected.

=item fail : Integer?

The number of the failed tests (except for skipped and failure-ignored
tests) within the process, if known.

=item failure_ignored : Integer?

The number of the failure-ignored tests within the process, if known.

=item json_file : ResultPath (global result only)

The path to the result JSON file.

=item ok : Boolean

Whether the process is success or not.

=item output_file : ResultPath (file's result only)

The path to the output file, which contains standard output and
standard error output of the test script, with any entangled log.

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

Where a descriptor integer is a Channel value; A size integer is
either a non-zero ASCII digit followed by zero or more ASCII digits,
C<0>, or C<-1>; A timestamp is one or more ASCII digits followed by an
ASCII "." byte followed by one or more ASCII digits.

The timestamp represents the time the chunk was received, in decimal
number of the Unix time.  The timestamp of a chunk is always equal to
or greater than that of any previous chunk.

The size integer represents the number of the bytes in the chunk body,
in decimal integer, when the number is zero or greater, or represents
the end of the file when the number is C<-1>.  Note that there might
not be any chunk with the size of C<-1> when the file is not closed
before the end of the execution.

A chunk body is the bytes that belongs to the file identified by the
descriptor integer.

=item pass : Integer?

The number of the passed tests (including failure-ignored tests but
excluding skipped tests) within the process, if known.

=item pass_after_retry : Integer?

The number of the passed tests that initially failed but then passed
when retried, if known.

=item skipped : Integer?

The number of the skipped tests within the process, if known.

=back


=back

=head1 ENVIRONMENT VARIABLES

C<CIRCLE_ARTIFACTS>: See L</TEST RESULTS>.

C<TESICA_MANIFEST_FILE>: See L</TEST MANIFEST FILE>.

=head1 EXIT STATUS

When all tests passes, the C<tesica> process returns zero (0).

When one or more tests fails, or one or more of commands specified in
C<before> fails, the C<tesica> process returns one (1).

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 HISTORY

This Git repository was located at <https://github.com/wakaba/tesica>
until 14 March, 2022.

=head1 LICENSE

Copyright 2018-2024 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
