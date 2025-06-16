#!/bin/bash
# This script sets up the dev environment for the B1MG-variant-voting project in OpenAI codex.

apt update && apt install r-base -y
cd shiny && Rscript codex_setup.R