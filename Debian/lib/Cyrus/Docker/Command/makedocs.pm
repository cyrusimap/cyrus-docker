use v5.36.0;

package Cyrus::Docker::Command::makedocs;
use Cyrus::Docker -command;

use Process::Status;

sub abstract { 'make the docs tree using Sphinx' }

sub description {
  return <<~'END';
  Build the cyrus-imapd documentation site (docsrc/) with Sphinx, writing HTML
  to docsrc/build/html.  This is the right way to preview documentation changes
  locally.  The build runs nitpicky and warnings-as-errors (-n -W), so a doc
  change that builds clean here will build clean in CI.
  END
}

sub execute ($self, $opt, $args) {
  my $root = $self->app->repo_root->child('docsrc');
  chdir $root or die "can't chdir to $root: $!";

  # I would prefer to use long form options, but they are not added until
  # Sphinx v7, and we are using v5 right now. -- rjbs, 2025-01-10
  # trixie packages Sphinx v8
  #
  # -n is "--nitpicky"
  # -W is "--fail-on-warning"
  system('make', q{SPHINXOPTS=-n -W}, 'html');
  Process::Status->assert_ok('making "html" target');
}

1;
