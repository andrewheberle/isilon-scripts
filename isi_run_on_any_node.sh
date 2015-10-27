#!/bin/bash
# This script runs a command on only a single node
# out of all nodes in the cluster that are "OK"
# Can be used to ensure a crontab entry can be set to run
# on all nodes but only run once in the cluster

isi_status=$(isi status -q)

check_node_ok () {
        nodenum=$1
        if [ $(echo $isi_status | egrep '^  ${nodenum}\|' | grep -v OK | wc -l) -eq 0 ]; then
                echo 0
        else
                echo 1
        fi
}

# Find this nodes ID
thisnode=$(hostname | awk '{n=split ($0, a, "-"); print a[n]}')

# Find how many nodes in the cluster
nodes=$(echo $isi_status | egrep '^[ 0-9][ 0-9][ 0-9]\|' | wc -l)

# Find how many nodes in the cluster are OK
oknodes=$(echo $isi_status | egrep '^[ 0-9][ 0-9][ 0-9]\|' | grep OK | wc -l)

# Create a timestamp used as our random seed on all nodes
timestamp=$(date +%Y%m%d%H%M)
RANDOM=$timestamp

# Choose random value between 1 and $nodes
n=$((RANDOM % $nodes + 1))

# Check if we chose a node that is not OK
check=$(check_node_ok $n)
while [ $check = 1 ]; do
        if [ $n -eq $nodes ]; then
                n=1
        else
                n=$(($n + 1))
        fi
        check=$(check_node_ok $n)
done

if [ $n -eq $thisnode ]; then
        $*
fi
