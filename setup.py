from setuptools import setup, find_packages

# Read dependencies from requirements.txt
with open("requirements.txt") as f:
    requirements = f.read().splitlines()

setup(
    name="finops_backend",
    version="1.0.30",
    packages=find_packages(where="src"),  # Ensure it picks up your source files
    package_dir={"": "src"},
    install_requires=requirements,  # Include all dependencies from requirements.txt
    entry_points={
        "console_scripts": [
            "finops_backend=finops_backend.app:main",  # Allow running with `finops_backend` command
        ]
    },
    include_package_data=False,  # Exclude config files from the package
)
