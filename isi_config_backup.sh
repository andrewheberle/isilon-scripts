#!/bin/sh
#
# Executes isi_ps script to backup cluster config
#
pwdfile=/ifs/admin/isi_ps/.config_backup
confoutput=/ifs/data/perth/cluster-config.json
python /ifs/admin/isi_ps/isi_ps.pyc --module=config --mode=backup --all --hidden --password_file=$pwdfile --file=$confoutput --quiet > /dev/null 2>&1