from fastapi import FastAPI

app = FastAPI(
    title="PyPI Server",
    version="1.0.0"
)


@app.get("/")
async def index():
    """
    List all available packages (similar to PyPI's simple index)
    """
    return {"hello": "world"}
