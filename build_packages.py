from typing import TypedDict
from pathlib import Path
import tomli
import tomli_w
import re
import subprocess
import sys


class Version(TypedDict):
    dependencies: list[str]


class Project(TypedDict):
    versions: dict[str, Version]


projects: dict[str, Project] = {
    "dep-plain": {
        "versions": {
            "0.1.0": {"dependencies": []},
            "0.2.0": {"dependencies": []},
            "1.0.0": {"dependencies": []},
        }
    },
    "dep-urllib3": {
        "versions": {
            "1.26.20": {"dependencies": []},
            "2.3.0": {"dependencies": []},
        }
    },
    "dep-old": {"versions": {"0.1.0": {"dependencies": ["dep-urllib3==1.26.20"]}}},
    "dep-bad-upper-bound": {
        "versions": {
            "0.1.0": {"dependencies": ["dep-urllib3>=1.0.0"]},
            "0.2.0": {"dependencies": ["dep-urllib3~=1.0"]},
        }
    },
}


def build_packages_for_project(project_name: str) -> None:
    root = Path(__file__).parent
    project_root = root / project_name
    conda_path = root / "pupa" / ".env" / "bin" / "conda"
    if not conda_path.exists():
        raise ValueError(f"conda not found in {conda_path}")

    hatch_path = root / ".venv" / "bin" / "hatch"
    if not hatch_path.exists():
        raise ValueError(f"hatch not found in {hatch_path}")

    pyproject_path = project_root / "pyproject.toml"
    if not pyproject_path.exists():
        raise ValueError(f"pyproject.toml not found for {project_name}")

    original_pyproject = pyproject_path.read_text()

    about_path = project_root / project_name.replace("-", "_") / "__about__.py"
    if not about_path.exists():
        raise ValueError(f"__about__.py not found for {project_name}")
    original_about = about_path.read_text()

    noarch_path = root / "conda-packages" / "noarch"
    noarch_path.mkdir(parents=True, exist_ok=True)

    try:
        for version, version_data in projects[project_name]["versions"].items():
            pyproject = tomli.loads(original_pyproject)
            pyproject["project"]["dependencies"] = version_data["dependencies"]
            _ = pyproject_path.write_text(tomli_w.dumps(pyproject))

            about = re.sub(
                r"__version__ = +.*", f'__version__ = "{version}"', original_about
            )
            _ = about_path.write_text(about)

            print(f"Building {project_name}=={version}")
            _ = subprocess.run(
                [hatch_path, "build", "-t", "wheel"], cwd=project_root, check=True
            )

            print(f"Building conda package for {project_name}=={version}")
            _ = subprocess.run(
                [
                    conda_path,
                    "pupa",
                    "--output-folder",
                    noarch_path,
                    "--build",
                    project_root,
                ],
                check=True,
            )
        _ = subprocess.run(
            [conda_path, "index", "--no-compact", noarch_path.parent], check=True
        )
    finally:
        _ = pyproject_path.write_text(original_pyproject)
        _ = about_path.write_text(original_about)


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) == 0:
        for project_name in projects.keys():
            build_packages_for_project(project_name)
    else:
        for project_name in args:
            if project_name not in projects:
                raise ValueError(f"Project {project_name} not found")
            build_packages_for_project(project_name)
