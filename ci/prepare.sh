#!/bin/bash

nextReleaseVersion="$1"
ACR="$ACR"

RELEASE=${nextReleaseVersion} ACR=${ACR} make ci-package
