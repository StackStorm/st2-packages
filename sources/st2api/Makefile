.PHONY: install debchange all requirements 

setup_py_prerequisites: st2_version debchange wheelhouse 
	touch setup_py_prerequisites

all: install

# Borrow global version if there's no specific one (NOT .PHONY)
st2_version:
	install -m644 ../st2_version ./st2_version

install: setup_py_prerequisites
	@echo "st2common" >> requirements.txt

debchange:
	$(eval ST2_VER := $(shell cat st2_version))
	debchange -v $(ST2_VER) -M 'new version build'

requirements:
	python ../scripts/fixate-requirements.py -s in-requirements.txt -f ../fixed-requirements.txt

# Install wheels into shared location
wheelhouse: requirements
	pip wheel --wheel-dir=/tmp/wheelhouse -r requirements.txt
