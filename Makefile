.PHONY: setup serve clean clean_scenarios build install_pupa scenario1 scenario1conda scenario2 scenario2conda scenario3 scenario3conda scenario4 scenario4conda

setup: install_pupa
	python -m venv .venv
	.venv/bin/pip install -r requirements.txt

install_pupa:
	rm -rf pupa
	mkdir -p pupa
	conda create -p pupa/.env python=3.12 conda conda-index -y
	git clone https://github.com/dholth/conda-pupa.git pupa/conda-pupa
	pupa/.env/bin/pip install -e pupa/conda-pupa

build: clean
	.venv/bin/python build_packages.py

serve:
	.venv/bin/fastapi dev ./pypi_server.py --no-reload

clean: clean_scenarios
	rm -rf conda-packages
	find dep-* -type f -name "*.whl" -delete

clean_scenarios:
	rm -rf scenario*

scenario1: clean_scenarios
	@echo "This scenario shows that pip will update a simple package to satisfy the requirements"
	@echo "Then, it shows that if you delete the .dist-info directory, python can use the package, but pip doesn't know it exists"
	mkdir -p scenario1
	python -m venv scenario1/.venv
	scenario1/.venv/bin/pip install 'dep-plain==0.1.0' --index-url http://localhost:8000 --no-cache-dir
	scenario1/.venv/bin/python -c "import dep_plain; dep_plain.hello()"
	scenario1/.venv/bin/pip install 'dep-plain>0.2.0' --index-url http://localhost:8000 --no-cache-dir
	scenario1/.venv/bin/python -c "import dep_plain; dep_plain.hello()"

	@echo "Deleting the .dist-info directory"
	rm -rf scenario1/.venv/lib/python3.*/site-packages/dep_plain-*.dist-info
	scenario1/.venv/bin/python -c "import dep_plain; dep_plain.hello()"

	@echo "Installing dep-plain to show that pip re-installs the package"
	scenario1/.venv/bin/pip install 'dep-plain>0.2.0' --index-url http://localhost:8000 --no-cache-dir
	scenario1/.venv/bin/python -c "import dep_plain; dep_plain.hello()"

scenario1conda: clean_scenarios
	@echo "This is the same as scenario1, but using conda to install the package"
	mkdir -p scenario1conda
	conda create -p scenario1conda/.env --channel file://$(PWD)/conda-packages -y python=3.12 'dep-plain=0.1.0'
	scenario1conda/.env/bin/python -c "import dep_plain; dep_plain.hello()"

	@echo "Updating dep-plain"
	conda install -p scenario1conda/.env --channel file://$(PWD)/conda-packages -y 'dep-plain>0.2.0'
	scenario1conda/.env/bin/python -c "import dep_plain; dep_plain.hello()"

	@echo "No-op if the requirement is already satisfied"
	conda install -p scenario1conda/.env --channel file://$(PWD)/conda-packages -y 'dep-plain>0.2.0'

	@echo "Deleting the .dist-info directory"
	rm -rf scenario1conda/.env/lib/python3.*/site-packages/dep_plain-*.dist-info
	scenario1conda/.env/bin/python -c "import dep_plain; dep_plain.hello()"

	@echo "Installing dep-plain shows that conda already thinks the package is installed and no-ops"
	conda install -p scenario1conda/.env --channel file://$(PWD)/conda-packages -y 'dep-plain>0.2.0'
	scenario1conda/.env/bin/python -c "import dep_plain; dep_plain.hello()"

	@echo "Deleting the conda-meta json file"
	rm scenario1conda/.env/conda-meta/dep-plain-*.json

	@echo "Installing dep-plain to show that conda re-installs the package"
	conda install -p scenario1conda/.env --channel file://$(PWD)/conda-packages -y 'dep-plain>0.2.0'
	scenario1conda/.env/bin/python -c "import dep_plain; dep_plain.hello()"

