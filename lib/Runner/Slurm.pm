package Runner::Slurm;

use File::Path qw(make_path remove_tree);
use File::Temp qw/ tempfile tempdir /;
use IO::File;
use IO::Select;
use Cwd;
use IPC::Open3;
use Symbol;
use Template;
use Log::Log4perl qw(:easy);
use DateTime;
use Data::Dumper;
#use IPC::Cmd qw/can_run/;

use Moose;
with 'MooseX::SimpleConfig';
extends 'Runner::Init';

=head1 NAME

Runner::Slurm - The great new Runner::Slurm!

=head1 VERSION

Version 0.01

=cut

our $VERSION = '1.2';


=head1 SYNOPSIS

Runner::Slurm->new_with_options(infile => '/path/to/commands');

This module is a wrapper around submitting arbirtary bash commands to slurm. 

It has two levels of management. The first is the main, and the second is controlled by Runner::Threads or Runner::MCE for the jobs.

It supports job dependencies. Put in the command 'wait' to tell slurm that some job or jobs depend on some other jobs completion. Put in the command 'newnode' to tell Runner::Slurm to submit the job to a new node.

The only necessary option is the --infile.

=head2 Submit Script

    cmd1
    cmd2 && cmd3
    cmd4 \
    --option cmd4 \
    #Tell Runner::Slurm to put in some job dependencies.
    wait
    cmd5
    #Tell Runner::Slurm to pass things off to a new node, but this job doesn't depend on the previous
    newnode
    cmd6

=head1 User Options

User options can be passed to the script with script --opt1 or in a configfile. It uses MooseX::SimpleConfig for the commands

=head2 configfile

Config file to pass to command line as --configfile /path/to/file. It should be a yaml or xml (untested)
This is optional. Paramaters can be passed straight to the command line

=head3 example.yml

    ---
    infile: "/path/to/commands/testcommand.in"
    outdir: "path/to/testdir"
    module:
        - "R2"
        - "shared"

=cut

has '+configfile' => (
    required => 0,
);

=head2 infile

infile of commands separated by newline

=head3 example.in

    cmd1
    cmd2 --input --input \
    --someotherinput
    wait
    #Wait tells slurm to make sure previous commands have exited with exit status 0.
    cmd3  ##very heavy job
    newnode
    #cmd3 is a very heavy job so lets start the next job on a new node

=cut

#We already have infile in Runner::Init, just wanted to include slurm specific documentation here

=head2 module

modules to load with slurm
Should use the same names used in 'module load'

Example. R2 becomes 'module load R2'

=cut

has 'module' => (
    is => 'rw',
    isa => 'ArrayRef',
    required => 0,
    documentation => q{List of modules to load ex. R2, samtools, etc},
); 

=head2 jobname

Specify a job name, and jobs will be jobname_1, jobname_2, jobname_x

=cut

has 'jobname' => (
    is => 'rw',
    isa => 'Str',
    required => 0,
    traits  => ['String'],
    default => q{job},
    handles => {
        add_jobname => 'append',
        clear_jobname => 'clear',
        replace_jobname => 'replace',
    },
    documentation => q{Specify a job name, each job will be appended with its batch order},
);

=head2 cpus_per_task

slurm item --cpus_per_task defaults to 8, which is probably fine

=cut

has 'cpus_per_task' => (
    is => 'rw',
    isa => 'Str',
    required => 0,
    default => 4,
);

=head2 commands_per_node

--commands_per_node defaults to 8, which is probably fine

=cut

has 'commands_per_node' => (
    is => 'rw',
    isa => 'Str',
    required => 0,
    default => 8,
);

=head2 partition

#Should probably have something at some point that you can specify multiple partitions....

Specify the partition. Defaults to the partition that has the most nodes.

=cut

has 'partition' => (
    is => 'rw',
    isa => 'Str',
    required => 0,
    default => '',
);

=head2 nodelist

Defaults to the nodes on the defq queue

=cut
 
has 'nodelist' => (
    is => 'rw',
    isa => 'ArrayRef',
    required => 0,
    documentation => q{List of nodes to submit jobs to. Defaults to the partition with the most nodes.},
);

