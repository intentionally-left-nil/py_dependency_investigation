.PHONY: setup serve scenario1 clean build_wheels
setup:
	python -m venv .venv
	.venv/bin/pip install -r requirements.txt

serve:
	.venv/bin/fastapi dev ./pypi_server.py

clean:
	rm -rf scenario1
	find dep-* -type f -name "*.whl" -delete
	

build_wheels:
	cd dep-a && hatch build -t wheel

scenario1: build_wheels
	mkdir -p scenario1
	python -m venv scenario1/.venv
	scenario1/.venv/bin/pip install dep-a==0.0.1 --index-url http://localhost:8000 --no-cache-dir
	scenario1/.venv/bin/python -c "import dep_a; dep_a.hello()"
