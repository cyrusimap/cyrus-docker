use v5.36.0;

package Cyrus::Docker::Command::distcheck;
use Cyrus::Docker -command;

use File::Spec ();
use File::Temp qw(tempdir);
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
    [ 'jobs|j=i', 'specify number of parallel jobs (default: 8) to run for make',
                  { default => 8 },
    ],
    [ 'dirty',    'do a dirty dist: the git repo MUST be dirty; otherwise, MUST NOT' ],
    [ 'brief',    'only make distcheck, do not test the tarball' ],
  );
}

sub execute ($self, $opt, $args) {
  my $root = $self->app->repo_root;
  chdir $root or die "can't chdir to $root: $!";

  my @lines = `git status --porcelain | grep -v '?'`;
  if (@lines && !$opt->dirty) {
    die "Refusing to distcheck in dirty git state without --dirty.\n";
  }

  if (!@lines && $opt->dirty) {
    die "Refusing to distcheck --dirty in clean git state.\n";
  }

  $ENV{PKG_CONFIG_PATH} = join q{:}, (
    '/usr/local/cyruslibs/lib/x86_64-linux-gnu/pkgconfig',
    '/usr/local/cyruslibs/lib/pkgconfig',
    ($ENV{PKG_CONFIG_PATH} or ())
  );

  $ENV{PATH} = join q{:}, '/usr/local/cyruslibs/bin', $ENV{PATH};

  run(qw( autoreconf -i -s ));

  run(qw( ./configure --enable-maintainer-mode ));

  my @jobs = ("-j", $self->app->config->{default_jobs} // $opt->jobs);

  run(qw( make distcheck ), @jobs);

  if ($opt->brief) {
    return;
  }

  my $commit = `git rev-parse HEAD`;
  Process::Status->assert_ok('checking current commit');

  chomp $commit;
  $commit = substr $commit, 0, 6;

  my $dirty = $opt->dirty ? '-dirty' : '';

  my ($tarball) = glob("cyrus-imapd-*-g${commit}*${dirty}.tar.gz");

  unless ($tarball) {
    die "Can't find the tarball we should've just built!\n";
  }

  my $full_tarball_path = File::Spec->catfile($root, $tarball);

  my $tempdir = tempdir(CLEANUP => 1);
  chdir $tempdir or die "can't chdir to $tempdir: $!";
  chmod 0755, $tempdir or die "can't chmod 0755 $tempdir: $!";

  run(qw( tar zxvf ), $full_tarball_path );

  my $extracted = File::Spec->catfile($tempdir, $tarball =~ s/\.tar\.gz$//r);
  chdir $extracted or die "can't chdir to $extracted: $!";

  local $ENV{CYRUS_CLONE_ROOT} = $extracted;
  run(qw( cyd build ));

  # This is a bit iffy, but gets the job done for now.
  local $ENV{CASSINI_FILENAME} = "$extracted/cassandane/cassandane.ini";

  run(qw( cyd test ));

  # chdir back to original root so that tempdir can be cleaned up
  chdir $root or die "can't chdir to $root: $!";
}

1;
