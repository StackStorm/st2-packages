ROOT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
SHELL := /bin/bash
VIRTUALENV_DIR ?= virtualenv/st2packages
.DEFAULT_GOAL := scriptsgen

.PHONY: .create_venv
.create_venv:
	test -d "$(VIRTUALENV_DIR)" || python3 -m venv "$(VIRTUALENV_DIR)"

.PHONY: .install_dependencies
.install_dependencies:
	"$(VIRTUALENV_DIR)/bin/pip3" install -r requirements.txt

.PHONY: clean
clean:
	test -d "$(VIRTUALENV_DIR)" && rm -rf "$(VIRTUALENV_DIR)"

.PHONY: scriptsgen
scriptsgen: .create_venv .install_dependencies
	@echo
	@echo "================== scripts gen ===================="
	@echo
	"$(VIRTUALENV_DIR)/bin/python3" tools/generate_install_script.py
	# Remove comments to reduce script size by ~7k
	for i in scripts/st2bootstrap-*.sh; \
	do \
		grep -Ev '^\s*#[^!]' "$$i" >"$$i".s && mv "$$i".s "$$i"; \
	done

.PHONY: .generated-files-check
.generated-files-check:
	# Verify that all the files which are automatically generated have indeed been re-generated and
	# committed
	@echo "==================== generated-files-check ===================="

	mkdir -p /tmp/scripts
	for i in scripts/st2bootstrap-*.sh; \
	do \
		cp scripts/$$i /tmp/$$i \
	done

	make scriptsgen

	for i in scripts/st2bootstrap-*.sh; \
	do \
		diff $i /tmp/$$i || (echo "scripts/st2bootstrap-deb.sh hasn't been re-generated and committed. Please run \"make scriptsgen\" and include and commit the generated file." && exit 1); \
	done

	@echo "All automatically generated files are up to date."
