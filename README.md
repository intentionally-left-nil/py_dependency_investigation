# Pip + Conda investigation

## Overview

This respository is a harness of test scenarios to investigate how pip and conda install python projects. The basic idea is that there are a bunch of simple projects named `dep-???` which interact in different ways. The build_packages.py script generates multiple versions of these projects with different versions & different dependencies. See the `projects` variable in [build_packages.py](build_packages.py) for these combinations. These packages are then installed into environments using some combination of pip and conda, and we can use this test harness to investigate!

## Getting Started

Beforehand, you need to have the following binaries installed:

- conda
- python

```sh
git clone git@github.com:intentionally-left-nil/py_dependency_investigation.git
cd py_dependency_investigation
make setup
make build
```

Then, we need to open a new background terminal and keep the pypi server running:

```sh
make serve
```

Now, we can run the various scenarios, e.g.

```sh
make scenario1
make scenario2
...
```

# Package Structure

This repository contains several test packages that demonstrate different dependency scenarios:

## Package Details

- **dep-plain**: A simple package used to demonstrate basic version updates and package management behavior.

- **dep-urllib3**: A mock package that simulates urllib3's version changes, used to demonstrate compatibility issues between major versions.

- **dep-old**: Demonstrates strict version pinning. This package will only work with urllib3 v1.26.20 and will cause dependency conflicts if urllib3 v2 is present.

- **dep-bad-upper-bound**: Demonstrates issues with loose version constraints:
  - v0.1.0 uses `>=1.0.0` which might incorrectly allow urllib3 v2
  - v0.2.0 uses `~=1.0` which properly constrains to urllib3 v1.x but will break with v2

## Version summary

| Package             | Version | Dependencies         | Notes                                                                     |
| ------------------- | ------- | -------------------- | ------------------------------------------------------------------------- |
| dep-plain           | 0.1.0   | none                 | Simple package with no dependencies                                       |
| dep-plain           | 0.2.0   | none                 | Minor version bump, same otherwise                                        |
| dep-plain           | 1.0.0   | none                 | Major version bump, same otherwise                                        |
| dep-urllib3         | 1.26.20 | none                 | Contains hello() and hello_v1() function. Raises if hello_v2() is called  |
| dep-urllib3         | 2.3.0   | none                 | Contains hello() and hello_v2() function. Raises if hello_v1() is called  |
| dep-old             | 0.1.0   | dep-urllib3==1.26.20 | Strictly requires urllib3 v1.26.20                                        |
| dep-bad-upper-bound | 0.1.0   | dep-urllib3>=1.0.0   | Allows any urllib3 version ≥1.0.0 (but breaks if urllib3 v2 is installed) |
| dep-bad-upper-bound | 0.2.0   | dep-urllib3~=1.0     | Fixes the upper bound to only allow v1.x versions of urllib3              |

# Scenarios

## Scenario 1 - Package Updates and Metadata (pip)

`make scenario1`

This scenario demonstrates how pip handles package updates and the importance of the `.dist-info` directory:

1. First installs `dep-plain 0.1.0`, then updates to a newer version when requested
2. Shows that deleting the `.dist-info` directory has interesting consequences:
   - Python can still import and use the package (since the code is still there)
   - Pip loses track of what's installed (since it uses `.dist-info` to track installations)
   - On next install, pip will reinstall the package since it can't find the `.dist-info`

## Scenario 1a - Package Updates and Metadata (conda)

`make scenario1a`

The conda version of scenario 1 highlights key differences in how conda tracks packages:

1. Similar to pip, installs and updates `dep-plain` as requested
2. Unlike pip, conda won't reinstall a package just because `.dist-info` is missing
3. Shows that conda uses its own metadata tracking in `conda-meta/*.json`:
   - Deleting the conda-meta json file makes conda "forget" about the package
   - Only then will conda reinstall the package

## Scenario 2 - Dependency Conflicts (pip)

`make scenario2`

Demonstrates pip's behavior with conflicting dependencies:

1. Attempts to install `dep-old` (requires urllib3 v1) and `dep-urllib3 v2` simultaneously
   - This fails due to the version conflict
2. Shows that order matters:
   - Installing `dep-urllib3 v2` first, then `dep-old`
   - Pip will downgrade urllib3 to v1 to satisfy `dep-old`'s requirements
   - This might be surprising since it modifies a previously installed package

