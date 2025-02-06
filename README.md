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

## Scenario 1 Conda - Package Updates and Metadata (conda)

`make scenario1conda`

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

## Scenario 2 Conda - Dependency Conflicts (conda)

`make scenario2conda`

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

## Scenario 3 Conda - Dependency Specification Issues (conda)

`make scenario3conda`

The conda version of the dependency specification test:

1. Similar to pip's behavior in this case
2. Shows that both package managers will allow potentially problematic installations
   when version constraints are too loose

## Scenario 4 - Dependency Metadata Manipulation (pip)

`make scenario4`

A deep dive into how pip uses package metadata:

1. First installs `dep-old` which requires urllib3 v1
2. Demonstrates that pip reads dependency requirements from `.dist-info/METADATA`
3. Shows that modifying the METADATA file can trick pip:
   - Changes the urllib3 requirement to `>=1.0.0`
   - Allows installation of urllib3 v2
   - Highlights pip's reliance on package metadata for dependency resolution

## Scenario 4 Conda - Dependency Metadata Manipulation (conda)

`make scenario4conda`

Contrasts conda's behavior with the same metadata manipulation:

1. Shows that conda ignores the `.dist-info/METADATA` file
2. Demonstrates that conda uses its own metadata system:
   - Modifying pip's metadata has no effect
   - Conda continues to enforce the original constraints
   - Highlights the more robust nature of conda's package tracking
