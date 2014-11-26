#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env 
#SBATCH --job-name=jobdown_12
#SBATCH --output=/home/guests/jir2004/perlmodule/Runner-Init/example/output_1cpn/slurm_logs_2014_11_25T12_10_56qgxugAXZ/jobdown_12.log

#SBATCH --partition=hpc


#SBATCH --nodelist=hpc008

#SBATCH --cpus-per-task=4




mcerunner.pl --procs 3 --infile /home/guests/jir2004/perlmodule/Runner-Init/example/output_1cpn/jobdown_batch12.in --outdir /home/guests/jir2004/perlmodule/Runner-Init/example/output_1cpn
