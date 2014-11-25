#!/usr/bin/env perl

package Runner::MCE;

use MCE;
use MCE::Queue;
use DateTime;
use DateTime::Format::Duration;

use Moose;
extends 'Runner::Init';

=head1 NAME

Runner::MCE

=head1 VERSION

Version 0.01

=cut

our $VERSION = '1.6';

=head1 SYNOPSIS

Use MCE and MCE::Queue to run arbitrary bash commands in parallel using processes. 

=cut

=head1 Variables

=cut

has 'queue' => (
    traits  => ['NoGetopt'],
    is => 'rw',
    lazy => 0,  ## must be 0 to ensure the queue is created prior to spawning
    default => sub {
        my $self = shift;
        return MCE::Queue->new();
    }
);

has 'mce' => (
    traits  => ['NoGetopt'],
    is => 'rw',
    lazy => 1,
    default => sub {
        my $self = shift;
        return MCE->new(
            max_workers => $self->procs, use_threads => 0, user_func => sub {
               my $mce = shift;
               while (1) {
                  my ($counter, $cmd) = $self->queue->dequeue(2);
                  last unless defined $counter;
                  $self->counter($counter);
                  $self->cmd($cmd);
                  $self->run_command_mce();
               }
            }
        );
    }
);

has 'using_mce' => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
    required => 1,
);


=head1 SUBROUTINES/METHODS

=cut

=head2 go

Initialize MCE things and use Runner::Init to parse and exec commands

=cut

sub go{
    my $self = shift;

    my $dt1 = DateTime->now();

    $self->prepend_logfile("MAIN_");
    $self->log($self->init_log);
    $self->mce->spawn;

    #MCE specific
    $self->parse_file_mce;

# MCE workers dequeue 2 elements at a time. Thus the reason for * 2.
    $self->queue->enqueue((undef) x ($self->procs * 2));
# MCE will automatically shutdown after running for 1 or no args.
    $self->mce->run(1);
    #End MCE specific

    my $dt2 = DateTime->now();
    my $duration = $dt2 - $dt1;
    my $format = DateTime::Format::Duration->new(
        pattern => '%Y years, %m months, %e days, %H hours, %M minutes, %S seconds'
    );

    $self->log->info("Total execution time ".$format->format_duration($duration));
    return;
}

=head2 parse_file_mce

The default method of parsing the file. 

    #starts a comment
    wait - says wait until all other processes/threads exitcode

    #this is a one line command
    echo "starting" 

    #This is a multiline command
    echo "starting line 1" \
        echo "starting line 2" \
        echo "finishing

=cut

sub parse_file_mce{
    my $self = shift;

    my $fh = IO::File->new( $self->infile, q{<} ) or $self->log->fatal("Error opening file  ".$self->infile."  ".$!); 
    die unless $fh;

    my $cmd;
    while(<$fh>){
        my $line = $_;
        next unless $line;
        next unless $line =~ m/\S/;
        next if $line =~ m/^#/;

        if($self->has_cmd){
            $self->add_cmd($line);
            if($line =~ m/\\$/){
                next;
            }
            else{
                $self->log->info("Enqueuing command:\n".$self->cmd);
                #MCE
                $self->queue->enqueue($self->counter, $self->cmd);
                #Threads
#                $self->run_command_threads;
                $self->clear_cmd;
                $self->inc_counter; 
            }
        }
        else{
            $self->cmd($line);
            if($line =~ m/\\$/){
                next;
            }
            elsif( $self->match_cmd("wait") ){
                $self->log->info("Beginning command:\n".$self->cmd);
                $self->log->info("Waiting for all children to complete...");
                $self->clear_cmd;
                #MCE
                $self->queue->enqueue((undef) x ($self->procs * 2));
                $self->mce->run(0);  # 0 indicates do not shutdown after running
#                #THREADS
#                $self->threads->wait_all_children;
                $self->log->info("All children have completed processing!");
                $self->inc_counter; 

            }
            else{
                $self->log->info("Enqueuing command:\n".$self->cmd);
                #MCE
                $self->queue->enqueue($self->counter, $self->cmd);
#                #Threads
#                $self->run_command_threads;
                $self->clear_cmd;
                $self->inc_counter; 
            }
        }
    }

}

#use namespace::autoclean;
1; 

=head1 AUTHOR

Jillian Rowe, C<< <jillian.e.rowe at gmail.com> >>
Mario Roy, C<< <marioeroy at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-runner-init at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Runner-Init>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Runner::MCE


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Runner-Init>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Runner-Init>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Runner-Init>

=item * Search CPAN

L<http://search.cpan.org/dist/Runner-Init/>

=back


=head1 ACKNOWLEDGEMENTS

This module was originally developed at and for Weill Cornell Medical College in Qatar. With approval from WCMC-Q, this information was generalized and put on github, for which the authors would like to express their gratitude.

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Jillian Rowe.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut
# End of Runner::MCE

