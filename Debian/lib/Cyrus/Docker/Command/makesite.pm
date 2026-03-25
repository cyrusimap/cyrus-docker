use v5.36.0;

package Cyrus::Docker::Command::makesite;
use Cyrus::Docker -command;

use Process::Status;
use Path::Tiny;

sub abstract { 'make the site docs tree using Sphinx' }

# This code is from build-cyrus-site in the cyrusimap.github.io repository
# In turn, that came from run-gp.pl in the branch perl-rewrite in the
# cyrusimap.org repository

# FIXME - there are a lot of variants of this subroutine in this tree. We should
# refactor to de-duplicate them

my sub run_or_die ($cmd, @args) {
  # This is from the original - do we still need this?
  local $ENV{PATH} = join(q{:}, qw( /usr/local/bin /usr/bin /bin ));

  say "===> running $cmd @args";
  system $cmd $cmd, @args;
  Process::Status->assert_ok($cmd);
}

my sub archive_copy ($version) {
  return $version => {
    repo       => 'archive',
    branch     => 'master',
    is_archive => 1,
    version    => $version,
    paths      => [ "/$version" ],
  };
}

my sub cyrus_branch ($branch, $paths = undef) {
  return (
    $branch => {
      repo   => 'imapd',
      branch => $branch,
      paths  => $paths // [ "/" . ($branch =~ s{^cyrus-imapd-}{}r) ]
    },
  );
}

sub execute ($self, $opt, $args) {
  # A semi-persistent working directory
  # (unclear if we still need this. It was intended in the original to reduce
  # the number of git clones, but this implementation solves that problem with
  # --reference)
  my $workdir = Path::Tiny->cwd('.');
  my $basedir = path('/tmp/CYRUS_DOCS_BUILD_DIR');

  my $builddir = $basedir->child('cyrus-site');

  my %repo = (
    sasl    => 'https://github.com/cyrusimap/cyrus-sasl.git',
    imapd   => 'https://github.com/cyrusimap/cyrus-imapd.git',
    archive => 'https://github.com/cyrusimap/cyrusimap.github.io.git',
);

  my %source = (
    'cyrus-sasl' => {
      repo    => 'sasl',
      branch  => 'master',
      paths   => [ '/sasl' ],
    },

    cyrus_branch('master', [ '/dev' ]),

    archive_copy('2.5'),
    archive_copy('3.0'),
    archive_copy('3.2'),
    archive_copy('3.4'),
    archive_copy('3.6'),

    cyrus_branch('cyrus-imapd-3.8'),
    cyrus_branch('cyrus-imapd-3.10'),
    cyrus_branch('cyrus-imapd-3.12', [ '/3.12', '/', '/stable' ]),
  );


  # set up our basedir
  $basedir->mkdir unless $basedir->is_dir;
  chdir $basedir or die "chdir $basedir: $!\n";

  # pull the target
  if ($builddir->is_dir) {
    say "#### we already have a build directory, cool...";
  } else {
    say "#### creating a build dir...";
    $builddir->mkdir;
  }

  # build the docs from each source
  my %current;
  foreach my $source_name (sort keys %source) {
    say "::group::building $source_name section of site"; # GitHub Actions log

    my $details = $source{$source_name};
    my $dir = $basedir->child($details->{is_archive} ? $details->{repo} : $source_name);
    my $branch = $details->{branch} || $source_name;

    # first make sure we have the source tree
    if ($current{$dir}++) {
      # We've already updated this checkout in this run
      # Currently this will only be reached for the archive_copy() directories
    } elsif (!$dir->is_dir) {
      my $repo_url = $repo{ $details->{repo} };

      say "#### cloning repo for $source_name...";
      run_or_die('git', 'clone', $repo_url,
                 '--branch', $branch,
                 '--single-branch',
                 '--no-tags',
                 '--depth', 1,
                 # We can add this unconditionally. git doesn't really care if
                 # we're cloning cyrus-sasl with cyrus-imapd as our reference
                 '--reference', $self->app->repo_root,
                 $dir);
    } else {
      say "#### updating repo for $source_name...";
      run_or_die('git', '-C', $dir, 'fetch', 'origin');
    }

    my $src;

    if ($details->{is_archive}) {
      $src = $dir->child('archived-versions', $details->{version});
      say "#### will use archived version from $src...";
    } else {
      say "#### building docs for $source_name...";
      run_or_die('git', '-C', $dir, 'checkout', '-q', "origin/$branch");
      run_or_die('make', '-C', $dir->child('docsrc'), 'html');

      $src = $basedir->child($source_name, qw(docsrc build html));
    }

    for my $path ($details->{paths}->@*) {
      say "#### rsyncing $source_name docs to $path...";
      my $dst = $builddir->child($path);

      # n.b. trailing / on src argument is load-bearing
      run_or_die('rsync', '-av', "$src/", $dst);
    }

    say "::endgroup::"; # GitHub Actions log
  }

  say "#### all done!";
}

1;
