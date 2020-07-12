#!/bin/bash

set -x
set -e

# Requires AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY and PASSPHRASE environment variables

usage()
{
    echo "usage: [-s src_dir] [-d dest_bucket_path] [-f full_if_older_than] [-r remove_if_older_than]] | [-h]]"
}

### MAIN

ARCHIVE_DIR=/tmp/archive
src_dir=
dest_bucket_path=
full_if_older_than='14D'
remove_if_older_than='1M'
includes=()
excludes=()

while [ "$1" != "" ]; do
    case $1 in
        -s | --src_dir )               shift
                                       src_dir=$1
                                       ;;
        -d | --dest_bucket_path )      shift
                                       dest_bucket_path=$1
                                       ;;
        -f | --full_if_older_than )    shift
                                       full_if_older_than=$1
                                       ;;
        -r | --remove_if_older_than )  shift
                                       remove_if_older_than=$1
                                       ;;
        -n | --include )               shift
		                       includes+=( $1 )
                                       ;;
        -x | --exclude )               shift
		                       excludes+=( $1 )
                                       ;;
        -h | --help )                  usage
                                       exit
                                       ;;
        * )                            usage
                                       exit 1
    esac
    shift
done

if [ "$src_dir" = "" ]; then
    usage
    exit 1
fi

if [ "$dest_bucket_path" = "" ]; then
    usage
    exit 1
fi

if [ "$full_if_older_than" = "" ]; then
    usage
    exit 1
fi

if [ "$remove_if_older_than" = "" ]; then
    usage
    exit 1
fi

# load gpg secret key
gpg --batch --import /tmp/key.pem
KEY_SIG=`gpg --list-keys | grep -A1 SC | tail -1 | awk '{print $1;}'`

# trust the loaded key
echo "$KEY_SIG:6:" | gpg --import-ownertrust

# make the archive cache directory
archive_bucket_path=$dest_bucket_path"/archive"
mkdir -p $ARCHIVE_DIR

# download the archive cache if it exists remotely
if aws s3 ls $archive_bucket_path
then
    duplicity restore "boto3+s3://$archive_bucket_path" $ARCHIVE_DIR
fi

# generate include options
include_opts=""
for include in ${includes[@]}; do
    include_opts+="--include $include "
done

# generate exclude options
#exclude_opts=""
#for exclude in ${excludes[@]}; do
#    exlcude_opts+="--exclude $exclude "
#done

# backup the request src dir
duplicity incr --progress --archive-dir $ARCHIVE_DIR --encrypt-key $KEY_SIG --allow-source-mismatch --full-if-older-than $full_if_older_than $include_opts --exclude '**' $src_dir "boto3+s3://$dest_bucket_path"
# and prune the backups
duplicity remove-older-than $remove_if_older_than --force --archive-dir $ARCHIVE_DIR "boto3+s3://$dest_bucket_path"

# backup the archive cache
duplicity incr --progress --encrypt-key $KEY_SIG --allow-source-mismatch --full-if-older-than $full_if_older_than $ARCHIVE_DIR "boto3+s3://$archive_bucket_path"
# and prune this backups
duplicity remove-older-than $remove_if_older_than --force "boto3+s3://$archive_bucket_path"
