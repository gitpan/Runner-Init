#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  slurmrunner.pl
#
#        USAGE:  ./slurmrunner.pl  
#
#  DESCRIPTION: Run jobs using slurm job queing system 
#
#===============================================================================

package Main;

use File::FindLib 'lib';

use Moose;
#use Carp::Always;
use Data::Dumper;

extends 'Runner::Slurm';

Runner::Slurm->new_with_options()->run;

1;