scenario2: clean_scenarios
	@echo "This scenario covers what happens if you have a dependency that can't be satisfied"
	@echo "First we'll try to install both at the same time, which will fail"
	@echo "Then, we'll install urllib3 first, and then dep-old which will downgrade urllib3 to 1.x"
	mkdir -p scenario2
	python -m venv scenario2/.venv
	scenario2/.venv/bin/pip install 'dep-old==0.1.0' 'dep-urllib3==2.3.0' --index-url http://localhost:8000 --no-cache-dir || true
	scenario2/.venv/bin/pip install 'dep-urllib3==2.3.0' --index-url http://localhost:8000 --no-cache-dir
	scenario2/.venv/bin/pip install 'dep-old==0.1.0' --index-url http://localhost:8000 --no-cache-dir

scenario2conda: clean_scenarios
	@echo "This is the same as scenario2, but using conda to install the packages"
	mkdir -p scenario2conda
	conda create -p scenario2conda/.env --channel file://$(PWD)/conda-packages -y python=3.12 'dep-old=0.1.0' 'dep-urllib3=2.3.0' || true
	conda create -p scenario2conda/.env --channel file://$(PWD)/conda-packages -y python=3.12 'dep-urllib3=2.3.0'
	@echo "Unlike pip, conda won't downgrade urllib3 since it was user-installed"
	conda install -p scenario2conda/.env --channel file://$(PWD)/conda-packages -y 'dep-old=0.1.0' || true

scenario3: clean_scenarios
	@echo "This scenario covers what happens if an old version of a package doens't have the correct dependency specifiers"
	mkdir -p scenario3
	python -m venv scenario3/.venv
	scenario3/.venv/bin/pip install 'dep-bad-upper-bound' 'dep-urllib3==2.3.0' --index-url http://localhost:8000 --no-cache-dir
	scenario3/.venv/bin/python -c "import dep_bad_upper_bound; dep_bad_upper_bound.hello()"

scenario3conda: clean_scenarios
	@echo "This is the same as scenario3, but using conda to install the packages"
	mkdir -p scenario3conda
	conda create -p scenario3conda/.env --channel file://$(PWD)/conda-packages -y python=3.12 'dep-bad-upper-bound' 'dep-urllib3=2.3.0'
	scenario3conda/.env/bin/python -c "import dep_bad_upper_bound; dep_bad_upper_bound.hello()"

scenario4: clean_scenarios
	@echo "This scenario shows that pip uses the .dist-info/METADATA field to determine what a package's dependencies are"
	@echo "First we'll install dep-old, which requires urllib3 v1. Then we'll modify the METADATA to allow urllib3 v2"
	@echo "Finally, we'll install urllib3 v2 and see that pip will allow installation"
	mkdir -p scenario4
	python -m venv scenario4/.venv
	scenario4/.venv/bin/pip install 'dep-old==0.1.0' --index-url http://localhost:8000 --no-cache-dir
	scenario4/.venv/bin/python -c "import dep_old; dep_old.hello()"
	@echo "Now we'll modify the METADATA to allow urllib3 v2"
	sed -i '' 's/dep-urllib3==1.26.20/dep-urllib3>=1.0.0/' scenario4/.venv/lib/python3.*/site-packages/dep_old-0.1.0.dist-info/METADATA
	scenario4/.venv/bin/pip install 'dep-urllib3==2.3.0' --index-url http://localhost:8000 --no-cache-dir
	scenario4/.venv/bin/python -c "import dep_old; dep_old.hello()"
	
scenario4conda: clean_scenarios
	@echo "This is the same as scenario4, but using conda to install the packages"
	mkdir -p scenario4conda
	conda create -p scenario4conda/.env --channel file://$(PWD)/conda-packages -y python=3.12 'dep-old=0.1.0'
	scenario4conda/.env/bin/python -c "import dep_old; dep_old.hello()"

	@echo "Now we'll modify the METADATA to allow urllib3 v2"
	sed -i '' 's/dep-urllib3==1.26.20/dep-urllib3>=1.0.0/' scenario4conda/.env/lib/python3.*/site-packages/dep_old-0.1.0.dist-info/METADATA
	@echo "This doesn't work for conda because it doesn't pay any attention to the METADATA file"
	conda install -p scenario4conda/.env --channel file://$(PWD)/conda-packages -y 'dep-urllib3=2.3.0'
