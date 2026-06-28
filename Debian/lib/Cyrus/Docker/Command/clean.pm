use v5.36.0;

package Cyrus::Docker::Command::clean;
use Cyrus::Docker -command;

use Process::Status;

sub abstract { 'clean all build artifacts in the cyrus-imapd source tree' }

sub description {
  return <<~'END';
  Remove build artifacts from the checkout with "git clean".  This only deletes
  git-ignored files (the -X flag), so new source files you haven't yet added are
  safe; it will not blow away uncommitted work the way a plain "git clean -dfx"
  would.
  END
}

sub execute ($self, $opt, $args) {
  my $root = $self->app->repo_root;
  chdir $root or die "can't chdir to $root: $!";

  # -d: recurses into untracked directories
  # -X: only delete files we ignore, so we don't delete new .c files (e.g.)
  # -f: actually delete things
  system(qw( git clean -dfX ));
  Process::Status->assert_ok("git clean");
}

1;
