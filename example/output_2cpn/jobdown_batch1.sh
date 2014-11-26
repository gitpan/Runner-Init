#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env 
#SBATCH --job-name=jobdown_1
#SBATCH --output=/home/guests/jir2004/perlmodule/Runner-Init/example/output_2cpn/slurm_logs_2014_11_25T12_11_49YYFuLIEN/jobdown_1.log

#SBATCH --partition=hpc


#SBATCH --nodelist=hpc007

#SBATCH --cpus-per-task=4




mcerunner.pl --procs 3 --infile /home/guests/jir2004/perlmodule/Runner-Init/example/output_2cpn/jobdown_batch1.in --outdir /home/guests/jir2004/perlmodule/Runner-Init/example/output_2cpn
