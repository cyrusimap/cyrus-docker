use v5.36.0;

package Cyrus::Docker::Command::coverage;
use Cyrus::Docker -command;

use Process::Status;
use File::Find;
use Cwd;

sub abstract { 'generate code coverage for the cyrus-imapd repo' }

my sub run (@args) {
  system(@args);
  Process::Status->assert_ok($args[0]);
}
sub _coverage_run(@command) {
  system(@command);
  Process::Status->assert_ok("@command");
}

sub execute ($self, $, $args) {
  my $coverage_dir = 'coverage';
  my $coverage_cunit = "$coverage_dir/cunit";
  my $coverage_combined = "$coverage_dir/combined";

  my @classes = qw(
                    Cyrus::Docker::Command::clone
                    Cyrus::Docker::Command::clean
              );

  for my $class (@classes) {
    my ($cmd, $opt, @args) = $class->prepare($self->app);
    $self->app->execute_command($cmd, $opt, @args);
  }

  # This run as root, so the coverage output files from CUnit tests are written
  # by root:
  {
    # There doesn't seem to be any clean way to do this:
    local @ARGV = ('--sanitizer', 'gcov', @ARGV);
    my $class = 'Cyrus::Docker::Command::build';
    my ($cmd, $opt, @args) = $class->prepare($self->app);
    $opt->{sanitizer} = 'gcov';
    $self->app->execute_command($cmd, $opt, @args);
  }

  run('coverage', $coverage_cunit, 'CUnit tests only');

  # The Cassadene tests as user cyrus, so that user needs to be able to write to
  # existing coverage output files, and to create new output files for code not
  # covered by CUnit tests

  my %ownership;
  find({
      no_chdir => 1,
      wanted => sub {
          return
              unless -f _;
          if(/\.gcda\z/) {
              # All existing *.gcda files might need to be updated
              ++$ownership{$_};
              return;
          }
          return
              unless m!\A(.*)/[^/]+\.gcno\z!;
          # All directories containing a *.gcno file might have new *.gcda files
          # written, hence they need to be writable
          ++$ownership{$1};
      }
  }, '.');

  system('chown', 'cyrus:mail', keys %ownership);
  Process::Status->assert_ok('chowning coverage files and directories');

  my $cwd = getcwd;

  # This will chdir:
  my $class = 'Cyrus::Docker::Command::test';
  my ($cmd, $opt, @args) = $class->prepare($self->app);
  $self->app->execute_command($cmd, $opt, @args);

  chdir $cwd or die "can't chdir back to $cwd: $!";

  run('coverage', $coverage_combined, 'All tests');

  for my $file0 (glob "$coverage_cunit/index*.html") {
    my $file1 = $file0 =~ s/\Q$coverage_cunit\E/$coverage_combined/r;
    run("lcov-index-splicer.pl", $file0, $file1);
  }

  say "Coverage report in file:/$cwd/$coverage_dir/index.html";
}

1;