## Scenario 2a - Dependency Conflicts (conda)

`make scenario2a`

Shows how conda handles the same conflict differently:

1. Like pip, fails to install conflicting packages simultaneously
2. Unlike pip, conda is more conservative:
   - When `dep-urllib3 v2` is installed first
   - Conda refuses to downgrade it to satisfy `dep-old`
   - This protects explicitly installed packages from automatic downgrades

## Scenario 3 - Dependency Specification Issues (pip)

`make scenario3`

Explores how pip handles packages with imprecise dependency specifications:

1. Installs both `dep-bad-upper-bound` and `dep-urllib3 v2`
2. Shows that even though the package specifies `urllib3>=1.0.0`:
   - The package might not actually work with urllib3 v2
   - Demonstrates why careful version constraints are important

## Scenario 3a - Dependency Specification Issues (conda)

`make scenario3a`

The conda version of the dependency specification test:

1. Similar to pip's behavior in this case
2. Shows that both package managers will allow potentially problematic installations
   when version constraints are too loose

## Scenario 3b - Dependency Hotfixes (conda)

`make scenario3b`

Demonstrates conda's repodata hotfix functionality:

1. Similar to scenario 3a, but uses a conda channel with dependency hotfixes
2. Shows how conda can retroactively fix dependency issues:
   - The hotfix updates the metadata for `dep-bad-upper-bound`
   - Prevents installation with incompatible urllib3 v2
   - Demonstrates conda's ability to patch package metadata without rebuilding packages

## Scenario 4 - Dependency Metadata Manipulation (pip)

`make scenario4`

A deep dive into how pip uses package metadata:

1. First installs `dep-old` which requires urllib3 v1
2. Demonstrates that pip reads dependency requirements from `.dist-info/METADATA`
3. Shows that modifying the METADATA file can trick pip:
   - Changes the urllib3 requirement to `>=1.0.0`
   - Allows installation of urllib3 v2
   - Highlights pip's reliance on package metadata for dependency resolution

## Scenario 4a - Dependency Metadata Manipulation (conda)

`make scenario4a`

Contrasts conda's behavior with the same metadata manipulation:

1. Shows that conda ignores the `.dist-info/METADATA` file
2. Demonstrates that conda uses its own metadata system:
   - Modifying pip's metadata has no effect
   - Conda continues to enforce the original constraints
   - Highlights the more robust nature of conda's package tracking

## Scenario 5 - Conda then Pip Installation

`make scenario5`

Demonstrates how pip interacts with conda-installed packages:

1. First installs `dep-plain` using conda
2. Then attempts to install the same package using pip
3. Shows that pip:
   - Detects the existing conda installation
   - Recognizes the package is already present
   - No-ops instead of reinstalling

## Scenario 5a - Pip then Conda Installation

`make scenario5a`

Shows how conda handles pip-installed packages:

1. First installs `dep-plain` using pip
2. Then attempts to install using conda
3. Demonstrates that conda:
   - Ignores the pip-installed package
   - Installs its own version over it
   - Takes precedence over the pip installation
   - Highlights the potential for conflicts when mixing package managers

## Scenario 5b - Conda and pip interoperability visibility

`make scenario5b`

This scenario demonstrates how conda interacts with pip-installed packages in an environment:

1. Installs `dep-plain` using pip in a fresh conda environment
2. Shows that `conda list` (by default) displays pip-installed packages
3. Shows that `conda list --no-pip` hides pip-installed packages from the output
4. Demonstrates that removing the `.dist-info` directory causes conda to no longer see the pip package

This highlights the interoperability between conda and pip, and how conda tracks (or loses track of) pip-installed packages depending on metadata and command-line flags.

## Scenario 6 - Package Manager Conflicts

`make scenario6`

Demonstrates potential issues when mixing pip and conda package installations:

1. First installs `dep-old` using pip (which requires urllib3 v1)
2. Then installs urllib3 v2 using conda
3. Shows how mixing package managers can break dependencies:
   - Conda ignores pip's dependency requirements
   - Conda installs urllib3 v2 despite pip package needing v1
   - Results in runtime errors when `dep-old` tries to use urllib3
   - Highlights why it's best to stick to one package manager

