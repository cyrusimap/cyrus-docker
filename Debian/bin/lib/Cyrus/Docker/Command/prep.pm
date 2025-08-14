use v5.36.0;

package Cyrus::Docker::Command::prep;
use Cyrus::Docker -command;

use Process::Status;
use Term::ANSIColor qw(colored);

my sub run (@args) {
  say "running: @args";
  system(@args);
  Process::Status->assert_ok($args[0]);
}

sub abstract { 'build a configured cyrus-imapd' }

sub opt_spec {
  return (
    [ 'with-sphinx|s', 'enable sphinx docs' ],
    [ 'sanitizer' => hidden => { one_of => [
      [ 'asan'  => 'build with AddressSanitizer' ],
      [ 'ubsan' => 'build with UBSan' ],
      [ 'ubsan-trap' => 'build with UBSan and trap on error' ],
    ] } ],
    [ 'compiler' => hidden => { one_of => [
      [ 'gcc' => 'gcc', ],
      [ 'clang' => 'clang', ],
    ] } ],
    [ 'jobs|j=i',    'specify number of parallel jobs (default: 8) to run for make',
                     { default => 8 },
    ],
  );
}

sub execute ($self, $opt, $args) {
  my $root = $self->app->repo_root;
  chdir $root or die "can't chdir to $root: $!";

  my @jobs = ("-j", $self->app->config->{default_jobs} // $opt->jobs);

  my @sphinx    = $opt->with_sphinx ? ('--with-sphinx')        : ();
  my @sanitizer = $opt->sanitizer   ? ('--' . $opt->sanitizer) : ();
  my @compiler  = $opt->compiler    ? ('--' . $opt->compiler ) : ();

  my @to_run = (
    [ 'Cyrus::Docker::Command::configure', (@sphinx, @sanitizer, @compiler) ],
    [ 'Cyrus::Docker::Command::build',   (@jobs) ],
    [ 'Cyrus::Docker::Command::check',   (@jobs) ],
    [ 'Cyrus::Docker::Command::install', (@jobs) ],
  );

  for my $to_run (@to_run) {
    (my $class, local @ARGV) = @$to_run;

    my ($cmd, $opt, @args) = $class->prepare($self->app);
    $self->app->execute_command($cmd, $opt, @args);
  }
}

1;
