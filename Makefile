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

.PHONY: .generated-files-check
.generated-files-check:
	# Verify that all the files which are automatically generated have indeed
	# been re-generated and committed.
	@echo "==================== generated-files-check ===================="
	make scriptsgen
	export NEED_COMMIT=0; \
	for i in scripts/st2bootstrap-*.sh; \
	do \
		export FILE=$$(git status -s "$$i"); \
		if grep -E " M $$i" <<<$$FILE ; then \
			echo "$$i hasn't been re-generated and committed. Please run \"make scriptsgen\" and include and commit the generated file."; \
			export NEED_COMMIT=1; \
			git diff "$$i" | cat; \
		elif grep -E "\?\? $$i" <<<$$FILE ; then \
			echo "$$i does not appear to be under git control!?  Please add it to git or remove it from the directory."; \
		fi; \
	done; \
	test $$NEED_COMMIT -eq 1 && exit 2 || true
	@echo "All automatically generated files are up to date."

