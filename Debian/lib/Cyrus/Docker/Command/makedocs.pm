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
  my $root = $self->app->repo_root;
  chdir $root or die "can't chdir to $root: $!";

  require Path::Tiny;
  my $status = Path::Tiny::path("config.status");
  my $have_sphinx;
  LINE: for my $line ($status->exists ? $status->lines : ()) {
    if ($line =~ m{^S\["SPHINX_BUILD"\]="[^"]+"$}m) {
      $have_sphinx = 1;
      last LINE;
    }
  }

  if ($have_sphinx) {
    say "already configured with sphinx, great!";
  } else {
    my $class = 'Cyrus::Docker::Command::build';
    my ($cmd, $opt, @args) = $class->prepare($self->app, qw(--with-sphinx -n));
    $self->app->execute_command($cmd, $opt, @args);
  }

  # I would prefer to use long form options, but they are not added until
  # Sphinx v7, and we are using v5 right now. -- rjbs, 2025-01-10
  # trixie packages Sphinx v8
  #
  # -n is "--nitpicky"
  # -W is "--fail-on-warning"
  local $ENV{SPHINXOPTS} = q{SPHINXOPTS=-n -W};
  system('make doc');
  Process::Status->assert_ok('making "doc" target');
}

1;
