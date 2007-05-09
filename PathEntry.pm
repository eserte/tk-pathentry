# -*- perl -*-

#
# $Id: PathEntry.pm,v 1.12 2007/05/09 14:23:12 k_wittrock Exp $
# Author: Slaven Rezic
#
# Copyright (C) 2001,2002,2003 Slaven Rezic. All rights reserved.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Mail: srezic@cpan.org
# WWW:  http://www.sourceforge.net/srezic
#

package Tk::PathEntry;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/);

use base qw(Tk::Derived Tk::Entry);

Construct Tk::Widget 'PathEntry';

sub ClassInit {
    my($class,$mw) = @_;
    $class->SUPER::ClassInit($mw);

    $mw->bind($class,"<Shift-Tab>" => sub {$mw->focusPrev});   # restore standard behaviour

    $mw->bind($class,"<Tab>" => sub {
		  my $w = shift;
		  if (!defined $w->{CurrentChoices}) {
		      # this is called only on init:
		      my $pathref = $w->cget(-textvariable);
		      $w->_popup_on_key($$pathref);
		  }
		  if (@{$w->{CurrentChoices}} > 0) {
		      my $pos_sep_rx = $w->_pos_sep_rx;
		      my $common = $w->_common_match;
		      my $case_rx = $w->cget(-casesensitive) ? "" : "(?i)";
		      if ($w->Callback(-isdircmd => $w, $common) &&
			  $common !~ m/$case_rx$pos_sep_rx$/             &&
			  @{$w->{CurrentChoices}} == 1
			 ) {
			  my $sep = $w->_sep;
			  $common .= $sep;
		      }
		      $w->_set_text($common);
		      $w->_popup_on_key($common);
		  } else {
		      $w->bell;
		  }
		  Tk->break;
	      });

    $mw->bind($class,"<Down>" => sub {
		  my $w = shift;
		  my $choices_t = $w->Subwidget("ChoicesToplevel");
		  # If the popup list is not displayed, display it if possible
		  $w->_popup_on_key($w->get()) if $choices_t->state eq 'withdrawn';
		  if ($choices_t && $choices_t->state ne 'withdrawn') {
		      my $choices_l = $w->Subwidget("ChoicesLabel");
		      $choices_l->focus();
		      my @sel = $choices_l->curselection;
		      if (!@sel) {
			  $choices_l->selectionSet(0);
		      }
		  }
	      });

    for ("Meta", "Alt") {
	$mw->bind($class,"<$_-BackSpace>" => '_delete_last_path_component');
	$mw->bind($class,"<$_-d>"         => '_delete_next_path_component');
	$mw->bind($class,"<$_-f>"         => '_forward_path_component');
	$mw->bind($class,"<$_-b>"         => '_backward_path_component');
    }
    $mw->bind($class,"<FocusOut>" => sub {
		  my $w = shift;
		  # Don't withdraw the choices listbox if the focus just has been passed to it.
		  return if $w->focusCurrent == $w->Subwidget("ChoicesLabel");
		  $w->Finish;
	      });

    $class;
}

sub SetBindtags{
    my($w) = @_;

    # Execute the widget bindings before the class bindings
    $w->SUPER::SetBindtags;
    my (@w_bindtags) = $w->bindtags;
    $w->bindtags( [ @w_bindtags[1, 0, 2, 3] ] );
}

