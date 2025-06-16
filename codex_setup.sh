#!/bin/bash
# This script sets up the dev environment for the B1MG-variant-voting project in OpenAI codex.

curl -O https://cdn.posit.co/r/ubuntu-2404/pkgs/r-${R_VERSION}_1_$(dpkg --print-architecture).deb
apt update
apt install ./r-${R_VERSION}_1_$(dpkg --print-architecture).deb -y

cd shiny && Rscript codex_setup.R