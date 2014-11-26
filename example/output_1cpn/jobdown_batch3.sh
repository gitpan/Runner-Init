#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env 
#SBATCH --job-name=jobdown_3
#SBATCH --output=/home/guests/jir2004/perlmodule/Runner-Init/example/output_1cpn/slurm_logs_2014_11_25T12_10_56qgxugAXZ/jobdown_3.log

#SBATCH --partition=hpc


#SBATCH --nodelist=hpc015

#SBATCH --cpus-per-task=4




mcerunner.pl --procs 3 --infile /home/guests/jir2004/perlmodule/Runner-Init/example/output_1cpn/jobdown_batch3.in --outdir /home/guests/jir2004/perlmodule/Runner-Init/example/output_1cpn
