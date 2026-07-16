use v5.36.0;

package Cyrus::Docker::Command::build;
use Cyrus::Docker -command;

use Process::Status;
use Term::ANSIColor qw(colored);

my sub run (@args) {
  say "running: @args";
  system(@args);
  Process::Status->assert_ok($args[0]);
}

sub abstract { 'configure, build, and install cyrus-imapd' }

sub description {
  return <<~'END';
  Configure, build, "make check", and install cyrus-imapd from the checkout at
  /srv/cyrus-imapd (or wherever CYRUS_CLONE_ROOT points).

  This is the canonical way Cyrus is built for development and CI.  The set of
  ./configure options used here is the *reference build configuration*: if you
  ever need to build Cyrus by hand, the list in the configure() method below is
  the one to copy.

  Common combinations:
    build         configure, build, run the fast CUnit checks, and install
    build -r      recompile a previous build (skip configure)
    build -n      skip the "make check" step
    build -nr     recompile, skipping both configure and "make check"
  END
}

# gcov isn't strictly a sanitizer, but it's easier to implement it as one
# (and it doesn't make sense to run coverage on a sanitizer build, even if the
# compiler would let us)

sub opt_spec {
  return (
    [ 'recompile|r', 'recompile, make check, and install a previous build' ],
    [ 'with-sphinx|s', 'enable sphinx docs' ],
    [ 'with-sasl=s', 'build with SASL from this directory' ],
    [ 'jobs|j=i',    'specify number of parallel jobs (default: 8) to run for make/make check',
                     { default => 8 },
    ],

    [ 'cunit-style' => hidden => { default => 'check_fast', one_of => [
      [ 'check'          => 'run make check'                 ],
      [ 'check-discrete' => 'run make check-discrete'        ],
      [ 'check-fast'     => 'run make check-fast (default)', ],
    ] } ],
    [ 'n' => 'skip make check* step', { implies => { 'cunit_style' => '' } } ],

    # back compat
    [ 'cunit' => "hidden" => { implies => { 'cunit_style' => 'check' } } ],

    [ 'sanitizer' => hidden => { one_of => [
      [ 'asan'  => 'build with AddressSanitizer' ],
      [ 'ubsan' => 'build with UBSan' ],
      [ 'ubsan-trap' => 'build with UBSan and trap on error' ],
      [ 'cover'  => 'build with gcov' ],
    ] } ],
    [ 'compiler' => hidden => { one_of => [
      [ 'gcc' => 'gcc', ],
      [ 'clang' => 'clang', ],
    ] } ],
    [ 'cflags=s' => 'additional flags to include in CFLAGS' ],
    [ 'cxxflags=s' => 'additional flags to include in CXXFLAGS' ],
  );
}

sub execute ($self, $opt, $args) {
  my $root = $self->app->repo_root;
  chdir $root or die "can't chdir to $root: $!";

  $self->configure($opt) unless $opt->recompile;

  my @jobs = ("-j", $self->app->config->{default_jobs} // $opt->jobs);

  run(qw( make                          ), @jobs);

  if (my $target = $opt->cunit_style) {
    $target =~ s/_/-/;

    run("make", $target, @jobs);
  }

  run(qw( sudo make install             ), @jobs);
  run(qw( sudo make install-binsymlinks ), @jobs);
  run(qw( sudo cp tools/mkimap /usr/cyrus/bin/mkimap ));

  system('/usr/cyrus/bin/cyr_info', 'version');
}

sub configure ($self, $opt) {
  my $version = `./tools/git-version.sh`;
  Process::Status->assert_ok("determining git version");

  chomp $version;

  if ($version eq 'unknown') {
    die "git-version.sh can't decide what version this is; giving up!\n";
  }

  # This is the reference ./configure invocation: the full set of features we
  # build and test in CI.  Build Cyrus by hand and this is the list to copy.  A
  # few that aren't self-explanatory:
  #
  #   --enable-unit-tests  builds the CUnit suite ("make check")
  #   --enable-xapian      search; needs the newer libs from cyruslibs (above)
  #   --enable-debug-slowio deliberately slows some I/O to surface ordering bugs
  #   --enable-jmap / --enable-http  the httpd subsystem (JMAP, *DAV)
  my @configopts = qw(
    --enable-autocreate
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
    --with-ldap=/usr
    --with-nghttp2
    --with-sqlite=yes
  );

  push @configopts, '--with-sphinx-build=no' unless $opt->with_sphinx;

  push @configopts, '--with-sasl=' . $opt->with_sasl if defined $opt->with_sasl;

  my $with_sanitizer = $opt->sanitizer ? " with " . $opt->sanitizer : "";

  my $san_flags = q{};
  my $san_ldflags = q{};

  if ($opt->sanitizer) {
    $san_flags = '-fno-omit-frame-pointer';

    if ($opt->sanitizer eq 'asan') {
      $san_flags .= ' -fsanitize=address';

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
      $san_flags .= ' -fsanitize=undefined';

      $ENV{UBSAN_OPTIONS} = "print_stacktrace=1:halt_on_error=1";

      if ($opt->sanitizer eq 'ubsan_trap') {
        $san_flags .= ' -fsanitize-undefined-trap-on-error';
      }

      if (! $opt->compiler) {
        # As gcc is our default compiler, and no special flags are needed, a
        # warning here feels like just noise (contrast with the asan case above)
      } elsif ($opt->compiler eq 'clang') {
        # https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html
        #    When the -fsanitize=undefined option is used to link a program,
        #    the GCC driver automatically links against libubsan.
        # clang offers no such luxury, and hence libcyrus.so and libcyrus_min.so
        # have unresolved references to __ubsan_handle_type_mismatch_v1
        $san_ldflags .= ' -lubsan';
      }
    } elsif ($opt->sanitizer eq 'cover') {
      # lcov was fine without this, but gcovr needs it
      # Leaving it in, as other alternative tools we trial might want it too:
      $san_flags .= " -fprofile-abs-path";

      push @configopts, '--enable-coverage';
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

  my $libsdir = '/usr/local/cyruslibs';
  my $target  = '/usr/cyrus';

  # The filename for xapian-config might end with a version string like "-N.N"
  # if it's a development snapshot, the stable release has no trailing version.
  # Prefer building with the stable release config if both exist.
  my ($xapian_config) = sort glob("$libsdir/bin/xapian-config*");
  die "No xapian-config binary found in $libsdir/bin\n" unless $xapian_config;

  my $more_cflags = $opt->cflags // "";
  my $more_cxxflags = $opt->cxxflags // "";

  local $ENV{LDFLAGS} = "$san_ldflags -L$libsdir/lib/x86_64-linux-gnu -L$libsdir/lib -Wl,-rpath,$libsdir/lib/x86_64-linux-gnu -Wl,-rpath,$libsdir/lib";
  local $ENV{PKG_CONFIG_PATH} = "$libsdir/lib/x86_64-linux-gnu/pkgconfig:$libsdir/lib/pkgconfig:\$PKG_CONFIG_PATH";
  local $ENV{CFLAGS} = "$san_flags -g -fPIC -W -Wall -Wextra -Werror -Wwrite-strings -Wformat=2 $more_cflags";
  local $ENV{CXXFLAGS} = "$san_flags -g -fPIC -W -Wall -Wextra -Werror $more_cxxflags";
  local $ENV{PATH} = "$libsdir/bin:$ENV{PATH}";

  run(qw( autoreconf -v -i ));

  run(
    './configure',
    "--prefix=$target",
    @configopts,
    "XAPIAN_CONFIG=$xapian_config",
  );
}

1;
