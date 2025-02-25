#!/bin/bash
rm -rf build dist finops_backend.egg-info  # Cleanup previous builds
python3 setup.py sdist bdist_wheel        # Build the wheel
