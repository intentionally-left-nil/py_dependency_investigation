.PHONY: setup serve scenario1 clean clean_wheels clean_scenarios build_all_wheels build
setup:
	python -m venv .venv
	.venv/bin/pip install -r requirements.txt

build: clean
	.venv/bin/python build_wheels.py

serve:
	.venv/bin/fastapi dev ./pypi_server.py --no-reload

clean: clean_scenarios
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

scenario2: clean_scenarios
	@echo "This scenario covers what happens if you have a dependency that can't be satisfied"
	@echo "First we'll try to install both at the same time, which will fail"
	@echo "Then, we'll install urllib3 first, and then dep-old which will downgrade urllib3 to 1.x"
	mkdir -p scenario2
	python -m venv scenario2/.venv
	scenario2/.venv/bin/pip install 'dep-old==0.1.0' 'dep-urllib3==2.3.0' --index-url http://localhost:8000 --no-cache-dir || true
	scenario2/.venv/bin/pip install 'dep-urllib3==2.3.0' --index-url http://localhost:8000 --no-cache-dir
	scenario2/.venv/bin/pip install 'dep-old==0.1.0' --index-url http://localhost:8000 --no-cache-dir

scenario3: clean_scenarios
	@echo "This scenario covers what happens if an old version of a package doens't have the correct dependency specifiers"
	mkdir -p scenario3
	python -m venv scenario3/.venv
	scenario3/.venv/bin/pip install 'dep-bad-upper-bound' 'dep-urllib3==2.3.0' --index-url http://localhost:8000 --no-cache-dir
	scenario3/.venv/bin/python -c "import dep_bad_upper_bound; dep_bad_upper_bound.hello()"


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
	
