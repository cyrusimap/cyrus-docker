package Cyrus::Docker;
use v5.36.0;

use JSON::XS ();
use Path::Tiny ();

use App::Cmd::Setup 0.336 -app => {
  getopt_conf => [],
};

sub repo_root ($self) {
  $self->{root} //= do {
    my $path = $ENV{CYRUS_CLONE_ROOT} || '/srv/cyrus-imapd';
    Path::Tiny::path($path);
  };
}

sub config ($self) {
  $self->{config} //= do {
    my $path = Path::Tiny::path('/etc/cyrus-docker.json');
    $path->exists ? JSON::XS::decode_json($path->slurp)
                  : {}
  };
}

1;
