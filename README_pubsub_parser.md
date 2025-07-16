# Pub/Sub Log Parser

## Installation

```bash
pip install -r requirements.txt
```

## Usage

### Basic usage with service account key
```bash
python pubsub_log_parser.py PROJECT_ID SUBSCRIPTION_NAME --credentials path/to/service-account-key.json
```

### Using the Terraform-generated service account
```bash
# If you used the Terraform config, the key file will be named: {project_id}-sa-log-key.json
python pubsub_log_parser.py win-windata-0-sbx win-windata-0-sbx-logs-sub --credentials win-windata-0-sbx-sa-log-key.json
```

### Advanced usage
```bash
python pubsub_log_parser.py PROJECT_ID SUBSCRIPTION_NAME \
  --output my_logs.csv \
  --max-messages 500 \
  --timeout 60 \
  --credentials path/to/key.json
```

## Output

The script creates a CSV file with the following columns:
- insertId: Unique identifier for the log entry
- timestamp: When the logged event occurred
- receiveTimestamp: When the log was received
- severity: Log severity level
- logName: Name of the log
- resource_type: Type of resource (e.g., gcs_bucket)
- resource_project_id: Project ID of the resource
- resource_bucket_name: Bucket name (if applicable)
- resource_location: Resource location
- principal_email: Email of the user who performed the action
- method_name: API method called
- service_name: GCP service name
- caller_ip: IP address of the caller
- user_agent: User agent string
- permission: Permission being checked
- permission_granted: Whether permission was granted
- status_code: HTTP status code
- auth_type: Authentication type

## Authentication

The script supports several authentication methods:
1. Service account key file (recommended for this use case)
2. Application Default Credentials (ADC)
3. Environment variable GOOGLE_APPLICATION_CREDENTIALS

## Examples

### Using with Terraform-generated resources
```bash
# Pull 50 messages and save to custom file
python pubsub_log_parser.py win-windata-0-sbx win-windata-0-sbx-logs-sub \
  --credentials win-windata-0-sbx-sa-log-key.json \
  --output storage_audit_logs.csv \
  --max-messages 50
```

### Continuous monitoring
```bash
# Run in a loop to continuously pull messages
while true; do
  python pubsub_log_parser.py PROJECT_ID SUBSCRIPTION_NAME \
    --credentials key.json \
    --output logs_$(date +%Y%m%d_%H%M%S).csv \
    --max-messages 100
  sleep 300  # Wait 5 minutes
done
```
