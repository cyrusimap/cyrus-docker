#!/usr/bin/perl

use strict;
use warnings;
use feature 'signatures';
use Path::Tiny;

require HTML::Tree;

my @sources = map { path($_) } @ARGV;
my @trees;

for my $file (@sources) {
  my $tree = HTML::Tree->new_from_file( $file->stringify );
  push @trees, $tree;

  my $leafdir = $file->parent->basename;

  for my $tuple ($tree->extract_links->@*) {
    my ($link, $element, $attr, $tag) = @$tuple;
    # The sideways links to the various sorted index files stay at this level
    next
      if $link =~ m!\Aindex[^/]*\.html\z!;
    # Absolute URLs don't need a directory name prepended
    next
      if $link =~ m!://! || $link =~ m!^A/!;
    $element->attr( $attr => "$leafdir/$link" );
  }
}

my $outfile = $sources[0]->parent->parent->child( $sources[0]->basename );
my $splice_point;

for my $tree (@trees) {
  my $source = shift @sources;

  my $body = $tree->find( 'body' );

  die "$0: $source has no <BODY>"
    unless $body;

  my @content = $body->content_list;

  my $have = join ",", map { $_->tag } @content;
  my $want = 'table,center,br,table,br';

  die "$0: $source BODY has tags $have; expected $want"
    unless $have eq $want;

  my ($header_table, $directory_table, $br) = @content;

  unless ($splice_point) {
    # The tree for the first file. We spice into this, at the br just
    # before the footer table
    $splice_point = $br;
    next;
  }

  # First line of the header table is the "title", which for us is the one-line
  # git log message. Don't wnat that twice
  ($header_table->content_list)[0]->delete;

  $splice_point->preinsert( $br );
  $splice_point->preinsert( $header_table );
  $splice_point->preinsert( $directory_table );
}

$outfile->spew( $trees[0]->as_HTML );
