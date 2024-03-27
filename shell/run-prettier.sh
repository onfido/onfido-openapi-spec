#!/usr/bin/env bash

# Don't carry on when any command fails
set -e

if [ "$1" == 'check' ]
then
  option="-c"
else
  option="--write"
fi

npm install prettier
npx prettier $option openapi.yaml paths/*.yaml schemas/**/*.yaml responses/**/*.yaml \
                     generators/**/config.yaml .github/workflows/*.yaml
npx prettier $option --parser markdown generators/*/templates/README.mustache
npx prettier $option --parser typescript generators/typescript-axios/templates/webhook-event-verifier.mustache
