use v5.36.0;

package Cyrus::Docker::Command::test;
use Cyrus::Docker -command;

use Path::Tiny;
use Process::Status;

sub abstract { 'test the cyrus-imapd repo with cassandane' }

sub description {
  return <<~'END';
  Run the Cassandane (Perl integration) test suite against the built Cyrus.

  With no arguments, runs every test.  Otherwise, name suites or individual
  tests as documented in testrunner.pl:

    test Quota                run the whole Quota suite
    test Quota.quotarename    run one test
    test Admin Quota          run several
    test ~Quota               run everything *except* the Quota suite

  With --cover, on a build made by "build --cover", the tests that ran get
  their own coverage report.  Stale gcov counters are cleared first, so the
  report describes just this run.  For example:

    test --cover Quota        report on what the Quota suite covered
  END
}

sub opt_spec {
  return (
    [ 'format=s', "which formatter to use; default: pretty",
                  { default => 'pretty' } ],
    [ 'ok!',      "include OK results in output (defaults on)", { default => 1 } ],
    [],
    [ 'slow!',    "run slow tests", { default => 0 } ],
    [ 'rerun',    "only run previously-failed tests" ],
    [ 'valgrind', "run with valgrind" ],
    [ 'verbose|v+', "increase verbosity", { default => 0 } ],
    [ 'jobs|j=i', "number of parallel jobs (default: from config, or 8) to run for make and testrunner" ],
    [],
    [ 'cover',       "write a coverage report for the tests that ran" ],
    [ 'cover-dir=s', "where to write the --cover report; default: coverage",
                     { default => 'coverage' } ],
  );
}

# "--enable-coverage" is what puts --coverage into GCOV_CFLAGS, so the Makefile
# is this build's own record of whether it was *configured* for coverage.
my sub is_coverage_build ($repo_root) {
  my $makefile = $repo_root->child('Makefile');
  return unless $makefile->is_file;
  return scalar grep {; /\AGCOV_CFLAGS\s*=\s*\S/ } $makefile->lines({ chomp => 1 });
}

