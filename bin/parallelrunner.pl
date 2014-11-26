#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  parallelrunner.pl
#
#        USAGE:  ./parallelrunner.pl  
#
#  DESCRIPTION: Run jobs using threads 
#===============================================================================

package Main;

use File::FindLib 'lib';

use Moose;
#use Carp::Always;
use Data::Dumper;

extends 'Runner::Threads';

Runner::Threads->new_with_options()->go;

1;
