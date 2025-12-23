use v5.36.0;

package Cyrus::Docker::Command::distcheck;
use Cyrus::Docker -command;

use Process::Status;
use Term::ANSIColor qw(colored);

my sub run (@args) {
  say "running: @args";
  system(@args);
  Process::Status->assert_ok($args[0]);
}

sub abstract { 'do a distcheck against cyrus-imapd' }

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

  # Assert that we're git clean?

  $ENV{PKG_CONFIG_PATH} = join q{:}, (
    '/usr/local/cyruslibs/lib/x86_64-linux-gnu/pkgconfig',
    '/usr/local/cyruslibs/lib/pkgconfig',
    ($ENV{PKG_CONFIG_PATH} or ())
  );

  $ENV{PATH} = join q{:}, '/usr/local/cyruslibs/bin', $ENV{PATH};

  run(qw( autoreconf -i -s ));

  run(qw( ./configure --enable-maintainer-mode ));

  my @jobs = ("-j", $self->app->config->{default_jobs} // $opt->jobs);

  run(qw( make distcheck                ), @jobs);
}

1;