# Configuring for coverage isn't the same as having compiled for it: only an
# instrumented compile writes a .gcno beside the object.
my sub count_instrumented_objects ($repo_root) {
  my $state = $repo_root->visit(sub {
    my ($path, $state) = @_;
    return unless $path->is_file && $path =~ /\.o\z/;

    # Cassandane compiles its own test helpers on every run, uninstrumented and
    # not in the report: counting them would refuse every run after the first.
    return if $path->relative($repo_root) =~ m{\Acassandane/};

    $state->{objects}++;
    $state->{instrumented}++ if -f ("$path" =~ s/\.o\z/.gcno/r);
  }, {
    recurse => 1,
  });

  return ($state->{objects} // 0, $state->{instrumented} // 0);
}

# Every object, not most of them: a report that omits uninstrumented code says
# nothing about what it omitted.
my sub assert_instrumented_build ($repo_root) {
  my ($objects, $instrumented) = count_instrumented_objects($repo_root);

  unless ($objects) {
    die qq{Refusing to run --cover: no object files under $repo_root.  }
      . qq{Build with --cover first.\n};
  }

  return if $instrumented == $objects;

  my $missing = $objects - $instrumented;

  die qq{Refusing to run --cover: coverage instrumentation is missing from }
    . qq{$missing of $objects object files.  Run 'clean', then rebuild with }
    . qq{--cover.\n};
}

# gcov counters accumulate across runs.  Without clearing them, a report would
# also describe whatever ran before: the CUnit tests from the build, or an
# earlier "test --cover" of some other suite.
my sub clear_coverage_data ($repo_root) {
  my $state = $repo_root->visit(sub {
    my ($path, $state) = @_;
    return unless $path->is_file && $path =~ /\.gcda\z/;
    $path->remove;
    $state->{cleared}++;
  }, {
    recurse => 1,
  });

  say "Cleared gcov counters from $state->{cleared} files."
    if $state->{cleared};
}

sub execute ($self, $opt, $args) {
  my $repo_root = $self->app->repo_root;

  if ($opt->cover) {
    unless (is_coverage_build($repo_root)) {
      die "Refusing to run --cover: this build wasn't configured for "
        . "coverage.  Build with --cover first.\n";
    }

    assert_instrumented_build($repo_root);

    clear_coverage_data($repo_root);
  }

  unless (-e '/run/rsyslogd.pid') {
    system('/usr/sbin/rsyslogd');
    Process::Status->assert_ok('starting rsyslog');
  }

  my $root = $repo_root->child('cassandane');
  chdir $root or die "can't chdir to $root: $!";

  # Cassandane needs a cassandane.ini.  In the image we just drop the canonical
  # "dockertests" profile into place and hand it to the cyrus user.
  unless (-e "cassandane.ini") {
    system(qw(cp -af cassandane.ini.dockertests cassandane.ini));
    Process::Status->assert_ok('copying cassandane.ini.dockertests to cassandane.ini');

    system(qw(chown cyrus:mail cassandane.ini));
    Process::Status->assert_ok('chowning cassandane.ini');
  }

  # XXX This is transitional, while we haven't updated cyrus-imap.git to
  # eliminate the .git in path names that existed prior to recent commits.
  {
    my @lines = path('cassandane.ini')->lines;
    s{/srv/[-A-Za-z]+\K.git}{}g for @lines;
    path('cassandane.ini')->spew(@lines);
  }

  my @jobs = ("-j", $self->app->job_count($opt->jobs));

  system(qw(make), @jobs);
  Process::Status->assert_ok('Cassandane make');

  # The Cassadene tests run as user cyrus, so that user needs to be able to
  # write to existing coverage output files, and to create new output files for
  # code not covered by CUnit tests
  my $ownership = $self->app->repo_root->visit(sub {
    my ($path, $state) = @_;
    return unless $path->is_file;
    if ($path =~ /\.gcda\z/) {
      # All existing *.gcda files might need to be updated
      ++$state->{$path};
    } elsif($path =~ m!\A(.*)/[^/]+\.gcno\z!) {
      # All directories containing a *.gcno file might have new *.gcda files
      # written, hence they need to be writable
      ++$state->{$1};
    }
  }, {
    recurse => 1,
  });

  my @to_chown = keys %$ownership;
  if (@to_chown) {
    system('chown', 'cyrus:mail', @to_chown);
    Process::Status->assert_ok('chowning coverage files and directories');
  }

  # The idea here is that if the user ran "cyd test Some::Test" then running
  # "make syntax" could add a lot of overhead in syntax checking.  If they're
  # testing *everything*, though, or "everything but three tests", then running
  # a syntax check is a good idea.  The --rerun options is treated like a
  # specific test selection, which is a bit of a gamble, but probably a good
  # one.
  my $selects_tests = $opt->rerun || grep {; !/^!/ && !/^-/ } @$args;
  unless ($selects_tests) {
    system(qw(make syntax), @jobs);
    Process::Status->assert_ok('Cassandane make syntax');
  }

  # Cassandane (really, the Cyrus code it drives) must run as the "cyrus" user,
  # not root.  We drop to cyrus:mail with setpriv.  Note there's no sudo here:
  # running inside the container we're already root and simply step *down*.
  system(
    qw( setpriv --reuid=cyrus --regid=mail --clear-groups --inh-caps=-all ),
    qw( ./testrunner.pl ), @jobs, qw( -f ), $opt->format,
      ($opt->ok     ? ()        : '--no-ok'),
      ($opt->rerun  ? '--rerun' : ()),
      ($opt->slow   ? '--slow'  : ()),
      ($opt->valgrind ? '--valgrind' : ()),
      (('-v') x $opt->verbose),
    @$args,
  );

  my $test_status = Process::Status->new;

  if ($opt->cover) {
    # The coverage tool captures relative to the checkout root.
    chdir $repo_root or die "can't chdir to $repo_root: $!";

    my $cover_dir = $opt->cover_dir;

    system('coverage', $cover_dir, @$args ? "@$args" : 'All tests');
    Process::Status->assert_ok('coverage');

    say "Coverage report in file://$repo_root/$cover_dir/index.html";
  }

  # Deferred until after the coverage report, because a failing test still
  # exercised code and that run is often exactly the one worth looking at.
  $test_status->assert_ok('Cassandane run');
}

1;
