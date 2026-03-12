use v5.36.0;

package Cyrus::Docker::Command::clone;
use Cyrus::Docker -command;

use Path::Tiny;
use Process::Status;

sub abstract { 'clone the cyrus-imapd source tree to /srv, if not present' }

sub execute ($self, $opt, $arg) {
  my $root = $self->app->repo_root;
  my $repo = 'https://github.com/cyrusimap/cyrus-imapd.git';

  # Not yet initialized.  Clone!
  if ($root->exists) {
    say "$root already exists, not cloning";
    return;
  }
  my $parent = $root->parent;
  chdir $parent or die "Can't chdir $parent: $!";

  system(qw(git clone -o github), $repo);
  Process::Status->assert_ok("cloning $repo");
}

1;
