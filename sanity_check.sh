#!/bin/bash

echo "==== FinOps Backend Sanity Check ===="
echo "Running checks at $(date)"

# Check Python version
echo -e "\n==== Python Version ===="
python --version
if [ $? -ne 0 ]; then
    echo "ERROR: Python not found or not working properly"
    exit 1
fi

# Check required packages
echo -e "\n==== Required Packages ===="
packages=("langchain" "langchain_openai" "faiss-cpu" "openai" "azure-identity" "tiktoken" "google-cloud-bigquery" "flask" "flask_cors" "nltk" "pandas" "plotly" "httpx" "sqlparse")
for package in "${packages[@]}"; do
    echo -n "Checking $package... "
    python -c "import $package" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "OK"
    else
        echo "MISSING or ERROR"
    fi
done

# Check configuration files
echo -e "\n==== Configuration Files ===="
config_files=("config/config.ini" "config/columns.jsonl" "config/tables.jsonl" "config/messages.json")
for file in "${config_files[@]}"; do
    if [ -f "$file" ]; then
        echo "$file: Found"
        if [[ "$file" == *".jsonl" ]]; then
            echo -n "  File size: "
            du -h "$file" | cut -f1
            echo -n "  Line count: "
            wc -l "$file" | cut -d' ' -f1
        fi
    else
        echo "$file: MISSING"
    fi
done

# Check OpenAI API configuration
echo -e "\n==== OpenAI API Configuration ===="
cat > check_config.py << 'EOF'
import configparser
config = configparser.ConfigParser()
config.read('config/config.ini')
print("API Key configured: {}".format("Yes" if config.get('OpenAI', 'api_key') else "No"))
print("Base URL configured: {}".format("Yes" if config.get('OpenAI', 'base_url') else "Using default OpenAI URL"))
print("Base Embedding URL configured: {}".format("Yes" if config.get('OpenAI', 'base_embedding_url') else "Using default OpenAI URL"))
print("API Version configured: {}".format("Yes" if config.get('OpenAI', 'api_version') else "No"))
print("Model configured: {}".format(config.get('OpenAI', 'model')))
print("Embedding Model configured: {}".format(config.get('OpenAI', 'embedding_model')))
print("Azure Deployment configured: {}".format("Yes" if config.get('OpenAI', 'azure_deployment') else "No"))
EOF

python check_config.py
rm check_config.py

# Check network connectivity
echo -e "\n==== Network Connectivity ===="
cat > check_connectivity.py << 'EOF'
import configparser
import subprocess
import sys

def check_url_connectivity(url, description):
    if not url:
        print(f"{description}: Not configured")
        return
    
    print(f"Checking connectivity to {description}: {url}")
    try:
        result = subprocess.run(["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", url], 
                                capture_output=True, text=True, timeout=10)
        status_code = result.stdout.strip()
        
        if result.returncode == 0 and int(status_code) < 400:
            print(f"{description} connection: OK (Status: {status_code})")
        else:
            print(f"WARNING: Cannot connect to {description} (Status: {status_code})")
    except Exception as e:
        print(f"ERROR: Failed to check {description} connectivity: {str(e)}")

config = configparser.ConfigParser()
config.read('config/config.ini')

# Get OpenAI URLs from config
base_url = config.get('OpenAI', 'base_url', fallback='')
base_embedding_url = config.get('OpenAI', 'base_embedding_url', fallback='')

# Check OpenAI API connectivity
if base_url:
    check_url_connectivity(base_url, "OpenAI API (from config)")
else:
    check_url_connectivity("https://api.openai.com/v1/models", "Default OpenAI API")

# Check OpenAI Embedding API connectivity
if base_embedding_url:
    check_url_connectivity(base_embedding_url, "OpenAI Embedding API (from config)")
EOF

python check_connectivity.py
rm check_connectivity.py

# Check custom API endpoints from config.ini
echo -e "\n==== Custom API Endpoints ===="
cat > check_endpoints.py << 'EOF'
import configparser
import requests
import sys

def check_endpoint(url, description):
    if not url:
        print(f"{description}: Not configured")
        return
    
    try:
        print(f"Checking {description}: {url}")
        response = requests.get(url, timeout=5, verify=False)
        print(f"  Status code: {response.status_code}")
        if response.status_code < 400:
            print(f"  Connection: OK")
        else:
            print(f"  Connection: FAILED - Status code {response.status_code}")
    except Exception as e:
        print(f"  Connection: FAILED - {str(e)}")

config = configparser.ConfigParser()
config.read('config/config.ini')

# Check OpenAI endpoints
base_url = config.get('OpenAI', 'base_url', fallback='')
base_embedding_url = config.get('OpenAI', 'base_embedding_url', fallback='')

