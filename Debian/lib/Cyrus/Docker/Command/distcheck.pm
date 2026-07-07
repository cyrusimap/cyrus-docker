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

sub description {
  return <<~'END';
  Build a release tarball with "make distcheck", then unpack it somewhere clean
  and build and test *that* with cyd build / cyd test.  This is how we confirm
  the dist tarball is self-contained and that a from-tarball build (the path a
  packager or end user takes) actually works.

  By default it insists the checkout be clean; pass --dirty to distcheck a dirty
  tree on purpose (and it will then insist the tree *is* dirty, to catch
  mistakes).  Use --brief to stop after "make distcheck" without testing the
  unpacked tarball.
  END
}

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
    die <<~'END'
    Can't find the tarball we should've just built!  This often means that you
    had a stale configure result, and built for the configured version, not the
    version that tools/git-version.sh would now produce.

    END
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

  run(qw( cyd makedocs ));

  # chdir back to original root so that tempdir can be cleaned up
  chdir $root or die "can't chdir to $root: $!";
}

1;
