#!/bin/bash

# Very simple usage instructions.

echo "$@" | grep -e '--help' --quiet && \
echo "./as-host-user.sh --image [image] --command [docker run ...]" && exit

# Verify that we are on a Linux machine.
# This wrapper is not necessary on MacOS systems, as Docker volumes are mounted via NFS.
# Not sure about Windows, but execution is prevented as well.

echo $(uname -s) | grep -e "Linux" --quiet || { echo Not a Linux host machine... exiting.; exit; }

# Check if Docker is available.

docker --version || { echo Docker not found... exiting.; exit; }

# Check if Docker image and Docker command are specified.

echo "$@" | grep -e '--image' --quiet || { echo --image not specified... exiting.; exit; }
echo "$@" | grep -e '--command' --quiet || { echo --command not specified... exiting.; exit; }

# Check if a `docker run` command is specified.

echo "$@" | grep -e 'docker run' --quiet || { echo No docker run command found... exiting.; exit; }

# Parse the inputs.

for ARG in "$@"; do
 case $ARG in
   --image) shift; DOCKER_IMAGE=$1; shift ;;
   --command) shift; ORIGINAL_DOCKER_COMMAND="$@" ;;
 esac
done

ORIGINAL_DOCKER_COMMAND="$@"
echo Original command: ${ORIGINAL_DOCKER_COMMAND}
echo Enable host user for: ${DOCKER_IMAGE}

# Prepare temporary directory for merging the Linux system account information.

TEMPDIR=$(mktemp -d $(pwd)/tmp.XXXXXXXX)
echo Temporary directory: ${TEMPDIR}
trap "echo Deleting: ${TEMPDIR}; rm -rf ${TEMPDIR}" 0

# Extract existing Docker image account information and append (replace with) the user account information of the host system.

id=$(docker create jupyter)
# https://stackoverflow.com/questions/25292198/docker-how-can-i-copy-a-file-from-an-image-to-a-host
docker cp $id:/etc/passwd ${TEMPDIR}/etc_passwd
docker cp $id:/etc/group ${TEMPDIR}/etc_group
docker rm $id

# If UID is already existing, remove the container's user...
sed "/$(id -u ${USER})/d" $TEMPDIR/etc_passwd > $TEMPDIR/etc_passwd
sed "/$(id -g ${USER})/d" $TEMPDIR/etc_group > $TEMPDIR/etc_group

# Append host system user information.
grep $(id -u ${USER}) /etc/passwd >> ${TEMPDIR}/etc_passwd
grep $(id -g ${USER}) /etc/group >> ${TEMPDIR}/etc_group

# Setup necessary Docker options.

USER_FLAGS="-u $(id -u ${USER}):$(id -g ${USER})"
MOUNT_FLAGS="-v ${TEMPDIR}/etc_passwd:/etc/passwd -v ${TEMPDIR}/etc_group:/etc/group"

FINAL_DOCKER_COMMAND=${ORIGINAL_DOCKER_COMMAND//docker run/docker run ${USER_FLAGS} ${MOUNT_FLAGS}}
echo Will execute: ${FINAL_DOCKER_COMMAND}

# Execute final Docker command.

${FINAL_DOCKER_COMMAND}