sub Populate {
    my($w, $args) = @_;

    my $choices_t = $w->Component("Toplevel" => "ChoicesToplevel");
    $choices_t->overrideredirect(1);
    $choices_t->withdraw;

    my $choices_l = $choices_t->Listbox(-background => "yellow",
					-border => 0,
					-width => 0,    # use autowidth feature
				       )->pack(-fill => "both",
					       -expand => 1);
    $w->Advertise("ChoicesLabel" => $choices_l);
    # <Button-1> in the Listbox
    $choices_l->bind("<1>" => sub {
			 my $lb = shift;
			 (my $y) = $lb->curselection;
			 $w->_set_text($lb->get($y));
			 $choices_t->withdraw;
		     });
    # <Return> in the Listbox
    $choices_l->bind("<Return>" => sub {
		 # Transfer the selection to the Entry widget
		 my $lb = shift;
		 my @sel = $lb->curselection;
		 if (@sel) {
		     $w->_set_text($lb->get($sel[0]));
		 }
		 $w->Finish;
	     });
    # <Return> in the Entry
    $w->bind("<Return>" => sub {
		 $w->Finish;
		 $w->Callback(-selectcmd => $w);
	     });
    # <Escape> in the Listbox
    $choices_l->bind("<Escape>" => sub {
		 $w->Finish;
	     });
    # <Escape> in the Entry
    $w->bind("<Escape>" => sub {
		 $w->Finish;
		 $w->Callback(-cancelcmd => $w);
	     });
    $w->bind("<FocusIn>" => sub {
		 # If the focus is passed to the entry widget by <Shift-Tab>,
		 # all text in the widget gets selected. This might lateron cause
		 # unintended deletion when pressing a key.
		 $w->selectionClear();
	     });

    if (exists $args->{-vcmd} ||
	exists $args->{-validatecommand} ||
	exists $args->{-validate}) {
	die "-vcmd, -validatecommand or -validate are not allowed with PathEntry";
    }

    $args->{-vcmd} = sub {
	my($pathname) = $_[0];
	my($action)   = $_[4];
	$action -= 7 if $action > 5;   # replace actual by official value
	return 1 if $action == -1; # nothing on forced validation

	# validate directory on input of separator
	if ($action == 1) {
	    my $pos_sep_rx = $w->_pos_sep_rx;
	    my $case_rx = $w->cget(-casesensitive) ? "" : "(?i)";
	    $w->_valid_dir('Path', @_) if $pathname =~ /$case_rx$pos_sep_rx$/;
	}
	$w->_popup_on_key($pathname);

	if ($action == 1 && # only on INSERT
	    $w->{CurrentChoices} && @{$w->{CurrentChoices}} == 1 &&
	    $w->cget(-autocomplete)) {
	    # XXX the afterIdle is hackish
	    $w->afterIdle(sub { $w->_set_text($w->{CurrentChoices}[0]) });
	    return 0;
	}

	1;
    };
    $args->{-validate} = 'key';

    if (!exists $args->{-textvariable}) {
	my $pathname;
	$args->{-textvariable} = \$pathname;
    }

    $w->ConfigSpecs
	(-initialdir  => ['PASSIVE',  undef, undef, undef],
	 -initialfile => ['PASSIVE',  undef, undef, undef],
	 -separator   => ['PASSIVE',  undef, undef,
			  $^O eq "MSWin32" ? ["\\", "/"] : "/"
			  ],
	 -casesensitive => ['PASSIVE', undef, undef,
			    $^O eq "MSWin32" ? 0 : 1
			    ],
	 -isdircmd    => ['CALLBACK', undef, undef, ['_is_dir']],
	 -isdirectorycommand => '-isdircmd',
	 -choicescmd  => ['CALLBACK', undef, undef, ['_get_choices']],
	 -choicescommand     => '-choicescmd',
	 -autocomplete => ['PASSIVE'],
	 -selectcmd   => ['CALLBACK'],
	 -selectcommand => '-selectcmd',
	 -cancelcmd   => ['CALLBACK'],
	 -cancelcommand => '-cancelcmd',
	 -messagecmd  => ['CALLBACK', undef, undef, ['_show_msg']],
	);
}

sub ConfigChanged {
    my($w,$args) = @_;
    for (qw/dir file/) {
	if (defined $args->{'-initial' . $_}) {
	    $w->_set_text($args->{'-initial' . $_});
	}
    }
    # validate initial directory
    $w->_valid_dir('Initial directory', $args->{'-initialdir'})
	if (defined $args->{'-initialdir'}  &&  ! defined $args->{'-initialfile'});
}

sub Finish {
    my $w = shift;
    my $choices_t = $w->Subwidget("ChoicesToplevel");
    $choices_t->withdraw;
    $choices_t->idletasks;
    delete $w->{CurrentChoices};
    $w->focus();   # pass focus back to the Entry widget (required for Linux)
}

sub _popup_on_key {
    my($w, $pathname) = @_;
    if ($w->ismapped) {
	$w->{CurrentChoices} = $w->Callback(-choicescmd => $w, $pathname);
	if ($w->{CurrentChoices} && @{$w->{CurrentChoices}} > 1) {
	    my $choices_l = $w->Subwidget("ChoicesLabel");
	    $choices_l->delete(0, 'end');
	    $choices_l->insert('end', @{$w->{CurrentChoices}});
	    # When the focus is passed to the Listbox, the last entry is
	    # active, because the lines were inserted as a list. So pressing
	    # the down arrow would select the last entry.
	    $choices_l->activate(0);
	    $w->_show_choices($w->rootx);
	} else {
	    my $choices_t = $w->Subwidget("ChoicesToplevel");
	    $choices_t->withdraw;
	}
    }
}

sub _sep {
    my $w = shift;
    my $sep = $w->cget(-separator);
    if (ref $sep eq 'ARRAY') {
	$sep->[0];
    } else {
	$sep;
    }

}

