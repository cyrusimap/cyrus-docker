use v5.36.0;

package Cyrus::Docker::Command::build;
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
    [ 'jobs|j=i',    'specify number of parallel jobs (default: 8) to run for make',
                     { default => 8 },
    ],
  );
}

sub execute ($self, $opt, $args) {
  my $root = $self->app->repo_root;
  chdir $root or die "can't chdir to $root: $!";

  unless (-e 'Makefile') {
    die "Can't build without a Makefile. Do you need to cyd configure?\n";
  }

  my @jobs = ("-j", $self->app->config->{default_jobs} // $opt->jobs);

  run(qw( make lex-fix                  ), @jobs);
  run(qw( make                          ), @jobs);
}

1;
