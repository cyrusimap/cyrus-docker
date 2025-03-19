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

  my $with_sanitizer = $opt->sanitizer ? " with " . $opt->sanitizer : "";

  my $san_flags = q{};

  if ($opt->sanitizer) {
    if ($opt->sanitizer eq 'asan') {
      $san_flags = '-fsanitize=address';

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
        $san_flags .= ' -static-libasan';
      }

    } elsif ($opt->sanitizer =~ /\Aubsan(_trap)?\z/) {
      $san_flags = '-fsanitize=undefined';

      $ENV{UBSAN_OPTIONS} = "print_stacktrace=1:halt_on_error=1";

      if ($opt->sanitizer eq 'ubsan_trap') {
        $san_flags .= ' -fsanitize-undefined-trap-on-error';
      }
    } else {
      die "Unknown sanitizer mode '" . $opt->sanitizer . "'?!\n";
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
    --enable-debug-slowio
    --enable-unit-tests
    --enable-xapian
    --enable-jmap
    --with-ldap=/usr"
  );

  my $libsdir = '/usr/local/cyruslibs';
  my $target  = '/usr/cyrus';

  local $ENV{LDFLAGS} = "-L$libsdir/lib/x86_64-linux-gnu -L$libsdir/lib -Wl,-rpath,$libsdir/lib/x86_64-linux-gnu -Wl,-rpath,$libsdir/lib";
  local $ENV{PKG_CONFIG_PATH} = "$libsdir/lib/x86_64-linux-gnu/pkgconfig:$libsdir/lib/pkgconfig:\$PKG_CONFIG_PATH";
  local $ENV{CFLAGS} = "$san_flags -g -fPIC -W -Wall -Wextra -Werror -Wwrite-strings";
  local $ENV{CXXFLAGS} = "$san_flags -g -fPIC -W -Wall -Wextra -Werror";
  local $ENV{PATH} = "$libsdir/bin:$ENV{PATH}";

  my sub run (@args) {
    say "running: @args";
    system(@args);
    Process::Status->assert_ok($args[0]);
  }

  run(qw( autoreconf -v -i ));

  run(
    './configure',
    "--prefix=$target",
    @configopts,
    "XAPIAN_CONFIG=$libsdir/bin/xapian-config-1.5",
  );

  run(qw( make lex-fix ));
  run(qw( make -j 8 ));
  run(qw( make -j 8 check ));
  run(qw( sudo make install ));
  run(qw( sudo make install-binsymlinks ));
  run(qw( sudo cp tools/mkimap /usr/cyrus/bin/mkimap ));

  system('/usr/cyrus/bin/cyr_info', 'version');
}

1;