## Scenario 7 - Hotfix Bypass with Pip

`make scenario7`

Shows how using pip after conda can bypass dependency hotfixes:

1. First installs `dep-bad-upper-bound` using conda with hotfixes
2. Then attempts to install urllib3 v2 using pip
3. Demonstrates a serious limitation:
   - Conda's hotfixes only work for conda operations
   - Pip still uses the original `.dist-info` metadata
   - Allows installation of incompatible urllib3 v2
   - Shows another way mixing package managers can break dependencies

# How it works: Pip/Pypi

## Creating a PyPI server

We don't actually want to upload these toy packages to a real PyPI server, so we implement a [PEP-691](https://peps.python.org/pep-0691/) HTTP rest server. This server has three endpoints:

1. GET `/` which returns a list of all projects (e.g.)

```json
{
  "meta": {
    "api_version": "1.0"
  },
  "projects": [
    {
      "name": "dep-bad-upper-bound"
    },
    {
      "name": "dep-bad-upper-bound"
    },
    {
      "name": "dep-urllib3"
    },
    {
      "name": "dep-urllib3"
    },
    {
      "name": "dep-plain"
    },
    {
      "name": "dep-plain"
    },
    {
      "name": "dep-plain"
    },
    {
      "name": "dep-old"
    }
  ]
}
```

1. GET `/<project>` which returns a list of files, pointing to each wheel:

```json
{
  "meta": {
    "api_version": "1.0"
  },
  "name": "dep-plain",
  "versions": ["1.0.0", "0.2.0", "0.1.0"],
  "files": [
    {
      "filename": "dep_plain-0.1.0-py3-none-any.whl",
      "url": "/dep-plain/dep_plain-0.1.0-py3-none-any.whl",
      "hashes": {
        "sha256": "c3503d661aa1cc069ad5b02876c18a081d6d783598e053dfe6cd1684313b84b2"
      },
      "provenance": null,
      "requires_python": null,
      "core_metadata": false,
      "size": null,
      "yanked": null,
      "upload_time": null
    },
    {
      "filename": "dep_plain-0.2.0-py3-none-any.whl",
      "url": "/dep-plain/dep_plain-0.2.0-py3-none-any.whl",
      "hashes": {
        "sha256": "ede3eafd8a662a0274dce36c52bb7e6b23889608b1b87874f46eb123cd3d4352"
      },
      "provenance": null,
      "requires_python": null,
      "core_metadata": false,
      "size": null,
      "yanked": null,
      "upload_time": null
    },
    {
      "filename": "dep_plain-1.0.0-py3-none-any.whl",
      "url": "/dep-plain/dep_plain-1.0.0-py3-none-any.whl",
      "hashes": {
        "sha256": "018ed1c86e90c0abe1cd2e7fd7da76a901e89412d594b06476d3f4eb632aac2d"
      },
      "provenance": null,
      "requires_python": null,
      "core_metadata": false,
      "size": null,
      "yanked": null,
      "upload_time": null
    }
  ]
}
```

3. GET `/<project>/<wheel_name>.whl` which returns the corresponding wheel listed in the `/<project>` endpoint.

The implementation of the server is pretty simple (and very unoptimized). For each request, we search for every wheel `wheels = current_dir.glob("dep-*/**/*.whl")` that is present in the directory. Then, the API builds up the correct response from the wheels present

## Getting pip to use the server

To get pip to use the server, we can use the `--index-url` flag to point to the server. For example,

```sh
pip install --index-url http://localhost:8000 dep-plain
```

# How it works: Conda

In order to install conda packages, you need a conda channel. A minimal conda channel consists of a `repodata.json` and the corresponding conda packages. Unlike pip, conda allows you to point at a local directory which has the appropriate structure.

## Generating the conda packages

We use [conda-pupa](https://dholth.github.io/conda-pupa/) to generate conda packages. When run, `conda-pupa` will output the corresponding `.conda` file to our specified `./conda-packages/noarch` directory. Then, we need to generate the repodata.json (and other misc. files). This is accomplished by running `conda index` in the `./conda-packages` directory.

## Getting conda to use the server

To get conda to use the server, we can use the `--channel` flag to point to the server. For example,

```sh
conda install --channel file://$(PWD)/conda-packages dep-plain
```
