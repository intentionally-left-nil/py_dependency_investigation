from typing import TypedDict
from pathlib import Path
import tomli
import tomli_w
import re
import subprocess
import sys
class Version(TypedDict):
    dependencies: list[str]

class Package(TypedDict):
    versions: dict[str, Version]



packages: dict[str, Package] = {
    "dep-a": {
        "versions": {
            "0.1.0": {
                "dependencies": []
            },
            "0.2.0": {
                "dependencies": []
            },
            "1.0.0": {
                "dependencies": []
            },
        }
    }
}


def build_wheels_for_package(package_name: str) -> None:
    root = Path(__file__).parent / package_name
    pyproject_path = root / "pyproject.toml"
    if not pyproject_path.exists():
        raise ValueError(f"pyproject.toml not found for {package_name}")
    
    original_pyproject = pyproject_path.read_text()

    about_path = root / package_name.replace("-", "_") / "__about__.py"
    if not about_path.exists():
        raise ValueError(f"__about__.py not found for {package_name}")
    original_about = about_path.read_text()

    try:
        for version, version_data in packages[package_name]["versions"].items():
            pyproject = tomli.loads(original_pyproject)
            pyproject["project"]["dependencies"] = version_data["dependencies"]
            _ = pyproject_path.write_text(tomli_w.dumps(pyproject))

            about = re.sub(r"__version__ = +.*", f'__version__ = "{version}"', original_about)
            _ = about_path.write_text(about)

            print(f"Building {package_name}=={version}")
            _ = subprocess.run(["hatch", "build", "-t", "wheel"], cwd=root, check=True)
    finally:
        _ = pyproject_path.write_text(original_pyproject)
        _ = about_path.write_text(original_about)
    

if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) == 0:
        for package_name in packages.keys():
            build_wheels_for_package(package_name)
    else:
        for package_name in args:
            if package_name not in packages:
                raise ValueError(f"Package {package_name} not found")
            build_wheels_for_package(package_name)


