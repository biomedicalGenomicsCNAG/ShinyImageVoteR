# Makefile for the Shiny imgVoteR Package
# Usage: make [target]

# Package information
PACKAGE_NAME = ShinyImgVoteR
VERSION = 0.1.0
TARBALL = $(PACKAGE_NAME)_$(VERSION).tar.gz

# R command
R = /usr/bin/R
RSCRIPT = Rscript

# DEBUG_TESTS = dev_scripts/debug-tests.sh
DEBUG_TESTS = dev_scripts/debug-tests.R

CONFIG_FILE_RELATIVE_PATH = app_env/config/config.yaml
CONFIG_FILE_PATH = $(realpath $(CONFIG_FILE_RELATIVE_PATH))

# SHELL := /usr/bin/env bash

# Default target
.PHONY: all
all: build

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  build        - Build the R package"
	@echo "  install      - Install the package locally"
	@echo "  check        - Run R CMD check"
	@echo "  test         - Run package tests"
	@echo "  coverage     - Generate test coverage report"
	@echo "  clean        - Clean build artifacts"
	@echo "  rebuild      - Clean, build, and install"
	@echo "  setup-userdata  - Setup external environment (config/, user_data/, database, images/)"
	@echo "  run          - Install package, setup user_data, and run the Shiny app"
	@echo "  document     - Generate documentation with roxygen2"
	@echo "  deps         - Install package dependencies"
	@echo "  setup-userdata - Setup user_data directory outside package"
	@echo "  setup-dev    - Setup development environment"
	@echo "  all          - Build the package (default)"

# Build the package
.PHONY: build
build:
	@echo "Building R package..."
	$(R) CMD build .
	@echo "Package built: $(TARBALL)"

# Install the package
.PHONY: install
install: build
	@echo "Installing R package..."
	$(R) CMD INSTALL $(TARBALL)
	@echo "Package installed successfully"

# Run R CMD check
.PHONY: check
check: build
	@echo "Checking R package..."
	$(R) CMD check $(TARBALL)

# Run package tests
.PHONY: test
test: install
	@echo "Running package tests..."
	$(RSCRIPT) -e "devtools::test()"

.PHONY: debug-test
debug-test: install
	chmod +x $(DEBUG_TESTS)
	@$(DEBUG_TESTS)

# Generate test coverage
.PHONY: coverage
cov: install
	@echo "Generating test coverage report"
	@$(RSCRIPT) dev_scripts/coverage.R

# Setup external environment (user_data, database, and config)
.PHONY: setup-userdata
setup-userdata: install
	@echo "Setting up external environment (user_data, database, and config)..."
	$(RSCRIPT) -e "library($(PACKAGE_NAME)); init_external_environment(); cat('External environment setup complete\n')"

# Run the Shiny application with external user_data
.PHONY: run
# run: install setup-userdata
run: install 
	@echo "Starting Shiny application with external user_data..."
	$(RSCRIPT) -e "devtools::load_all(); run_voting_app(config_file_path = '$(CONFIG_FILE_PATH)')"

# Generate documentation
.PHONY: document
document:
	@echo "Generating documentation..."
	$(RSCRIPT) -e "if(!require('roxygen2')) install.packages('roxygen2'); roxygen2::roxygenise()"

# Install dependencies
.PHONY: deps
deps:
	@echo "Installing package dependencies..."
	$(RSCRIPT) -e "if(!require('devtools')) install.packages('devtools'); devtools::install_deps(dependencies = TRUE)"

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm $(PACKAGE_NAME)_*.tar.gz
	@echo "Cleaned build artifacts"

# Rebuild everything
.PHONY: rebuild
rebuild: clean build install

# Test the installed package functions
.PHONY: test-functions
test-functions: install
	@echo "Testing package functions..."
	$(RSCRIPT) -e "library($(PACKAGE_NAME)); cat('Testing run_voting_app function exists:', exists('run_voting_app'), '\n'); cat('Testing get_app_dir function:', get_app_dir(), '\n')"

# Quick coverage check
.PHONY: coverage-quick
coverage-quick: install
	@echo "Running quick coverage analysis..."
	$(RSCRIPT) -e "library(covr); library($(PACKAGE_NAME)); cov <- package_coverage(); cat('Overall coverage:', percent_coverage(cov), '%\n')"

# Development workflow
.PHONY: dev
dev: document build install test-functions
	@echo "Development workflow completed"

# CI/CD simulation
.PHONY: ci
ci: deps document build check test coverage-quick
	@echo "CI/CD simulation completed"

# Show package information
.PHONY: info
info:
	@echo "Package: $(PACKAGE_NAME)"
	@echo "Version: $(VERSION)"
	@echo "Tarball: $(TARBALL)"
	@echo "R Version: $$($(R) --version | head -1)"

# Show installed package info
.PHONY: package-info
package-info: install
	@echo "Showing installed package information..."
	$(RSCRIPT) -e "library($(PACKAGE_NAME)); cat('Package path:', find.package('$(PACKAGE_NAME)'), '\n'); cat('App directory:', get_app_dir(), '\n')"

# Setup development environment
.PHONY: setup-dev
setup-dev: setup-userdata
	@echo "Setting up development environment..."
	@if [ -d "inst/shiny-app/db.sqlite" ]; then \
		echo "Moving database file..."; \
		mv inst/shiny-app/db.sqlite . || true; \
	fi
	@echo "Development environment setup complete"

stop:
	fuser -k 8000/tcp

vignettes-build:
	@echo "Building vignettes..."
	$(R) -e "devtools::build_vignettes()"

vignettes-run: vignettes-build
	@echo "Running vignettes..."
	$(R) -e "devtools::load_all(); rmarkdown::run('vignettes/shinyImgVoter.Rmd')"

# NOTE: below is only working directly in R
pkgdown:
	$(R) -e "pkgdown::build_site()"