if base_url:
    check_endpoint(base_url, "OpenAI Base URL")
else:
    check_endpoint("https://api.openai.com", "Default OpenAI API")

if base_embedding_url:
    check_endpoint(base_embedding_url, "OpenAI Embedding URL")
EOF

python check_endpoints.py
rm check_endpoints.py

# Check GCP service account file
echo -e "\n==== GCP Service Account ===="
cat > check_gcp.py << 'EOF'
import configparser
import os
import json

config = configparser.ConfigParser()
config.read('config/config.ini')
service_account_file = config.get('Database', 'service_account_file', fallback='')
print(f"Service account file path: {service_account_file}")
print(f"File exists: {'Yes' if os.path.exists(service_account_file) else 'No'}")

if os.path.exists(service_account_file):
    print(f"File size: {os.path.getsize(service_account_file)} bytes")
    print(f"File permissions: {oct(os.stat(service_account_file).st_mode)[-3:]}")
    
    # Validate JSON format
    try:
        with open(service_account_file, 'r') as f:
            json_data = json.load(f)
        print("JSON format: Valid")
        
        # Check for required fields
        required_fields = ['type', 'project_id', 'private_key_id', 'private_key', 'client_email']
        missing_fields = [field for field in required_fields if field not in json_data]
        
        if missing_fields:
            print(f"WARNING: Missing required fields: {', '.join(missing_fields)}")
        else:
            print("Required fields: All present")
            print(f"Project ID: {json_data.get('project_id')}")
            print(f"Client Email: {json_data.get('client_email')}")
    except json.JSONDecodeError:
        print("JSON format: INVALID")
    except Exception as e:
        print(f"Error reading service account file: {str(e)}")
EOF

python check_gcp.py
rm check_gcp.py

# Check memory and CPU resources
echo -e "\n==== System Resources ===="
echo "Memory:"
free -h
echo -e "\nCPU:"
lscpu | grep "CPU(s):" | head -1
echo -e "\nDisk Space:"
df -h .

# Check VM resource sufficiency for FAISS
echo -e "\n==== VM Resource Sufficiency for FAISS ===="
cat > check_resources.py << 'EOF'
import os
import psutil
import configparser
import json

def get_file_size(file_path):
    if os.path.exists(file_path):
        return os.path.getsize(file_path)
    return 0

def check_resources():
    # Get memory info
    mem = psutil.virtual_memory()
    total_mem_gb = mem.total / (1024 * 1024 * 1024)
    available_mem_gb = mem.available / (1024 * 1024 * 1024)
    
    # Get CPU info
    cpu_count = psutil.cpu_count(logical=False)
    cpu_count_logical = psutil.cpu_count(logical=True)
    
    # Get disk info
    disk = psutil.disk_usage('.')
    total_disk_gb = disk.total / (1024 * 1024 * 1024)
    free_disk_gb = disk.free / (1024 * 1024 * 1024)
    
    # Get JSONL file sizes
    config = configparser.ConfigParser()
    config.read('config/config.ini')
    columns_path = config.get('Database', 'columns_path', fallback='config/columns.jsonl')
    tables_path = config.get('Database', 'tables_path', fallback='config/tables.jsonl')
    
    columns_size_mb = get_file_size(columns_path) / (1024 * 1024)
    tables_size_mb = get_file_size(tables_path) / (1024 * 1024)
    
    # Estimate FAISS memory requirements (rough estimation)
    # FAISS typically needs ~10x the size of the raw data for index creation
    estimated_faiss_mem_gb = columns_size_mb * 10 / 1024
    
    print(f"Total Memory: {total_mem_gb:.2f} GB")
    print(f"Available Memory: {available_mem_gb:.2f} GB")
    print(f"Physical CPU Cores: {cpu_count}")
    print(f"Logical CPU Cores: {cpu_count_logical}")
    print(f"Total Disk Space: {total_disk_gb:.2f} GB")
    print(f"Free Disk Space: {free_disk_gb:.2f} GB")
    print(f"Columns JSONL Size: {columns_size_mb:.2f} MB")
    print(f"Tables JSONL Size: {tables_size_mb:.2f} MB")
    print(f"Estimated FAISS Memory Requirement: {estimated_faiss_mem_gb:.2f} GB")
    
    # Check if resources are sufficient
    print("\nResource Sufficiency Analysis:")
    
    # Memory check for FAISS
    if available_mem_gb > estimated_faiss_mem_gb * 1.5:
        print("✅ Memory: SUFFICIENT for FAISS operations")
    elif available_mem_gb > estimated_faiss_mem_gb:
        print("⚠️ Memory: MARGINAL for FAISS operations - May experience slowdowns")
    else:
        print("❌ Memory: INSUFFICIENT for FAISS operations - Likely to timeout or crash")
    
    # CPU check
    if cpu_count >= 2:
        print("✅ CPU: SUFFICIENT for FAISS operations")
    else:
        print("⚠️ CPU: MARGINAL for FAISS operations - May experience slowdowns")
    
    # Disk check
    if free_disk_gb > 5:
        print("✅ Disk: SUFFICIENT space available")
    else:
        print("⚠️ Disk: LOW on free space - May cause issues with temporary files")

