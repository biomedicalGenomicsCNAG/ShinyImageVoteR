#!/bin/bash
# This script sets up the dev environment for the B1MG-variant-voting project in OpenAI codex.

apt update && apt install r-base -y
cd shiny
R -e 'install.packages("pak", repos = "https://r-lib.github.io/p/pak/stable/source/linux-gnu/x86_64")'