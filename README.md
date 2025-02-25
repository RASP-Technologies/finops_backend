# Run finops_backend using whl file

## Pre-requisite

### Step 1
In the working directory create the following files in `config` folder and replace the values appropriately

```
config.ini
tables_bank.jsonl
columns_bank.jsonl
messages.json
```

### Step 2

Download the whl file from `dist/' directory

Latest whl file version = `finops_backend-1.0.6-py3-none-any.whl`

### Step 3

Create a virtual environment using the following command

` python -m venv venv `

Activate virtual environment

` source venv/bin/activate `

### Step 4

Install finops_backend using following command

` pip install dist/finops_backend-1.0.6-py3-none-any.whl `

### Step 5

Once the installation is complete you can execute the following command to start finops_backend

` finops_backend `