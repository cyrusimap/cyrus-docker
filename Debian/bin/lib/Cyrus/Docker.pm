package Cyrus::Docker;
use v5.36.0;

use Path::Tiny;

use App::Cmd::Setup 0.336 -app => {
  getopt_conf => [],
};

sub repo_root ($self) {
  $self->{root} //= do {
    my $path = $ENV{CYRUS_CLONE_ROOT} || '/srv/cyrus-imapd';
    path($path);
  };
}

1;
