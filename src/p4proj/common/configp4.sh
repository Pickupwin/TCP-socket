cd $(dirname $0)/..
SDE_PATH="/root/bf-sde-9.4.0"
. $SDE_PATH/set_sde.bash
sh ./common/addport.sh
$SDE_PATH/run_bfshell.sh -b ./$1/setup.py