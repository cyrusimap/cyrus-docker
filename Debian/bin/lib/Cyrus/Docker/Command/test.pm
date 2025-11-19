use v5.36.0;

package Cyrus::Docker::Command::test;
use Cyrus::Docker -command;

use Path::Tiny;
use Process::Status;

sub abstract { 'test the cyrus-imapd repo with cassandane' }

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
    [ 'jobs|j=i', "number of parallel jobs (default: 8) to run for make and testrunner",
                  { default => 8 } ],
  );
}

sub execute ($self, $opt, $args) {
  unless (-e '/run/rsyslogd.pid') {
    system('/usr/sbin/rsyslogd');
    Process::Status->assert_ok('starting rsyslog');
  }

  my $root = $self->app->repo_root->child('cassandane');
  chdir $root or die "can't chdir to $root: $!";

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

  my @jobs = ("-j", $self->app->config->{default_jobs} // $opt->jobs);

  system(qw(make), @jobs);
  Process::Status->assert_ok('Cassandane make');

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

  Process::Status->assert_ok('Cassandane run');
}

1;
