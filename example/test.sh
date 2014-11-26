#!/bin/bash - 
#===============================================================================
#
#          FILE: test.sh
# 
#         USAGE: ./test.sh 
# 
#   DESCRIPTION: 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: YOUR NAME (), 
#  ORGANIZATION: 
#       CREATED: 11/25/2014 15:09
#      REVISION:  ---
#===============================================================================

#set -o nounset                              # Treat unset variables as an error

# /home/guests/jir2004/perlmodule/Runner-Init/bin/slurmrunner.pl --infile testcommand.in --outdir `pwd`/output_1cpn --jobname jobdown --commands_per_node 1 
# /home/guests/jir2004/perlmodule/Runner-Init/bin/slurmrunner.pl --infile testcommand.in --outdir `pwd`/output_2cpn --jobname jobdown --commands_per_node 2 

/home/guests/jir2004/perlmodule/Runner-Init/bin/slurmrunner.pl --infile testcommand.in --outdir `pwd`/output_3cpn --jobname jobdown --commands_per_node 3 

