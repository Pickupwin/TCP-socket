cd $(dirname $0)/..
SDE_PATH="/root/bf-sde-9.4.0"
. $SDE_PATH/set_sde.bash
$SDE_PATH/run_switchd.sh -p $1