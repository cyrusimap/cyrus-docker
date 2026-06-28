use v5.36.0;

package Cyrus::Docker::Command::smoke;
use Cyrus::Docker -command;

use Process::Status;

sub abstract { 'build and test the contents of cyrus-imapd repo' }

sub description {
  return <<~'END';
  The all-in-one shortcut: clone (if needed), clean, build, and test.  CI runs
  effectively this: cyd build, then cyd test.  smoke is a good single command
  to confirm a checkout is healthy.
  END
}

sub execute ($self, $opt, $args) {
  my @classes = qw(
    Cyrus::Docker::Command::clone
    Cyrus::Docker::Command::clean
    Cyrus::Docker::Command::build
    Cyrus::Docker::Command::test
  );

  for my $class (@classes) {
    my ($cmd, $opt, @args) = $class->prepare($self->app);
    $self->app->execute_command($cmd, $opt, @args);
  }
}

1;
