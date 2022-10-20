cd $(dirname $0)/..
SDE_PATH="/root/bf-sde-9.4.0"
. $SDE_PATH/set_sde.bash
sh ./common/addport.sh

# export PYTHONPATH="$SDE_INSTALL/lib/python2.7/site-packages/tofino"
python2 ./$1/rpc_setup.py