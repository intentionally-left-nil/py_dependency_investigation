.PHONY: setup serve scenario1 clean clean_wheels clean_scenarios build_all_wheels
setup:
	python -m venv .venv
	.venv/bin/pip install -r requirements.txt

serve:
	.venv/bin/fastapi dev ./pypi_server.py

clean:
	rm -rf scenario1

clean_wheels:	
	find dep-* -type f -name "*.whl" -delete

clean_scenarios:
	rm -rf scenario*

build_all_wheels: clean_wheels
	.venv/bin/python build_wheels.py

scenario1: clean_scenarios
	mkdir -p scenario1
	python -m venv scenario1/.venv
	.venv/bin/python build_wheels.py dep-a
	scenario1/.venv/bin/pip install 'dep-a==0.1.0' --index-url http://localhost:8000 --no-cache-dir
	scenario1/.venv/bin/python -c "import dep_a; dep_a.hello()"
	scenario1/.venv/bin/pip install 'dep-a>0.2.0' --index-url http://localhost:8000 --no-cache-dir
	scenario1/.venv/bin/python -c "import dep_a; dep_a.hello()"