sub _pos_sep_rx {
    my $w = shift;
    my $sep = $w->cget(-separator);
    if (ref $sep eq 'ARRAY') {
	"[" . join("", map { quotemeta } @$sep) . "]";
    } else {
	quotemeta $sep;
    }
}

sub _neg_sep_rx {
    my $w = shift;
    my $sep = $w->cget(-separator);
    if (ref $sep eq 'ARRAY') {
	"[^" . join("", map { quotemeta } @$sep) . "]";
    } else {
	"[^" . quotemeta($sep) . "]";
    }
}

sub _delete_last_path_component {
    my $w = shift;

    my $before_cursor = substr($w->get, 0, $w->index("insert"));
    my $after_cursor = substr($w->get, $w->index("insert"));
    my $pos_sep = $w->_pos_sep_rx;
    my $neg_sep = $w->_neg_sep_rx;
    $before_cursor =~ s|$neg_sep+$pos_sep?$||;
    my $pathref = $w->cget(-textvariable);
    $$pathref = $before_cursor . $after_cursor;
    $w->icursor(length $before_cursor);
    $w->_popup_on_key($$pathref);
}

sub _delete_next_path_component {
    my $w = shift;

    my $before_cursor = substr($w->get, 0, $w->index("insert"));
    my $after_cursor = substr($w->get, $w->index("insert"));
    my $pos_sep = $w->_pos_sep_rx;
    my $neg_sep = $w->_neg_sep_rx;
    $after_cursor =~ s|^$pos_sep?$neg_sep+||;
    my $pathref = $w->cget(-textvariable);
    $$pathref = $before_cursor . $after_cursor;
    $w->icursor(length $before_cursor);
    $w->_popup_on_key($$pathref);
}

sub _forward_path_component {
    my $w = shift;
    my $after_cursor = substr($w->get, $w->index("insert"));
    my $pos_sep = $w->_pos_sep_rx;
    my $neg_sep = $w->_neg_sep_rx;
    if ($after_cursor =~ m|^($pos_sep?$neg_sep+)|) {
	$w->icursor($w->index("insert") + length $1);
    }
}

sub _backward_path_component {
    my $w = shift;
    my $before_cursor = substr($w->get, 0, $w->index("insert"));
    my $pos_sep = $w->_pos_sep_rx;
    my $neg_sep = $w->_neg_sep_rx;
    if ($before_cursor =~ m|($neg_sep+$pos_sep?)$|) {
	$w->icursor($w->index("insert") - length $1);
    }
}

sub _common_match {
    my $w = shift;
    my(@choices) = @{$w->{CurrentChoices}};
    my $common = shift @choices;
    my $case_sensitive = $w->cget(-casesensitive);
    foreach (@choices) {
	my $choice = $case_sensitive ? $_ : lc $_;
	if (length $choice < length $common) {
	    $common = substr($common, 0, length $_);
	}
	$common = lc $common if !$case_sensitive;
	for my $i (0 .. length($common) - 1) {
	    if (substr($choice, $i, 1) ne substr($common, $i, 1)) {
		return "" if $i == 0;
		$common = substr($choice, 0, $i);
		last;
	    }
	}
    }
    $common;
}

sub _get_choices {
    my($w, $pathname) = @_;
    my $neg_sep = $w->_neg_sep_rx;
    if ($pathname =~ m|^~($neg_sep+)$|) {
	my $userglob = $1;
	my @users;
	my $sep = $w->_sep;
	while(my $user = getpwent) {
	    if ($user =~ /^$userglob/) {
		push @users, "~$user$sep";
		last if $#users > 50; # XXX make better optimization!
	    }
	}
	endpwent;
	if (@users) {
	    \@users;
	} else {
	    [$pathname];
	}
    } else {
	my $glob;
	$glob = "$pathname*";
	use File::Glob ':glob';   # allow whitespace in $pathname
	[ glob($glob) ];
    }
}

sub _show_choices {
    my($w, $x_pos) = @_;
    my $choices_t = $w->Subwidget("ChoicesToplevel");
    if (defined $x_pos) {
	$choices_t->geometry("+" . $x_pos . "+" . ($w->rooty+$w->height));
	$choices_t->deiconify;
	$choices_t->raise;
    }
}

sub _is_dir { -d $_[1] }

# Replace text in widget and position the cursor to the end

sub _set_text {
    my ($w, $text) = @_;

    $ {$w->cget(-textvariable)} = $text;
    $w->icursor("end");
    $w->xview("end");
}

# Warn if "directory" exists as a plain file

