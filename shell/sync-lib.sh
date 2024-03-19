#!/usr/bin/env bash

if [ $# -lt 1 ];
then
  echo "Usage: $0 client-lib-name [generator-name]"
  exit 1
fi

client_lib_name=$1
generator_name=${2:-$client_lib_name}

if [ "$(basename $(pwd))" != "onfido-$client_lib_name" ];
then
  echo "Invalid folder name, onfido-$client_lib_name expected"
  exit 2
fi

rsync -r --exclude='/.git*' \
  --exclude-from=../onfido-openapi-spec/generators/${generator_name}/exclusions.txt \
  --delete-after ../onfido-openapi-spec/generated/artifacts/${generator_name}/ .
