use v5.36.0;

package Cyrus::Docker::Command::build;
use Cyrus::Docker -command;

use Process::Status;
use Term::ANSIColor qw(colored);

sub abstract { 'configure, build, and install cyrus-imapd' }

sub opt_spec {
  return (
    [ 'sanitizer' => hidden => { one_of => [
      [ 'asan'  => 'build with AddressSanitizer' ],
      [ 'ubsan' => 'build with UBSan' ],
      [ 'ubsan-trap' => 'build with UBSan and trap on error' ],
    ] } ],
    [ 'compiler' => hidden => { one_of => [
      [ 'gcc' => 'gcc', ],
      [ 'clang' => 'clang', ],
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

  my $with_sanitizer = "";

  if ($opt->sanitizer) {
    if ($opt->sanitizer eq 'asan') {
      $with_sanitizer = " with asan";

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

      if (! $opt->compiler) {
        warn colored(['red'], "If using gcc you may need ASAN_OPTIONS=verify_asan_link_order=0 when running cassandane tests.") . "\n";
        warn colored(['red'], "Alternatively, use 'cyd build --asan --gcc' and I'll configure the build appropriately") . "\n";

      } elsif ($opt->compiler eq 'gcc') {
        # As of at least gcc 12 we need to statically link libasan or cass
        # tests fail with "ASan runtime does not come first..." errors
        $ENV{CYRUS_SAN_FLAGS} .= ' -static-libasan';
      }

    } elsif ($opt->sanitizer =~ /^ubsan/) {
      $with_sanitizer = " with ubsan";

      $ENV{CYRUS_SAN_FLAGS} = '-fsanitize=undefined';

      if ($opt->sanitizer eq 'ubsan_trap') {
        $ENV{CYRUS_SAN_FLAGS} .= ' -fsanitize-undefined-trap-on-error';
      }
    }
  }

  my $with_cc = "";

  if ($opt->compiler) {
    $ENV{CC} = $opt->compiler;

    $with_cc = " using $ENV{CC}";
  }

  say "building cyrusversion $version$with_cc$with_sanitizer";

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