=head2 submit_slurm 

Bool value whether or not to submit to slurm. If you are looking to debug your files, or this script you will want to set this to zero.

=cut

has 'submit_to_slurm' => (
    is => 'rw',
    isa => 'Bool',
    default => 1, 
    required => 0,
    documentation => q{Bool value whether or not to submit to slurm. If you are looking to debug your files, or this script you will want to set this to zero.},
);

=head2 template_file

actual template file

One is generated here for you, but you can always supply your own with --template_file /path/to/template

=cut

has 'template_file' => (
    is => 'rw',
    isa => 'Str',
    default => sub {
        my $self = shift;

        my($fh, $filename) = tempfile();

        my $tt =<<EOF;
#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env 
#SBATCH --job-name=[% JOBNAME %]
#SBATCH --output=[% OUT %]
[% IF PARTITION %]
#SBATCH --partition=[% PARTITION %]
[% END %]
[% IF NODE %]
#SBATCH --nodelist=[% NODE %]
[% END %]
#SBATCH --cpus-per-task=[% CPU %]
[% IF AFTEROK %]
#SBATCH --dependency=afterok:[% AFTEROK %] 
[% END %]

[% IF MODULE %]
    [% FOR d = MODULE %]
module load [% d %]
    [% END %]
[% END %]

[% COMMAND %]
EOF

        print $fh $tt;
        return $filename;
    },
);

=head2 procs_per_sbatch

Number of processes to use per sbatch. By default this is a conservative number as there is no checking mechanism to see how 'heavy' a job is.

=cut

has procs_per_sbatch => (
    is => 'rw',
    isa => 'Int',
    default => 3,
    required => 0,
);

=head2 user

user running the script. Passed to slurm for mail information

=cut

has 'user' => (
    is => 'rw',
    isa => 'Str',
    default => sub { return $ENV{LOGNAME} || $ENV{USER} || getpwuid($<); },
    required => 1,
);

=head2 use_threads 

Bool value to indicate whether or not to use threads. Default is uses processes

If using threads your perl must be compiled to use threads!

=cut

has 'use_threads' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
    required => 0,
);

=head2 use_processes 

Bool value to indicate whether or not to use processes. Default is uses processes

=cut

has 'use_processes' => (
    is => 'rw',
    isa => 'Bool',
    default => 1,
    required => 0,
);

=head1 Internal Variables

You should not need to mess with any of these.

=head2 template

template object for writing slurm batch submission script

=cut

has 'template' => (
    traits => ['NoGetopt'],
    is => 'rw',
    required => 0,
    default => sub {return Template->new(ABSOLUTE     => 1) },
);


=head2 cmd_counter

keep track of the number of commands - when we get to more than commands_per_node restart so we get submit to a new node.

=cut

has 'cmd_counter' => (
    traits  => ['Counter', 'NoGetopt'],
    is      => 'ro',
    isa     => 'Num',
    required => 1,
    default => 1,
    handles => {
        inc_cmd_counter   => 'inc',
        dec_cmd_counter   => 'dec',
        reset_cmd_counter => 'reset',
    },
);

=head2 node_counter

Keep track of which node we are on

=cut

has 'node_counter' => (
    traits  => ['Counter', 'NoGetopt'],
    is      => 'ro',
    isa     => 'Num',
    required => 1,
    default => 0,
    handles => {
        inc_node_counter   => 'inc',
        dec_node_counter   => 'dec',
        reset_node_counter => 'reset',
    },
);

=head2 batch_counter

Keep track of how many batches we have submited to slurm

=cut

has 'batch_counter' => (
    traits  => ['Counter', 'NoGetopt'],
    is      => 'ro',
    isa     => 'Num',
    required => 1,
    default => 1,
    handles => {
        inc_batch_counter   => 'inc',
        dec_batch_counter   => 'dec',
        reset_batch_counter => 'reset',
    },
);

=head2 node

Node we are running on

=cut

