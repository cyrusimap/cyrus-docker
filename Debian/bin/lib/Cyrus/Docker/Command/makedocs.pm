use v5.36.0;

package Cyrus::Docker::Command::makedocs;
use Cyrus::Docker -command;

use Process::Status;

sub abstract { 'make the docs site using Sphinx' }

sub execute ($self, $opt, $args) {
  my $root = "/srv/cyrus-imapd/docsrc";
  chdir $root or die "can't chdir to $root: $!";

  system('make', 'html');
  Process::Status->assert_ok('making "html" target');
}

1;
