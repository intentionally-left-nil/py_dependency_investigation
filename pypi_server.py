from fastapi import FastAPI

from datetime import datetime
from typing import ClassVar, Any
from typing_extensions import override
import json
from pathlib import Path
from packaging.utils import parse_wheel_filename
from packaging.utils import canonicalize_name
from packaging.version import Version
from pydantic import BaseModel, Field, ConfigDict
from fastapi.responses import FileResponse, Response
from fastapi.exceptions import HTTPException
import hashlib
import re


class Meta(BaseModel):
    api_version: str = Field(validation_alias="api-version")
    model_config: ClassVar[ConfigDict] = ConfigDict(populate_by_name=True)


class IndexResponse(BaseModel):
    class Project(BaseModel):
        name: str
        model_config: ClassVar[ConfigDict] = ConfigDict(populate_by_name=True)

    meta: Meta
    projects: list[Project]


class PackageResponse(BaseModel):
    class File(BaseModel):
        filename: str
        url: str
        hashes: dict[str, str]
        provenance: str | None = None
        requires_python: str | None = Field(None, validation_alias="requires-python")
        core_metadata: bool | dict[str, str] = Field(
            default=False, validation_alias="core-metadata"
        )
        size: int | None = None
        yanked: bool | str | None = None
        upload_time: datetime | None = Field(None, validation_alias="upload-time")

    meta: Meta
    name: str
    versions: list[str]
    files: list[File]

app = FastAPI(
    title="PyPI Server",
    version="1.0.0"
)

simple_content_type = "application/vnd.pypi.simple.v1+json"
class SimpleResponse(Response):
    media_type: str = simple_content_type

    @override
    def render(self, content: Any) -> bytes:
        return json.dumps(content).encode("utf-8")

@app.get("/", response_model=IndexResponse, response_class=SimpleResponse)
async def index() -> IndexResponse:
    """
    List all available packages (similar to PyPI's simple index)
    """
    current_dir = Path(__file__).parent
    wheels = current_dir.glob("dep-*/**/*.whl")
    project_names = {canonicalize_name(parse_wheel_filename(wheel.name)[0]) for wheel in wheels}
    
    projects = [IndexResponse.Project(name=name) for name in sorted(project_names)]

    return IndexResponse(
        meta=Meta(api_version="1.0"),
        projects=projects
    )

def get_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate_project_name(project_name: str) -> None:
    if not re.match(r"^[a-zA-Z0-9_-]+$", project_name):
        raise HTTPException(status_code=400, detail="Invalid project name")

@app.get("/{project_name}", response_model=PackageResponse, response_class=SimpleResponse)
async def package(project_name: str) -> PackageResponse:
    validate_project_name(project_name)
    current_dir = Path(__file__).parent
    wheels = current_dir.glob(f"dep-*/**/*.whl")
    files: list[PackageResponse.File] = []
    versions: list[str] = []
    for wheel in wheels:
        name, version, _, _ = parse_wheel_filename(wheel.name)
        if name != canonicalize_name(project_name):
            continue
        files.append(PackageResponse.File(
            filename=wheel.name,
            url=f"/{project_name}/{wheel.name}",
            hashes={"sha256": get_sha256(wheel)},
            requires_python=None,
            upload_time=None,
        ))
        versions.append(str(version))
    versions.sort(key=lambda v: Version(v), reverse=True)
    return PackageResponse(
        meta=Meta(api_version="1.0"),
        name=project_name,
        versions=versions,
        files=files,
    )

@app.get("/{project_name}/{wheel_name}.whl")
async def get_wheel(project_name: str, wheel_name: str) -> FileResponse:
    validate_project_name(project_name)
    wheel_name = wheel_name + '.whl'
    current_dir = Path(__file__).parent
    wheels = list(current_dir.glob(f"{canonicalize_name(project_name)}/**/{wheel_name}"))
    if len(wheels) != 1:
        raise HTTPException(status_code=404, detail="Wheel not found")
    return FileResponse(wheels[0])