has 'node' => (
    traits => ['NoGetopt'],
    is => 'rw',
    isa => 'Str|Undef',
    lazy => 1,
    default => sub {
        my $self = shift;
        return $self->nodelist()->[0] if $self->nodelist;
        return "";
    }
);

=head2 cmd

Current command specified by infile

=cut

has 'cmd' => (
    traits  => ['String', 'NoGetopt'],
    is => 'rw',
    isa => 'Str',
    required => 0,
    default => q{},
    handles => {
        add_cmd => 'append',
        match_cmd => 'match',
    },
    clearer => 'clear_cmd',
    predicate => 'has_cmd',
);

=head2 batch

List of commands to submit to slurm

=cut

has 'batch' => (
    traits  => ['String', 'NoGetopt',],
    is => 'rw',
    isa => 'Str',
    default => q{},
    required => 0,
    handles => {
        add_batch     => 'append',
    },
    clearer => 'clear_batch',
    predicate => 'has_batch',
);

=head2 cmdfile

File of commands for mcerunner/parallelrunner
Is cleared at the end of each slurm submission

=cut

has 'cmdfile' => (
    traits  => ['String', 'NoGetopt'],
    default => q{},
    is => 'rw',
    isa => 'Str',
    required => 0,
    handles => {
        clear_cmdfile     => 'clear',
    },
);

=head2 slurmfile

File generated from slurm template

=cut

has 'slurmfile' => (
    traits  => ['String', 'NoGetopt'],
    default => q{},
    is => 'rw',
    isa => 'Str',
    required => 0,
    handles => {
        clear_slurmfile     => 'clear',
    },
);

=head2 jobref

Array of arrays details slurmjob id. Index -1 is the most recent job submissisions, and there will be an index -2 if there are any job dependencies

=cut

has 'jobref' => (
    traits  => ['NoGetopt'],
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [ [] ]  },
);

=head2 wait

Boolean value indicates any job dependencies

=cut

