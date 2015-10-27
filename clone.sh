#!/bin/bash
# 
# Script clones files from Isilon snapshots back to original (live) location
#
# Syntax (as root):
#
# /bin/zsh /ifs/admin/clone.sh "/ifs/live/directory" "Snapshot_Name" [FileList.txt]
# 
# Only works with four nodes currently
#

# Temporary location for file and directory lists
tempdir=/ifs/temp

old_IFS=$IFS

function cleanup {
        # Cleanup function run on EXIT of script
        echo "$(date +%Y-%m-%dT%H:%M:%S) : Cleaning up."
        IFS=$old_IFS
        [ -f ${dlist} ] && rm -f ${dlist}
        [ -f ${flist} ] && rm -f ${flist}
}

# Run cleanup on EXIT
trap cleanup EXIT

# snap name and livedir as arguments
snap=$2
livedir=$1

# Check for more than two commandline argumets
# optional third argument is list of files to clone (used as part of parallel processing)
if [ $# -gt 2 ]; then
        # Find node number this script is running on
        thisnode=$(hostname | awk '{n=split ($0, a, "-"); print a[n]}')
        case ${thisnode} in
                1) suffix=a
                ;;
                2) suffix=b
                ;;
                3) suffix=c
                ;;
                4) suffix=d
                ;;
                *) suffix=bad
                ;;
        esac
        # Look for supplied file list with .x as a suffix
        flist=$3.${suffix}
        if [ ! -f ${flist} ]; then
                echo "$(date +%Y-%m-%dT%H:%M:%S) : Supplied file list not found (${flist})."
                exit 1
        fi
else
        # No third argument so we are running on the "master" note (ie node where script was intially executed)
        thisnode="m"

fi

# Check for livedir
[ ! -d "${livedir}" ] && exit 1
echo "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : Source directory \"${livedir}\" exists..."

# Check snapshot exists
[ ! -d "${livedir}/.snapshot/${snap}" ] && exit 1
echo "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : Snapshot \"${snap}\" exists..."

# Check if filelist was supplied
if [ $# -eq 2 ]; then
        # No filelist suppplied
        # Generate list of directories from snapshot
        echo "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : Checking for missing directories..."
        dlist=$(mktemp ${tempdir}/clone-dirs.XXXXXX)
        find "${livedir}/.snapshot/${snap}" -type d > ${dlist}
        missingdirs=0

        # Loop through list of dirs to see if they exist in the live dir
        while read line; do
                src=${line}
                tgt=$(echo ${line} | awk -F "/.snapshot/${snap}/" '{print $2}')
                if [ ! -d "${livedir}/${tgt}" ]; then
                        [ ${missingdirs} -eq 0 ] && echo "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : Missing directories found."
                        echo "${tgt}"
                        missingdirs=1
                fi
        done < ${dlist}

        # Bail out if missing directories found
        [ ${missingdirs} -eq 1 ] && exit 1
        echo "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : No missing directories found."
else
        # Do not generate dirlist if filelist was supplied (assumed already done)
        echo "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : Check for missing directories skipped."
        dlist=${tempdir}/invalid-file
fi

if [ $# -eq 2 ]; then
        # If no filelist was supplied, generate list
        echo -n "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : Building file list..."
        flist=$(mktemp ${tempdir}/clone-files.XXXXXX)
        find "${livedir}/.snapshot/${snap}" -type f > ${flist}
        echo "done."
        # Split file list into equal parts (based on number of nodes)
        echo -n "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : Splitting file list..."
        # Count lines output from isi_nodes to determine number of nodes
        isi_num_nodes=$(isi_nodes %{id} %{name} | wc -l)
        # Count lines in file list
        totalfiles=$(wc -l < ${flist})
        # Divide evenly
        ((lines_per_flist = (totalfiles + isi_num_nodes - 1) / isi_num_nodes))
        # Split file
        split -a 1 -l ${lines_per_flist} ${flist} ${flist}.
        echo "done."
        # Execute script on each node - providing file list
        isi_for_array --quiet /bin/zsh /ifs/admin/clone.sh \"${livedir}\" \"${snap}\" ${flist}
else
        # File list is specified so run clone process
        echo "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : File list build skipped."
        # Count files for basic progress output
        totalfiles=$(wc -l < ${flist})
        echo "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : Starting file copy (${flist})..."
        filecount=1
        # Iterate through file list
        while read line; do
                # Source is from snap
                src=${line}
                # Strip everything before snapshot directory component to get relative target filename
                tgt=$(echo ${line} | awk -F "/.snapshot/${snap}/" '{print $2}')
                echo -n "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : (${filecount}/${totalfiles}) Cloning to ${livedir}/${tgt}..."
                # Copy (using clone directive), preserving all attributes (ACLs etc) and not overwriting files already that exist
                # Target is live filesystem dir (livedir)/(relative filename from snap)
                cp -cpn "${src}" "${livedir}/${tgt}"
                ret=$?
                # Print return code (not interpreted...just printed)
                if [ $ret -eq 0 ]; then
                        echo "OK."
                else
                        echo "Return Code (${ret})."
                fi
                ((filecount = (filecount + 1)))
        done < ${flist}
        echo "$(date +%Y-%m-%dT%H:%M:%S) : ${thisnode} : File copy done (${flist})."
fi
