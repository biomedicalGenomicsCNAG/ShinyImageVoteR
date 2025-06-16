#!/bin/bash
# This script sets up the dev environment for the B1MG-variant-voting project in OpenAI codex.
# ENV VAR set in codex: R_VERSION=4.5.0

curl -O https://cdn.posit.co/r/ubuntu-2404/pkgs/r-${R_VERSION}_1_$(dpkg --print-architecture).deb
apt update
apt install ./r-${R_VERSION}_1_$(dpkg --print-architecture).deb -y

ln -s /opt/R/${R_VERSION}/bin/R /usr/local/bin/R
ln -s /opt/R/${R_VERSION}/bin/Rscript /usr/local/bin/Rscript

cd shiny && Rscript codex_setup.R