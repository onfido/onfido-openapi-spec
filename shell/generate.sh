#!/usr/bin/env bash

# Don't carry on when any command fails
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASEDIR=${SCRIPT_DIR}/..

COMMON_CONFIG_FILE="generators/common/config.yaml"
GENERATORS=${*:-`ls generators`}
GENERATED_CONFIG_FILES=""

OPENAPI_GENERATOR_VERSION=${OPENAPI_GENERATOR_VERSION:-v7.3.0}
OPENAPI_GENERATOR_COMMAND=${OPENAPI_GENERATOR_COMMAND:-\
  docker run --rm -v "$(pwd):/local" -w /local \
  openapitools/openapi-generator-cli:${OPENAPI_GENERATOR_VERSION}}

BUMP_CLIENT_LIBRARY_VERSION=${BUMP_CLIENT_LIBRARY_VERSION:-""}

# $1: version, $2: bump type (Major, Minor, Patch)
function semver_bump() {
  INPUT_VERSION=$1
  BUMP_TYPE=$2
  POS=0
  RESET=
  OUTPUT_VERSION=
  OUTPUT_SEPARATOR="."

  IFS='.' read -ra NUMBERS <<< "$INPUT_VERSION"
  for NUMBER in "${NUMBERS[@]}"; do
    if [ -z "${RESET}" ];
    then
      if ([ $POS -eq 0 ] && [ "$BUMP_TYPE" == "Major" ]) || \
         ([ $POS -eq 1 ] && [ "$BUMP_TYPE" == "Minor" ])   || \
         ([ $POS -eq 2 ] && [ "$BUMP_TYPE" == "Patch" ]) ;
      then
        NUMBER=$((NUMBER+1))
        RESET=1
      fi
    else
      NUMBER=0
    fi

    echo -n "${NUMBER}${OUTPUT_SEPARATOR}"

    if [ $POS -ge 1 ];
    then
      OUTPUT_SEPARATOR=""
    fi

    POS=$((POS+1))
  done
}

function validate_templates_checksum() {
  GENERATOR=$1
  LIBRARY=$2
  RESULT=0

  if [ ! -z "$LIBRARY" ];
  then
    LIBRARY="--library $LIBRARY"
  fi

  $OPENAPI_GENERATOR_COMMAND author template -g $GENERATOR $LIBRARY -o generated/templates/${GENERATOR} > /dev/null

  pushd generated/templates/${GENERATOR} > /dev/null
  shasum -a 256 * >| SHA256SUM
  popd > /dev/null

  OUR_SHASUMS=generators/${GENERATOR}/templates/SHA256SUM
  echo >| $OUR_SHASUMS.new

  for TEMPLATE in $(ls generators/${GENERATOR}/templates/ | grep -v SHA256SUM) ;
  do
    FILENAME=$(basename $TEMPLATE)

    LIB_SHASUM=$(grep $FILENAME generated/templates/${GENERATOR}/SHA256SUM | awk '{print $1}' || true)
    OUR_SHASUM=$(grep $FILENAME $OUR_SHASUMS | awk '{print $1}' || true)

    if [[ ! -z "$LIB_SHASUM" ]];  # File is provided by lib
    then
      if [ ! -z "$OUR_SHASUM" ] && [[ "$LIB_SHASUM" != "$OUR_SHASUM" ]];   # We do have checksum and doesn't match
      then
        echo -e "\n################################################################################\n"
        echo -e " !!! Error while building generator ${GENERATOR}!!!\n"
        echo " SHA256SUM for template $FILENAME changed, diff reported below. To overwrite template, run:"
        echo "  cp generated/templates/${GENERATOR}/$FILENAME generators/${GENERATOR}/templates/"
        echo
        diff generated/templates/${GENERATOR}/$FILENAME generators/${GENERATOR}/templates/$FILENAME || true
        RESULT=1
      fi

      echo "$LIB_SHASUM  $FILENAME" >> $OUR_SHASUMS.new
    fi
  done

  # If any change to checksums
  if [ $RESULT -ne 0 ];
  then
    mv $OUR_SHASUMS.new $OUR_SHASUMS
  else
    unlink $OUR_SHASUMS.new
  fi

  return $RESULT
}

cd ${BASEDIR}
rm -rf generated; mkdir -p generated/configuration

for GENERATOR in $GENERATORS
do
  if [ "${GENERATOR}" != "common" ];
  then
    echo "Building configuration for generator ${GENERATOR}..."

    GENERATOR_FOLDER=generators/${GENERATOR}
    CONFIG_FILE=${GENERATOR_FOLDER}/config.yaml
    GENERATED_CONFIG_FILE=generated/configuration/${GENERATOR}.yaml

    GIT_REPO_ID=$(grep gitRepoId: $CONFIG_FILE | sed 's/gitRepoId: //g')
    LIBRARY=$(grep library: $CONFIG_FILE | sed 's/library: //g')

    if [ -n "${GIT_REPO_ID}" ];
    then
      LATEST_LIBRARY_VERSION=$(curl -s https://api.github.com/repos/onfido/${GIT_REPO_ID}/releases/latest | jq .name | sed 's/[v"]//g')
      CURRENT_LIBRARY_VERSION=$(semver_bump ${LATEST_LIBRARY_VERSION} ${BUMP_CLIENT_LIBRARY_VERSION})

      echo "Latest delivered version was: ${LATEST_LIBRARY_VERSION}"
      echo "Current version is going to be: ${CURRENT_LIBRARY_VERSION}"
      echo "Should bump client library?: ${BUMP_CLIENT_LIBRARY_VERSION}"
    else
      CURRENT_LIBRARY_VERSION=""
    fi

    validate_templates_checksum $GENERATOR $LIBRARY

    ( cat $COMMON_CONFIG_FILE && echo && cat $CONFIG_FILE ) | \
        GENERATOR=${GENERATOR} \
        CLIENT_LIBRARY_VERSION=${CURRENT_LIBRARY_VERSION} \
        envsubst >| ${GENERATED_CONFIG_FILE}

    echo "Configuration for generator ${GENERATOR} built."

    # Dump version number aside to have github action retrieving them later on
    if [ -n "${GITHUB_OUTPUT}" -a -n "${CURRENT_LIBRARY_VERSION}" ];
    then
      echo "$(echo $GENERATOR | tr - _ )_version=${CURRENT_LIBRARY_VERSION}" >> $GITHUB_OUTPUT
    fi

    GENERATED_CONFIG_FILES="${GENERATED_CONFIG_FILES} ${GENERATED_CONFIG_FILE}"
  fi
done

${OPENAPI_GENERATOR_COMMAND} batch --clean ${GENERATED_CONFIG_FILES}