sub _valid_dir {
    my ($w, $type, $pathname) = @_;

    # remove trailing separators
    my $pos_sep_rx = $w->_pos_sep_rx;
    my $case_rx = $w->cget(-casesensitive) ? "" : "(?i)";
    $pathname =~ s/$case_rx$pos_sep_rx+$//;
    return unless $pathname;
    if (-e $pathname  &&  ! $w->Callback(-isdircmd => $w, $pathname)) {
	# $type is 'Path' or 'Initial directory'.
	$w->Callback(-messagecmd => $w, "$type $pathname\nis not a directory");
        # Don't suppress or attempt to autocorrect the directory.
        # Give the user the chance to correct a typo error.
    }
}

# Show message by default in messageBox

sub _show_msg {
    my ($w, $msg) = @_;

    $w->messageBox(-title => $msg =~ /^Error:/ ? 'Error' : 'Warning',
	-icon => 'warning', -message => $msg);
}

1;

__END__

=head1 NAME

Tk::PathEntry - Entry widget for selecting paths with completion

=head1 SYNOPSIS

    use Tk::PathEntry;
    my $pe = $mw->PathEntry
                     (-textvariable => \$path,
		      -selectcmd => sub { warn "The pathname is $path\n" },
		     )->pack;

=head1 DESCRIPTION

This is an alternative to classic file selection dialogs. It works
more like the file completion in modern shells like C<tcsh> or
C<bash>.

With the C<Tab> key, you can force the completion of the current path.
If there are more choices, a window is popping up with these choices.
With the C<Meta-Backspace> or C<Alt-Backspace> key, the last path
component will be deleted.

=head1 OPTIONS

B<Tk::PathEntry> supports all standard L<Tk::Entry|Tk::Entry> options
except C<-vcmd> and C<-validate> (these are used internally in
B<PathEntry>). The additional options are:

=over 4

=item -initialdir

Set the initial path to the value. Alias: C<-initialfile>. You can
also use a pre-filled C<-textvariable> to set the initial path.

=item -separator

The character used as the path component separator. This may be also
an array reference for multiple characters. For Windows, this is by
default the characters C</> and C<\>, otherwise just C</>.

=item -casesensitive

Set to a true value if the filesystem is case sensitive. For Windows,
this is by default false, otherwise true.

=item -isdircmd

Can be used to set another directory recognizing subroutine. The
directory name is passed as second parameter. Alias:
C<-isdirectorycommand>. The default is a subroutine using C<-d>.

=item -choicescmd

Can be used to set another globbing subroutine. The current pathname
is passed as second parameter. Alias: C<-choicescommand>. The
default is a subroutine using the standard C<glob> function.

=item -selectcmd

This will be called if a path is selected, either by hitting the
Return key or by clicking on the choice listbox. Alias:
C<-selectcommand>.

=item -cancelcmd

This will be called if the Escape key is pressed. Alias:
C<-cancelcommand>.

=item -autocomplete

If this is set to true, and there remains only one item in the
choice listbox, it will be transferred to the entry value automatically.

=item -messagecmd

Can be used to set a different subroutine for displaying messages. The
message is passed as the second parameter. Examples are 
C<-messagecmd => sub {print "$_[1]\n"}>, C<-messagecmd => sub {$_[0]->bell}>,
or even C<-messagecmd => undef>. The default is a subroutine using
C<messageBox>. 

=back

=head1 METHODS

=over 4

=item Finish

This will popdown the window with the completion choices. It is called
automatically if the user selects an entry from the listbox, hits the
Return or Escape key or the widget loses the focus.

=back

=head1 EXAMPLES

If you want to not require from your users to install Tk::PathEntry,
you can use the following code snippet to create either a PathEntry or
an Entry, depending on what is installed:


    my $e;
    if (!eval '
        use Tk::PathEntry;
        $e = $mw->PathEntry(-textvariable => \$file,
                            -selectcmd => sub { $e->Finish },
                           );
        1;
    ') {
        $e = $mw->Entry(-textvariable => \$file);
    }
    $e->pack;

=head1 NOTES

Since C<Tk::PathEntry> version 2.17, it is not recommended to bind the
Return key directly. Use the C<-selectcmd> option instead.

=head1 TODO

=over

=item * Check color settings on Windows

=item * Add ctrl-tab or another key as tab replacement

=back

=head1 SEE ALSO

L<Tk::PathEntry::Dialog (3)|Tk::PathEntry::Dialog>,
L<Tk::Entry (3)|Tk::Entry>, L<tcsh (1)|tcsh>, L<bash (1)|bash>.

=head1 AUTHOR

Slaven Rezic <srezic@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2001,2002 Slaven Rezic. All rights
reserved. This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

