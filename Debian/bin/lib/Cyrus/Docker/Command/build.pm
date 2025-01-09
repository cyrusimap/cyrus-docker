use v5.36.0;

package Cyrus::Docker::Command::build;
use Cyrus::Docker -command;

use Process::Status;

sub abstract { 'configure, build, and install cyrus-imapd' }

sub execute ($self, $opt, $args) {
  my $root = $self->app->repo_root;
  chdir $root or die "can't chdir to $root: $!";

  my $version = `./tools/git-version.sh`;
  Process::Status->assert_ok("determining git version");

  chomp $version;

  if ($version eq 'unknown') {
    die "git-version.sh can't decide what version this is; giving up!\n";
  }

  say "building cyrusversion $version";

  $ENV{CFLAGS}="-g -W -Wall -Wextra -Werror";

  my @configopts = qw(
    --enable-autocreate
    --enable-backup
    --enable-calalarmd
    --enable-gssapi
    --enable-http
    --enable-idled
    --enable-murder
    --enable-nntp
    --enable-replication
    --enable-shared
    --enable-silent-rules
    --enable-unit-tests
    --enable-xapian
    --enable-jmap
    --with-ldap=/usr"
  );

  local $ENV{CONFIGOPTS} = "@configopts";

  system('./tools/build-with-cyruslibs.sh');
  Process::Status->assert_ok("building cyrus-imapd");

  system('/usr/cyrus/bin/cyr_info', 'version');
}

1;
