setup:
	python -m venv .venv
	.venv/bin/pip install -r requirements.txt

serve:
	.venv/bin/fastapi dev ./pypi_server.py
