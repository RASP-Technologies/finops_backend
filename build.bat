@echo off
rmdir /s /q build dist finops_backend.egg-info
python setup.py sdist bdist_wheel
