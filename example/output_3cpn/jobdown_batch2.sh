#!/bin/bash
#
#SBATCH --share
#SBATCH --get-user-env 
#SBATCH --job-name=jobdown_2
#SBATCH --output=/home/guests/jir2004/perlmodule/Runner-Init/example/output_3cpn/slurm_logs_2014_11_25T12_12_30kBQUCcit/jobdown_2.log

#SBATCH --partition=hpc


#SBATCH --nodelist=hpc008

#SBATCH --cpus-per-task=4




mcerunner.pl --procs 3 --infile /home/guests/jir2004/perlmodule/Runner-Init/example/output_3cpn/jobdown_batch2.in --outdir /home/guests/jir2004/perlmodule/Runner-Init/example/output_3cpn
