#!/usr/bin/perl
use v5.36.0;

use utf8;

package Cyrus::Docker::Command::shell;
use Cyrus::Docker -command;
use Term::ANSIColor qw(colored);

sub abstract { 'run a shell' }

sub command_names ($self, @rest) {
  my @names = $self->SUPER::command_names(@rest);
  return (@names, 'sh');
}

sub do_motd {
  my $menu = <<~'END';
            /////  |||| Cyrus IMAP docker image
          /////    |||| Run cyrus-docker (or "cyd") as:
        /////      ||||
      /////        ||||  • cyd clone  - clone cyrus-imapd.git from GitHub
    /////          ||||  • cyd prep   - configure, build, check, and install
    \\\\\          ||||  • cyd test   - run the cyrus-imapd test suite
      \\\\\        ||||  • cyd smoke  - clone, prep, and test
        \\\\\      ||||
          \\\\\    ||||  • cyd shell  - run a shell in the container
            \\\\\  ||||
  END

  $menu =~ s{([/|\\]+)}{colored(['bright_cyan'], "$1")}ge;
  $menu =~ s{• \K([^-]+)}{colored(['bright_yellow'], "$1")}ge;
  print $menu;

  # -t *STDOUT -- detect that we have a tty
  # I have not yet found a reliable test for "is interactive" (-i).
  unless (-t *STDOUT) {
    say "❗️ It looks like you ran this from a non-interactive container.";
    say "❗️ You probably want to use: docker run -ti [image]";
    exit;
  }
}

sub execute ($self, $opt, $args) {
  $self->do_motd;
  exec 'bash';
}

1;
