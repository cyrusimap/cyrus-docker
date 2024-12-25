use v5.36.0;

package Cyrus::Docker::Command::clone;
use Cyrus::Docker -command;

use Path::Tiny;
use Process::Status;

sub execute ($self, $opt, $arg) {
  my $root = '/srv';
  my $repo = 'https://github.com/cyrusimap/cyrus-imapd.git';

  # Not yet initialized.  Clone!
  if (-d "$root/cyrus-imapd") {
    say "$root/cyrus-imapd already exists, not cloning";
    return;
  }

  system(qw(git clone -o github), $repo);
  Process::Status->assert_ok("cloning $repo");
}

1;
