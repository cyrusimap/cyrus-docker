use v5.36.0;

package Cyrus::Docker::Command::checkout;
use Cyrus::Docker -command;

use Path::Tiny;
use Process::Status;

sub execute ($self, $opt, $arg) {
  my $root = '/srv';
  my $repo = 'https://github.com/cyrusimap/cyrus-imapd.git';
  my $head = 'master';

  # Not yet initialized.  Clone!
  unless (-d "$root/cyrus-imapd") {
    system(qw(git clone -o github), $repo);
    Process::Status->assert_ok("cloning $repo");
    return;
  }

  # Already there.  Fetch and update.
  chdir("$root/cyrus-imapd") or die "can't chdir: $!\n";

  system(qw(git fetch github));
  Process::Status->assert_ok("fetching from github");

  system(qw(git switch -C), $head, "github/$head");
  Process::Status->assert_ok("updating $head to github/$head");
}

1;