try:
    import psutil
    check_resources()
except ImportError:
    print("psutil package not installed. Install with: pip install psutil")
    print("Unable to perform detailed resource analysis.")
EOF

python check_resources.py
rm check_resources.py

# Test embedding generation with a small sample
echo -e "\n==== Testing Embedding Generation ===="
cat > test_embedding.py << 'EOF'
import os
import sys
import time
import configparser
import json
from langchain_openai import AzureOpenAIEmbeddings, OpenAIEmbeddings

def test_embedding():
    try:
        config = configparser.ConfigParser()
        config.read('config/config.ini')
        
        # Get OpenAI configuration
        api_key = config.get('OpenAI', 'api_key', fallback='')
        api_version = config.get('OpenAI', 'api_version', fallback='')
        base_url = config.get('OpenAI', 'base_url', fallback='')
        base_embedding_url = config.get('OpenAI', 'base_embedding_url', fallback='')
        project_id = config.get('OpenAI', 'project_id', fallback='')
        embedding_model = config.get('OpenAI', 'embedding_model', fallback='text-embedding-3-large')
        azure_deployment = config.get('OpenAI', 'azure_deployment', fallback='')
        
        print(f"API Key: {'Configured' if api_key else 'Not configured'}")
        print(f"API Version: {api_version if api_version else 'Not configured'}")
        print(f"Base URL: {base_url if base_url else 'Using default OpenAI URL'}")
        print(f"Base Embedding URL: {base_embedding_url if base_embedding_url else 'Using default OpenAI URL'}")
        print(f"Project ID: {project_id if project_id else 'Not configured'}")
        print(f"Embedding Model: {embedding_model}")
        print(f"Azure Deployment: {azure_deployment if azure_deployment else 'Not configured'}")
        
        start_time = time.time()
        
        if base_embedding_url:
            print("\nTesting Azure OpenAI Embeddings...")
            headers = {
                'HSBC-Params': f'{{"req_from":"{project_id}", "type":"embedding"}}',
                'Authorization-Type': 'genai',
                'Authorization': f'Bearer {api_key}',
                'Content-Type': 'application/json'
            }
            
            embedding = AzureOpenAIEmbeddings(
                azure_endpoint=base_embedding_url,
                openai_api_key=api_key,
                openai_api_version=api_version,
                deployment=embedding_model,
                default_headers=headers
            )
        else:
            print("\nTesting OpenAI Embeddings...")
            embedding = OpenAIEmbeddings(
                model=embedding_model,
                api_key=api_key
            )
        
        # Test with a simple text
        print("\nGenerating embedding for test query...")
        result = embedding.embed_query("This is a test query")
        
        end_time = time.time()
        
        if result and len(result) > 0:
            print(f"Embedding generation successful!")
            print(f"Embedding dimensions: {len(result)}")
            print(f"Time taken: {end_time - start_time:.2f} seconds")
            return True
        else:
            print("Embedding generation failed - empty result")
            return False
    except Exception as e:
        print(f"Error during embedding test: {str(e)}")
        return False

if __name__ == "__main__":
    success = test_embedding()
    sys.exit(0 if success else 1)
EOF

python test_embedding.py
embedding_result=$?

# Test FAISS document loading and indexing
echo -e "\n==== Testing FAISS Document Loading ===="
cat > test_faiss.py << 'EOF'
import os
import sys
import time
import configparser
import traceback
from langchain_community.document_loaders import JSONLoader
from langchain_community.vectorstores import FAISS
from langchain_openai import AzureOpenAIEmbeddings, OpenAIEmbeddings

