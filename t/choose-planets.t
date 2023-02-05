#!/usr/bin/perl -w
# -*- perl -*-

# In this test script Tk::PathEntry is "misused" as a selector of
# multiple items within one Entry widget, with the help of
# autocompletion. This specific script helps you to create a
# comma-separated list out of the eight solar system planets.
#
# To try it out, run
#
#    BATCH=0 perl -Mblib t/choose-planets.t
#
# after
#
#    perl Makefile.PL
#    make
#
# Please see below how -isdircmd and -choicescmd need to be
# defined.

use strict;
use warnings;

use Test::More;

use Tk;
use Tk::PathEntry;


my $mw = eval { tkinit };
plan skip_all => 'cannot create main window: $@' if !$mw;

plan 'no_plan';

if (!defined $ENV{BATCH}) { $ENV{BATCH} = 1 }

# A list of items to choose from.
my @items = qw(
		  Mercury
		  Venus
		  Earth
		  Mars
		  Jupiter
		  Saturn
		  Uranus
		  Neptune
	     );
# A set created from these items.
my %items = map {($_,1)} @items;

my $choosen_items;
# The separator between items. Additionally the isdircmd & choicescmd
# callbacks are written such that extra space after the comma is
# allowed.
my $sep = ',';

$mw->title("Select planets:");
$mw->minsize(300,50);

my $pe = $mw->PathEntry
    (-textvariable => \$choosen_items,
     -separator => $sep,
     -casesensitive => 0,

     # The custom -isdircmd callback needs to return true if
     # the last component of the Entry is a complete item.
     -isdircmd => sub {
	 my $choosen_items = $_[1];
	 if ($choosen_items =~ m{(?:^|.*\Q$sep\E\s*)(.*)}) {
	     if ($items{$1}) {
		 return 1;
	     }
	 }
	 return 0;
     },
     # The custom -choicescmd callback first finds out which of the
     # items are already selected and put them into the set
     # %choosen_items; these are not presented again by the
     # autocompletion. Then the left available items are
     # prefix-filtered by last entered item. Note that every element
     # of the output array needs to consist of the previously entered
     # items, too.
     -choicescmd => sub {
	 my($w, $choosen_items) = @_;
	 my %choosen_items;
	 if ($choosen_items =~ /^(.*)\Q$sep\E/) {
	     %choosen_items = map {($_,1)} split /\Q$sep\E\s*/, $1;
	 }
	 my @available_items = grep { !$choosen_items{$_} } @items;

	 if ($choosen_items =~ m{(.*\Q$sep\E\s*|^)(.*)}) {
	     my($existing, $begin) = ($1, $2);
	     @available_items = map { "$existing$_" } grep { m{^\Q$begin} } @available_items;
	 }

	 \@available_items;
     })->grid(-sticky => "ew");

$mw->gridColumnconfigure(0, -weight => 1);
ok Tk::Exists($pe);
$pe->focus;

$mw->Label(-textvariable => \$choosen_items)->grid;

$mw->Button(-text => "OK",
	    -command => sub { $mw->destroy })->grid;

if ($ENV{BATCH}) { $mw->after(1000, sub { $mw->destroy }) }

MainLoop;

__END__
