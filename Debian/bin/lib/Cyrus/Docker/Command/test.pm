use v5.36.0;

package Cyrus::Docker::Command::test;
use Cyrus::Docker -command;

use Path::Tiny;
use Process::Status;

sub execute ($self, $opt, $args) {
  unless (-e '/run/rsyslogd.pid') {
    system('/usr/sbin/rsyslogd');
    Process::Status->assert_ok('starting rsyslog');
  }

  my $root = "/srv/cyrus-imapd/cassandane";
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

  system(qw(make -j 8));
  Process::Status->assert_ok('Cassandane make');

  system(
    qw(
      setpriv --reuid=cyrus --regid=mail
              --clear-groups --inh-caps=-all
              ./testrunner.pl -f pretty -j 8
    ),
    @$args,
  );

  Process::Status->assert_ok('Cassandane run');
}

1;