#!/bin/bash
#
# Shut down Isilon cluster via script
#
# Could be combined with UPS monitoring that can execute script to run this
# via SSH (eg plink.exe on Windows) on Isilon
#
# Will shut down all nodes
#
# Syntax: isi_cluster_shutdown.sh [--really-shutdown]
#
if [ "$1" = "--really-shutdown" ]; then
        echo Shutting down cluster
        cat << EOF | /usr/bin/isi_config
        shutdown all
        yes
        EOF
else
        echo Not shutting down.
fi
