.PHONY: scriptsgen
scriptsgen:
	@echo
	@echo "================== scripts gen ===================="
	@echo
	/usr/bin/env python3 tools/generate_final_installer_scripts.py

.PHONY: .generated-files-check
.generated-files-check:
	# Verify that all the files which are automatically generated have indeed been re-generated and
	# committed
	@echo "==================== generated-files-check ===================="

	# 1. Sample config - conf/st2.conf.sample
	cp scripts/st2bootstrap-deb.sh /tmp/st2bootstrap-deb.sh.upstream
	cp scripts/st2bootstrap-el8.sh /tmp/st2bootstrap-el8.sh.upstream
	cp scripts/st2bootstrap-el9.sh /tmp/st2bootstrap-el9.sh.upstream

	make scriptsgen

	diff scripts/st2bootstrap-deb.sh /tmp/st2bootstrap-deb.sh.upstream || (echo "scripts/st2bootstrap-deb.sh hasn't been re-generated and committed. Please run \"make scriptsgen\" and include and commit the generated file." && exit 1)
	diff scripts/st2bootstrap-el8.sh /tmp/st2bootstrap-el8.sh.upstream || (echo "scripts/st2bootstrap-el8.sh hasn't been re-generated and committed. Please run \"make scriptsgen\" and include and commit the generated file." && exit 1)
	diff scripts/st2bootstrap-el9.sh /tmp/st2bootstrap-el9.sh.upstream || (echo "scripts/st2bootstrap-el9.sh hasn't been re-generated and committed. Please run \"make scriptsgen\" and include and commit the generated file." && exit 1)

	@echo "All automatically generated files are up to date."
