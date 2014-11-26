#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env 
#SBATCH --job-name=jobdown_11
#SBATCH --output=/home/guests/jir2004/perlmodule/Runner-Init/example/output_1cpn/slurm_logs_2014_11_25T12_10_56qgxugAXZ/jobdown_11.log

#SBATCH --partition=hpc


#SBATCH --nodelist=hpc007

#SBATCH --cpus-per-task=4




mcerunner.pl --procs 3 --infile /home/guests/jir2004/perlmodule/Runner-Init/example/output_1cpn/jobdown_batch11.in --outdir /home/guests/jir2004/perlmodule/Runner-Init/example/output_1cpn
