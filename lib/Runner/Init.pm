package Runner::Init;

#use 5.006;

use Carp;
use Data::Dumper;
use IPC::Open3;
use IO::Select;
use Symbol;
use Log::Log4perl qw(:easy);
use DateTime;
use DateTime::Format::Duration;
use Cwd;
use File::Path qw(make_path);
use File::Spec;

use Moose;
use Moose::Util::TypeConstraints;
with 'MooseX::Getopt';


=head1 NAME

Runner::Init 

=head1 VERSION

Version 0.01

=cut

our $VERSION = '1.4';

=head1 SYNOPSIS


This is a base class for Runner::MCE and Runner:Threads. You should not need to call this module directly.

=head1 EXPORT
=cut

=head1 VARIABLES

=cut

=head2 infile

File of commands separated by newline. The command 'wait' indicates all previous commands should finish before starting the next one.

=cut

has 'infile' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    documentation => q{File of commands separated by newline. The command 'wait' indicates all previous commands should finish before starting the next one.},
    trigger => \&_set_infile,
);

sub _set_infile{
    my($self, $infile) = @_;

    $infile = File::Spec->rel2abs($infile);
    $self->{infile} = $infile;
}

=head2 outdir

Directory to write out files and logs.

=cut

has 'outdir' => (
    is => 'rw',
    isa => 'Str',
    required => 1,
    default => sub {return getcwd() },
    documentation => q{Directory to write out files.},
    trigger => \&_set_outdir,
);

sub _set_outdir{
    my($self, $outdir) = @_;

    make_path($outdir) if ! -d $outdir;
    $outdir = File::Spec->rel2abs($outdir);
    $self->{outdir} = $outdir;
}

=head2 logdir

Pattern to use to write out logs directory. Defaults to outdir/prunner_current_date_time/log1 .. log2 .. log3.

=cut

