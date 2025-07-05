#!/bin/bash

# Script to test all prompts from prompts.txt through the API endpoints
# The sequence is:
# 1. Execute /generate_query with query from prompts.txt
# 2. If successful, execute /api/cost/estimate with the query from first response
# 3. If successful, execute /generate_insights_from_query with the query from first response

# Set the base URL - update this if needed
BASE_URL="http://localhost:5000"
LOG_FILE="test_prompts_results.log"

# Clear the log file
echo "Starting API tests at $(date)" > $LOG_FILE
echo "----------------------------------------" >> $LOG_FILE

# Function to make API calls and process responses
test_prompt() {
    local prompt="$1"
    local prompt_num="$2"
    
    echo "----------------------------------------" >> $LOG_FILE
    echo "Testing Prompt #$prompt_num: '$prompt'" >> $LOG_FILE
    echo "----------------------------------------" >> $LOG_FILE
    
    # Step 1: Call /generate_query endpoint
    echo "[Step 1] Calling /generate_query with prompt: '$prompt'" >> $LOG_FILE
    
    # Use curl to make the API call and capture the response
    GENERATE_QUERY_RESPONSE=$(curl -s -X POST "$BASE_URL/generate_query" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$prompt\", \"llm_type\": \"openai\"}")
    
    # Check if the call was successful
    HTTP_STATUS=$(echo "$GENERATE_QUERY_RESPONSE" | grep -o '"status": [0-9]*' | awk '{print $2}')
    
    # Extract the SQL query from the response
    SQL_QUERY=$(echo "$GENERATE_QUERY_RESPONSE" | grep -o '"sql_query_generated": "[^"]*"' | sed 's/"sql_query_generated": "\(.*\)"/\1/')
    
    echo "Response from /generate_query:" >> $LOG_FILE
    echo "$GENERATE_QUERY_RESPONSE" >> $LOG_FILE
    
    # If SQL_QUERY is empty or contains "Exception", consider it a failure
    if [[ -z "$SQL_QUERY" || "$SQL_QUERY" == *"Exception"* ]]; then
        echo "[ERROR] Failed to generate SQL query for prompt: '$prompt'" >> $LOG_FILE
        echo "Moving to next prompt..." >> $LOG_FILE
        return
    fi
    
    echo "[SUCCESS] Generated SQL query: $SQL_QUERY" >> $LOG_FILE
    
    # Step 2: Call /api/cost/estimate endpoint
    echo "" >> $LOG_FILE
    echo "[Step 2] Calling /api/cost/estimate with the generated SQL query" >> $LOG_FILE
    
    COST_ESTIMATE_RESPONSE=$(curl -s -X POST "$BASE_URL/api/cost/estimate" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$SQL_QUERY\"}")
    
    echo "Response from /api/cost/estimate:" >> $LOG_FILE
    echo "$COST_ESTIMATE_RESPONSE" >> $LOG_FILE
    
    # Check if the cost estimate call was successful
    if [[ "$COST_ESTIMATE_RESPONSE" == *"error"* ]]; then
        echo "[ERROR] Failed to estimate cost for the SQL query" >> $LOG_FILE
        echo "Moving to next prompt..." >> $LOG_FILE
        return
    fi
    
    echo "[SUCCESS] Cost estimate retrieved successfully" >> $LOG_FILE
    
    # Step 3: Call /generate_insights_from_query endpoint
    echo "" >> $LOG_FILE
    echo "[Step 3] Calling /generate_insights_from_query with the generated SQL query" >> $LOG_FILE
    
    INSIGHTS_RESPONSE=$(curl -s -X POST "$BASE_URL/generate_insights_from_query" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$SQL_QUERY\", \"llm_type\": \"openai\"}")
    
    echo "Response from /generate_insights_from_query:" >> $LOG_FILE
    echo "$INSIGHTS_RESPONSE" >> $LOG_FILE
    
    # Check if the insights call was successful
    if [[ "$INSIGHTS_RESPONSE" == *"error"* || "$INSIGHTS_RESPONSE" == *"Sorry"* ]]; then
        echo "[ERROR] Failed to generate insights for the SQL query" >> $LOG_FILE
    else
        echo "[SUCCESS] Insights generated successfully" >> $LOG_FILE
    fi
    
    echo "" >> $LOG_FILE
    echo "Completed testing prompt #$prompt_num" >> $LOG_FILE
    echo "----------------------------------------" >> $LOG_FILE
}

# Read prompts from file and test each one
prompt_num=1
while IFS= read -r prompt || [[ -n "$prompt" ]]; do
    # Skip empty lines
    if [[ -z "$prompt" ]]; then
        continue
    fi
    
    # Test the current prompt
    test_prompt "$prompt" "$prompt_num"
    
    # Increment prompt counter
    ((prompt_num++))
    
    # Add a small delay between requests to avoid overwhelming the server
    sleep 2
done < "prompts.txt"

echo "----------------------------------------" >> $LOG_FILE
echo "Testing completed at $(date)" >> $LOG_FILE
echo "Results saved to $LOG_FILE"

# Print a summary
echo "----------------------------------------"
echo "Testing completed. Results saved to $LOG_FILE"
echo "Total prompts tested: $((prompt_num-1))"
echo "----------------------------------------"