has 'wait' => (
    traits  => ['NoGetopt'],
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

=head1 SUBROUTINES/METHODS

=cut

=head2 run()

First sub called
Calling system module load * does not work within a screen session!

=cut

sub run {
    my $self = shift;

    #This fails in a screen session!
#    system("module load slurm");
#    system("module load shared");
    
    print "In run\n";
    $self->logname('slurm_logs');
    $self->log($self->init_log);
    $self->log->info("hello world");

    $self->check_files;
    $self->parse_file_slurm;
}

=head2 check_files()

Check to make sure the outdir exists. 
If it doesn't exist the entire path will be created

=cut

sub check_files{
    my($self) = @_;
    my($t);

    $t = $self->outdir;
    $t =~ s/\/$//g;
    $self->outdir($t);

    #make the outdir
    make_path($self->outdir) if ! -d $self->outdir;

    $self->get_nodes;
}

=head2 get_nodes

Get the nodes from sinfo if not supplied

If the nodelist is supplied partition must be supplied

=cut

sub get_nodes{
    my($self) = @_;

    if(!$self->nodelist && $self->partition){
        print "If you define a partition you must define a nodelist!\n";
        die;
    }
    
    my @s = `sinfo -r`;
    my $href;

    foreach my $s (@s) {
        my @nodes = ();
        my $noderef = [];
        next if $s =~ m/^PARTITION/i;
        my @t = ($s =~ /(\S+)/g);
        $t[0] =~ s/\*//g;
        next unless $t[1] =~ m/up/; 

        my $nodes = $t[5];

        #list of nodes
        if($nodes =~ m/\[/){
            my($n) = ($nodes =~ m/\[(\S+)\]/g);
            my @n = split(",", $n);

            foreach my $nt (@n) {
                if($nt =~ m/-/){
                    my(@m) = ($nt =~ m/(\d+)-(\d+)/g);
                    push(@$noderef, ($m[0]..$m[1]));
                }
                else{
                    my($m) = ($nt =~ m/(\d+)/g);
                    push(@$noderef, $m);
                }
            }
        }
        else{ #only one node
            my($m) = ($nodes =~ m/(\d+)/g);
            push(@$noderef, $m);
        }

        if(exists $href->{$t[0]}){
            my $aref = $href->{$t[0]};
            push(@$aref, @$noderef) if $noderef;
            $href->{$t[0]} = $aref;
        }
        else{
#        $href->{$t[0]} = \@nodes;
            $href->{$t[0]} = $noderef;
        }
    }

#Got the nodes lets find out which partition has the most nodes
#Unless we already have a defined partition, then we don't care


    my $holder = 0;
    my $bpart;

    while(my($part, $nodes) = each %{$href}){
        next unless $nodes;
        next unless ref($nodes) eq "ARRAY";

        @$nodes = map { $part.$_ } @$nodes;

        if(scalar @$nodes > $holder){
            $holder = scalar @$nodes;
            $bpart = $part;
        }
    }

    if($self->partition){
        $self->nodelist($href->{$self->partition});
        return;
    }

    $self->partition($bpart);
    $self->nodelist($href->{$bpart});
}

=head2 parse_file_slurm

Parse the file looking for the following conditions

lines ending in `\`
wait
nextnode

Batch commands in groups of $self->cpus_per_task, or smaller as wait and nextnode indicate

=cut

sub parse_file_slurm{
    my $self = shift;
    my $fh = IO::File->new( $self->infile, q{<} ) or print "Error opening file  ".$self->infile."  ".$!; # even better!
    while(<$fh>){
        my $line = $_;
        next unless $line;
        next unless $line =~ m/\S/;
        next if $line =~ m/^#/;

        if( 0 == $self->cmd_counter % $self->commands_per_node && $self->batch ){
            #Run this batch and start the next
            $self->work;
        }

        if($self->has_cmd){
            $self->add_cmd($line);
            $self->add_batch($line);
            if($line =~ m/\\$/){
                next;
            }
            else{
                $self->add_cmd("\n");
                $self->add_batch("\n");
                $self->clear_cmd;
                $self->inc_cmd_counter; 
            }
        }
        else{
            $self->add_cmd($line);
            
            if($line =~ m/\\$/){
                $self->add_batch($line);
                next;
            }
            elsif( $self->match_cmd("wait") ){
                #submit this batch and get the job id so the next can depend upon it
                $self->clear_cmd;
                $self->wait(1);
                #Keep this for debug info for now
#                shift @{$self->jobref} if scalar @{$self->jobref} > 2;
                $self->work;
                push(@{$self->jobref}, []);
            }
            elsif( $self->match_cmd("newnode") ){
                $self->clear_cmd;
                $self->work;
            }
            else{
                #Don't want to increase command count for wait and newnode
                $self->inc_cmd_counter; 
            }
            $self->add_batch($line."\n") if $self->has_cmd;
            $self->clear_cmd;
        }
    }
#    print "Working!\n".Dumper($self->batch);
    $self->work if $self->has_batch;

    $self->log->debug("All the jobs ".Dumper($self->jobref));
}

=head2 work

Get the node #may be removed but we'll try it out
Process the batch
Submit to slurm
Take care of the counters

=cut

sub work{
    my $self = shift;


    if($self->node_counter > (scalar @{ $self->nodelist }) ){
        $self->reset_node_counter;
    }
    $self->node($self->nodelist()->[$self->node_counter]) if $self->nodelist;
    $self->process_batch;

    $self->inc_batch_counter;
    $self->clear_batch;
    $self->inc_node_counter;

    $self->reset_cmd_counter;
}

=head2 process_batch()

Create the slurm submission script from the slurm template
Write out template, submission job, and infile for parallel runner

=cut

sub process_batch{
    my $self = shift;
    my($cmdfile, $slurmfile, $slurmsubmit, $fh, $command);
    
    $self->cmdfile($self->outdir."/".$self->jobname."_batch".$self->batch_counter.".in");
    $self->slurmfile($self->outdir."/".$self->jobname."_batch".$self->batch_counter.".sh"); 

    $fh = IO::File->new( $self->cmdfile, q{>} ) or print "Error opening file  ".$self->cmdfile."  ".$!; 

    print $fh $self->batch if defined $fh && defined $self->batch;
    $fh->close;

    my $ok;
    if($self->wait){
        $ok = join(":", @{$self->jobref->[-2]}) if $self->jobref->[-2];
    }

    #Giving outdir/jobname doesn't work unless a full file path is supplied
    #Need to get absolute path going on...
    $self->cmdfile($self->jobname."_batch".$self->batch_counter.".in");

    if($self->use_threads){
        $command = "paralellrunner.pl --procs ".$self->procs_per_sbatch." --infile ".$self->cmdfile." --outdir ".$self->outdir;
    }
    elsif($self->use_processes){
        $command = "mcerunner.pl --procs ".$self->procs_per_sbatch." --infile ".$self->cmdfile." --outdir ".$self->outdir;
    }

    $self->template->process($self->template_file, 
        { JOBNAME => $self->jobname."_".$self->batch_counter, 
            USER => $self->user, 
            NODE => $self->node, 
            CPU => $self->cpus_per_task, 
            PARTITION => $self->partition,
            AFTEROK => $ok, 
            OUT => $self->logdir."/".$self->jobname."_".$self->batch_counter.".log",
            MODULE => $self->module,
#            COMMAND => "perl /data/apps/software/slurm_scripts/paralellnoderunner.pl --procs 3 --infile ".$self->cmdfile." --outdir ".$self->outdir },
            COMMAND => $command },
        $self->slurmfile
    ) || die $self->template->error;

    chmod 0777, $self->slurmfile;

    $self->submit_slurm if $self->submit_to_slurm;
}

=head2 submit_slurm()

Submit jobs to slurm queue using sbatch. 

This subroutine was just about 100% from the following perlmonks discussions. All that I did was add in some logging.

http://www.perlmonks.org/?node_id=151886
You can use the script at the top to test the runner. Just download it, make it executable, and put it in the infile as 

perl command.pl 1
perl command.pl 2
#so on and so forth

=cut

sub submit_slurm{
    my $self = shift;

    my ($infh,$outfh,$errfh);
    $errfh = gensym(); # if you uncomment this line, $errfh will
    # never be initialized for you and you
    # will get a warning in the next print
    # line.
    my $cmdpid;
    eval{
        $cmdpid = open3($infh, $outfh, $errfh, "sbatch ".$self->slurmfile);
        print "Submitting job ".$self->slurmfile."\n";
    };
    die $@ if $@;

    my $sel = new IO::Select; # create a select object
    $sel->add($outfh,$errfh); # and add the fhs
    
    my($stdout, $stderr, $jobid);

    while(my @ready = $sel->can_read) {
        foreach my $fh (@ready) { # loop through them
            my $line;
            # read up to 4096 bytes from this fh.
            my $len = sysread $fh, $line, 4096;
            if(not defined $len){
                # There was an error reading
                $self->log->fatal("Error from child: $!");
            } elsif ($len == 0){
                # Finished reading from this FH because we read
                # 0 bytes.  Remove this handle from $sel.  
                $sel->remove($fh);
                next;
            } else { # we read data alright
                if($fh == $outfh) {
                    $stdout .= $line;
                    $self->log->info($line);
                } elsif($fh == $errfh) {
                    $stderr .= $line;
                    $self->log->error($line);
                } else {
                    $self->log->fatal("Shouldn't be here!\n");
                }
            }
        }
    }

    waitpid($cmdpid, 1);
    my $exitcode = $?;
    
    ($jobid) = $stdout =~ m/Submitted batch job (\d.*)$/ if $stdout;
    if(!$jobid){
        print "No job was submitted! Please check to make sure you have loaded modules shared and slurm!\nFull error is:\t$stderr\n$stdout\nEnd Job error";
        print "Submit scripts will be written, but will not be submitted to the queue. Please look at your files in ".$self->outdir." for more information\n";
        $self->submit_to_slurm(0);
    }
    else{
        push(@{$self->jobref->[-1]}, $jobid);
    }
}

=head1 AUTHOR

Jillian Rowe, C<< <jillian.e.rowe at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-runner-init at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Runner-Init>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Runner::Slurm


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

1; # End of Runner::Slurm
