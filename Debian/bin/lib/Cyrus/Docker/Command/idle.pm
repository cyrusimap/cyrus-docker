use v5.36.0;

package Cyrus::Docker::Command::idle;
use Cyrus::Docker -command;

use Process::Status;
use Term::ANSIColor qw(colored);

sub abstract { 'sleep forever, to keep a container running' }

sub execute ($self, $opt, $args) {
  my $motd = <<~'END';
            /////  |||| Cyrus IMAP docker image
          /////    |||| IDLE mode (not to be confused with IMAP IDLE)
        /////      ||||
      /////        |||| If you're seeing this, that's weird.
    /////          ||||
    \\\\\          |||| IDLE mode is most useful for a detached
      \\\\\        |||| container in which you exec more commands later.
        \\\\\      ||||
          \\\\\    ||||
            \\\\\  ||||
  END

  $motd =~ s{([/|\\]+)}{colored(['bright_cyan'], "$1")}ge;
  $motd =~ s{• \K([^-]+)}{colored(['bright_yellow'], "$1")}ge;
  print $motd;

  sleep 60 while 1;
}

1;