has 'logdir' => (
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    required => 1,
    default => \&set_logdir,
    documentation => q{Directory where logfiles are written. Defaults to current_working_directory/prunner_current_date_time/log1 .. log2 .. log3'},
);

=head2 procs

Total number of running children allowed at any time. Defaults to 10. The command 'wait' can be used to have a variable number of children running. It is best to wrap this script in a slurm job to not overuse resources. This isn't used within this module, but passed off to mcerunner/parallelrunner.

=cut

has 'procs' => (
    is => 'rw',
    isa => 'Int',
    default => 10,
    required => 0,
    documentation => q{Total number of running children allowed at any time. Defaults to 10. The command 'wait' can be used to have a variable number of children running. It is best to wrap this script in a slurm job to not overuse resources.}
);


has 'verbose' => (
    is => 'rw', 
    isa => enum([qw[0 1]]),
    required => 1, 
    default => 1,
    documentation => q{Level of verbosity},
);

=head1 Internal VARIABLES

You shouldn't be calling these directly.

=cut

has 'cmd' => (
    traits  => ['String', 'NoGetopt'],
    is => 'rw',
    isa => 'Str',
    lazy_build => 1,
    required => 0,
    handles => {
        add_cmd => 'append',
        match_cmd => 'match',
    }
);

has 'counter' => (
    traits  => ['Counter', 'NoGetopt'],
    is      => 'rw',
    isa     => 'Num',
    required => 1,
    default => 1,
    handles => {
        inc_counter   => 'inc',
        dec_counter   => 'dec',
        reset_counter => 'reset',
    },
);

#this needs to be called in the main app
has 'log' => (
    traits  => ['NoGetopt'],
    is => 'rw',
#    default => \&init_log,
);

has 'logfile' => (
    traits  => ['String', 'NoGetopt'],
    is => 'rw',
    default => \&set_logfile,
    handles => {
        add_logfile => 'append',
        prepend_logfile => 'prepend',
        clear_logfile => 'clear',
    }
);

has 'logname' => (
    is => 'Str',
    is => 'rw',
    default => 'prunner_logs',
);

=head1 Subroutines

=cut

sub set_logdir{
    my $self = shift;

    my $logdir;
    $logdir = $self->outdir."/".$self->logname."_".$self->set_logfile;
    $logdir =~ s/\.log$//;
    my @chars = ("A".."Z", "a".."z");
    my $string;
    $string .= $chars[rand @chars] for 1..8;
    $logdir .= $string;

    #Don't want to overwrite existing logdirs
    while(-d $logdir){
        sleep(2);
        $logdir = getcwd()."/".$self->logname."_".$self->set_logfile;
        $logdir =~ s/\.log$//;
    }
    make_path($logdir) if ! -d $logdir;
    return $logdir;
}

sub set_logfile{
    my $self = shift;

    my $dt = DateTime->now();
    $dt =~ s/[^\w]/_/g;
    return "$dt.log";
}

sub init_log{
    my $self = shift;

    Log::Log4perl->easy_init(
        {
            level    => $TRACE,
            utf8     => 1,
            mode => 'append',
            file => ">>".$self->logdir."/".$self->logfile,
            layout   => '%d: %p %m%n '
        }
    );

    my $log = get_logger();
    return $log;
}

=head2 run_commands_threads

Start the thread, run the command, and finish the thread

=cut

sub run_command_threads{
    my $self = shift;

    my $pid = $self->threads->start($self->cmd) and return;

    my $exitcode = $self->_log_commands($pid);

    $self->threads->finish($exitcode); # pass an exit code to finish

    return;
}

=head2 run_commands_mce

MCE knows which subcommand to use from Runner/MCE - object mce

=cut

sub run_command_mce{
    my $self = shift;

    my $pid = $$;
    
    #Mce doesn't take exitcode to end
    $self->_log_commands($pid);

    return;
}

=head2 _log_commands

Log the commands run them. Cat stdout/err with IO::Select so we hopefully don't break things.

This example was just about 100% from the following perlmonks discussions.

http://www.perlmonks.org/?node_id=151886

You can use the script at the top to test the runner. Just download it, make it executable, and put it in the infile as 

perl command.pl 1
perl command.pl 2
#so on and so forth

=cut

sub _log_commands {
    my($self, $pid) = @_;

    #same here
    my $dt1 = DateTime->now();

    #Create logdir

    #Create new log for each job
    $self->logfile($self->set_logfile);
    $self->prepend_logfile("CMD".$self->counter."_PID_$pid");
    my $logger = $self->init_log;

    #Start running job
    my ($infh,$outfh,$errfh);
    $errfh = gensym(); # if you uncomment this line, $errfh will
    # never be initialized for you and you
    # will get a warning in the next print
    # line.
    my $cmdpid;
    eval{
        $cmdpid = open3($infh, $outfh, $errfh, $self->cmd);
    };
    die $@ if $@;

    $logger->debug("Starting job ".$self->counter." with PID $cmdpid");
    $logger->debug("Cmd is ".$self->cmd);

# now our child is running, happily printing to 
# its stdout and stderr (our $outfh and $errfh).

    my $sel = new IO::Select; # create a select object
    $sel->add($outfh,$errfh); # and add the fhs

    while(my @ready = $sel->can_read) {
        foreach my $fh (@ready) { # loop through them
            my $line;
            # read up to 4096 bytes from this fh.
            my $len = sysread $fh, $line, 4096;
            if(not defined $len){
                # There was an error reading
                $logger->fatal("Error from child: $!");
            } elsif ($len == 0){
                # Finished reading from this FH because we read
                # 0 bytes.  Remove this handle from $sel.  
                $sel->remove($fh);
                next;
            } else { # we read data alright
                if($fh == $outfh) {
                    $logger->info($line);
                } elsif($fh == $errfh) {
                    $logger->error($line);
                } else {
                    $logger->fatal("Shouldn't be here!\n");
                }
            }
        }
    }

    waitpid($cmdpid, 1);
    my $exitcode = $?;

    $logger->debug("Finishing job ".$self->counter." with PID $cmdpid and ExitCode $exitcode");

    my $dt2 = DateTime->now();
    my $duration = $dt2 - $dt1;
    my $format = DateTime::Format::Duration->new(
        pattern => '%Y years, %m months, %e days, %H hours, %M minutes, %S seconds'
    );
    $logger->info("Total execution time ".$format->format_duration($duration));

    return $exitcode;
}


#__PACKAGE__->meta->make_immutable;
use namespace::autoclean;
1; 

=head1 AUTHOR

Jillian Rowe, C<< <jillian.e.rowe at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-runner-init at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Runner-Init>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Runner::Init


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

#End of Runner::Init
