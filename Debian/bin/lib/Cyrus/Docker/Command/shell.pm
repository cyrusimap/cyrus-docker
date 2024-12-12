#!/usr/bin/perl
use v5.36.0;

use utf8;

package Cyrus::Docker::Command::shell;
use Cyrus::Docker -command;
use Term::ANSIColor qw(colored);

sub do_motd {
  my $menu = <<~'END';
            /////  ||||
          /////    |||| Cyrus IMAP docker image
        /////      |||| Run cyrus-docker (or "cyd") as:
      /////        ||||
    /////          ||||  • cyd checkout - check out cyrus-imapd.git
    \\\\\          ||||  • cyd build    - build your checked out cyrus-imapd
      \\\\\        ||||  • cyd test     - run the cyrus-imapd test suite
        \\\\\      ||||
          \\\\\    ||||
            \\\\\  ||||
  END

  $menu =~ s{([/|\\]+)}{colored(['bright_cyan'], "$1")}ge;
  $menu =~ s{• \K([^-]+)}{colored(['bright_yellow'], "$1")}ge;
  print $menu;
}

sub execute ($self, $opt, $args) {
  $self->do_motd;
  exec 'bash';
}

1;