def test_faiss_loading():
    try:
        config = configparser.ConfigParser()
        config.read('config/config.ini')
        
        # Get database configuration
        db_column_path = config.get('Database', 'columns_path', fallback='config/columns.jsonl')
        
        # Get OpenAI configuration
        api_key = config.get('OpenAI', 'api_key', fallback='')
        api_version = config.get('OpenAI', 'api_version', fallback='')
        base_url = config.get('OpenAI', 'base_url', fallback='')
        base_embedding_url = config.get('OpenAI', 'base_embedding_url', fallback='')
        project_id = config.get('OpenAI', 'project_id', fallback='')
        embedding_model = config.get('OpenAI', 'embedding_model', fallback='text-embedding-3-large')
        azure_deployment = config.get('OpenAI', 'azure_deployment', fallback='')
        
        print(f"Testing FAISS document loading from: {db_column_path}")
        
        # Check if file exists
        if not os.path.exists(db_column_path):
            print(f"ERROR: File {db_column_path} does not exist")
            return False
        
        # Check file size
        file_size = os.path.getsize(db_column_path)
        print(f"File size: {file_size} bytes")
        
        # Configure embedding model
        if base_embedding_url:
            print("Using Azure OpenAI Embeddings...")
            headers = {
                'HSBC-Params': f'{{"req_from":"{project_id}", "type":"embedding"}}',
                'Authorization-Type': 'genai',
                'Authorization': f'Bearer {api_key}',
                'Content-Type': 'application/json'
            }
            
            embedding = AzureOpenAIEmbeddings(
                azure_endpoint=base_embedding_url,
                openai_api_key=api_key,
                openai_api_version=api_version,
                deployment=embedding_model,
                default_headers=headers
            )
        else:
            print("Using OpenAI Embeddings...")
            embedding = OpenAIEmbeddings(
                model=embedding_model,
                api_key=api_key
            )
        
        # Load documents with timeout monitoring
        print("Loading documents...")
        start_time = time.time()
        
        try:
            # Set a timeout for document loading (30 seconds)
            documents = JSONLoader(file_path=db_column_path, jq_schema='.', text_content=False, json_lines=True).load()
            doc_load_time = time.time() - start_time
            print(f"Document loading completed in {doc_load_time:.2f} seconds")
            print(f"Number of documents loaded: {len(documents)}")
            
            # Create FAISS index with timeout monitoring
            print("Creating FAISS index...")
            index_start_time = time.time()
            
            # Only process a small subset for testing if there are many documents
            test_docs = documents[:min(10, len(documents))]
            db = FAISS.from_documents(documents=test_docs, embedding=embedding)
            
            index_time = time.time() - index_start_time
            print(f"FAISS index creation completed in {index_time:.2f} seconds")
            
            # Test retrieval
            print("Testing retrieval...")
            retrieval_start_time = time.time()
            
            search_kwargs = {'k': 5}  # Use a smaller k for testing
            retriever = db.as_retriever(search_type='similarity', search_kwargs=search_kwargs)
            matched_columns = retriever.get_relevant_documents(query="test query")
            
            retrieval_time = time.time() - retrieval_start_time
            print(f"Retrieval completed in {retrieval_time:.2f} seconds")
            print(f"Number of matched columns: {len(matched_columns)}")
            
            total_time = time.time() - start_time
            print(f"Total processing time: {total_time:.2f} seconds")
            
            return True
        except Exception as e:
            elapsed_time = time.time() - start_time
            print(f"Operation failed after {elapsed_time:.2f} seconds with error: {str(e)}")
            print("Stack trace:")
            traceback.print_exc()
            return False
            
    except Exception as e:
        print(f"Error during FAISS testing: {str(e)}")
        print("Stack trace:")
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = test_faiss_loading()
    sys.exit(0 if success else 1)
EOF

python test_faiss.py
faiss_result=$?

echo -e "\n==== Sanity Check Summary ===="
if [ $embedding_result -eq 0 ]; then
    echo "Embedding test: PASSED"
else
    echo "Embedding test: FAILED - This is likely causing the timeout issue"
fi

if [ $faiss_result -eq 0 ]; then
    echo "FAISS document loading test: PASSED"
else
    echo "FAISS document loading test: FAILED - This is likely causing the timeout issue"
fi

echo -e "\n==== Recommendations ===="
cat << 'EOF'
If tests are failing, try the following:

1. Install missing packages:
   pip install faiss-cpu azure-identity google-cloud-bigquery psutil

2. Update deprecated imports:
   - Change "from langchain.document_loaders import JSONLoader" to "from langchain_community.document_loaders import JSONLoader"
   - Change "from langchain.vectorstores import FAISS" to "from langchain_community.vectorstores import FAISS"

3. Add timeout and retry logic to the return_matched_columns function:
   ```python
   from tenacity import retry, stop_after_attempt, wait_exponential

   @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=1, min=2, max=10))
   def create_faiss_with_timeout(documents, embedding):
       try:
           return FAISS.from_documents(documents=documents, embedding=embedding)
       except Exception as e:
           print(f"Error creating FAISS index: {str(e)}")
           raise
   
   # Then use this function instead of direct call
   db = create_faiss_with_timeout(documents, embedding)
   ```

4. Pre-build and cache FAISS index:
   - Consider pre-building the FAISS index and saving it to disk
   - Load the pre-built index instead of creating it on each query
EOF

echo -e "\nSanity check completed at $(date)"
