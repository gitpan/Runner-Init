#!/usr/bin/env perl 
#===============================================================================
#
#         FILE:  mcerunner.pl
#
#        USAGE:  ./mcerunner.pl  
#
#  DESCRIPTION: Run jobs use MCE 
#===============================================================================

package Main;

use strict;
use warnings;

use File::FindLib 'lib';

use Moose;
#use Carp::Always;
use Data::Dumper;

#use Runner::MCE;
extends 'Runner::MCE';

Runner::MCE->new_with_options()->go;

1;
