use v5.36.0;

package Cyrus::Docker::Command::clean;
use Cyrus::Docker -command;

use Process::Status;

sub execute ($self, $opt, $args) {
  my $root = "/srv/cyrus-imapd";
  chdir $root or die "can't chdir to $root: $!";

  # -d: recurses into untracked directories
  # -X: only delete files we ignore, so we don't delete new .c files (e.g.)
  # -f: actually delete things
  system(qw( git clean -dfX ));
  Process::Status->assert_ok("git clean");
}

1;
