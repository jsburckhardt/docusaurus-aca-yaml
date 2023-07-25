#!/usr/bin/env bash

set -euo pipefail

az extension add --name containerapp

npm install -g markdownlint
npm install -g markdownlint-cli
npm install -g cspell@latest
cd src/docusaurus && npm install && npm install --only=dev
