#!/bin/bash -l
module remove tecplot*
module load tecplot/2015r2


scripts_dir=/people/song884/github/dvz_wmac/watercontent/
setup_dir=/people/song884/wmac/fy18/fine_model/model_setup/watercontent/

cd $setup_dir


# --- initial upscaling and writing of cell face coordinates 
# !!!!!!!!!!!!!!!!! modify model dimensions in ups_theta.f90
gfortran -o ups_theta.x $scripts_dir"ups_theta.f90"
# echo "grid.stompmod" >> temp
# echo "grid.gslib" >> temp
# echo "y" >> temp
# echo "filelist" >> temp
# ./ups_theta.x < temp
# rm temp


module remove python*
module load python/2.7.8
#python $scripts_dir"wmac_param_step1.py"
python $scripts_dir"wmac_param_step3.py"