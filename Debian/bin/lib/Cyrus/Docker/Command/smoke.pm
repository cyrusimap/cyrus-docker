use v5.36.0;

package Cyrus::Docker::Command::smoke;
use Cyrus::Docker -command;

use Process::Status;

sub execute ($self, $opt, $args) {
  my @classes = qw(
    Cyrus::Docker::Command::clone
    Cyrus::Docker::Command::build
    Cyrus::Docker::Command::test
  );

  for my $class (@classes) {
    my ($cmd, $opt, @args) = $class->prepare($self->app);
    $self->app->execute_command($cmd, $opt, @args);
  }
}

1;
