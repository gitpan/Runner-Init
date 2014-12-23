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

use Moose;
extends 'Runner::MCE';

Main->new_with_options()->go;

1;
