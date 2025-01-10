use v5.36.0;

package Cyrus::Docker::Command::makedocs;
use Cyrus::Docker -command;

use Process::Status;

sub abstract { 'make the docs site using Sphinx' }

sub execute ($self, $opt, $args) {
  my $root = $self->app->repo_root->child('docsrc');
  chdir $root or die "can't chdir to $root: $!";

  # I would prefer to use long form options, but they are not added until
  # Sphinx v7, and we are using v5 right now. -- rjbs, 2025-01-10
  #
  # -n is "--nitpicky"
  # -W is "--fail-on-warning"
  system('make', q{SPHINXOPTS=-n -W}, 'html');
  Process::Status->assert_ok('making "html" target');
}

1;
