use v5.36.0;

package Cyrus::Docker::Command::build;
use Cyrus::Docker -command;

use Process::Status;

sub abstract { 'configure, build, and install cyrus-imapd' }

sub opt_spec {
  return (
    [ 'sanitizer' => hidden => { one_of => [
      [ 'asan'  => 'build with AddressSanitizer' ],
      [ 'ubsan' => 'build with UBSan' ],
      [ 'ubsan-trap' => 'build with UBSan and trap on error' ],
    ] } ],
  );
}

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

  if ($opt->sanitizer) {
    if ($opt->sanitizer eq 'asan') {
      $ENV{CYRUS_SAN_FLAGS} = '-fsanitize=address';

      my $lsan_opts = $ENV{LSAN_OPTIONS} || "";
      my $dont_suppress;

      if ($lsan_opts) {
        my %opts = map { split '=', $_ } split(':', $lsan_opts);
        if ($opts{supressions} && $opts{supressions} ne "cunit/leaksanitizer.suppress") {
          warn "Warning! LSAN_OPTIONS already defines a suppressions file so ours will not be used. You may see spurious failures...\n";
          $dont_suppress = 1;
        }
      }

      unless ($dont_suppress) {
        $ENV{LSAN_OPTIONS} = "$lsan_opts:suppressions=leaksanitizer.suppress";
      }
    } elsif ($opt->sanitizer =~ /^ubsan/) {
      $ENV{CYRUS_SAN_FLAGS} = '-fsanitize=undefined';

      if ($opt->sanitizer eq 'ubsan_trap') {
        $ENV{CYRUS_SAN_FLAGS} .= ' -fsanitize-undefined-trap-on-error';
      }
    }
  }

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
