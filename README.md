# GCP Resource Counter & Dynamic Filter Generator

A comprehensive toolset for auditing Google Cloud Platform (GCP) resources and generating dynamic log filters for monitoring and compliance.

All the scripts developed during the CNAM Mémoire implementation.

## 🔧 Tools Overview

### 1. `count_gcp_resources.sh`
A powerful bash script that scans GCP projects and provides detailed resource inventory across multiple services.

### 2. `generate_dynamic_filter.py`  
A Python tool that generates dynamic log filters based on detected GCP services for enhanced monitoring and audit capabilities.

## 📋 Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
  - [Resource Counting](#resource-counting)
  - [Filter Generation](#filter-generation)
- [Supported Services](#supported-services)
- [Examples](#examples)
- [Background Mode](#background-mode)
- [Output Format](#output-format)
- [Contributing](#contributing)
- [License](#license)

## ✨ Features

### Resource Counter (`count_gcp_resources.sh`)
- **Multi-mode scanning**: Single project or entire folder hierarchy
- **Comprehensive coverage**: 15+ GCP services and resource types
- **Background execution**: Detached mode for long-running scans
- **Detailed reporting**: Per-project breakdown and global summaries
- **Debug mode**: Enhanced logging for troubleshooting
- **Flexible input**: Auto-detection of project vs folder IDs

### Filter Generator (`generate_dynamic_filter.py`)
- **Dynamic filtering**: Generates service-specific log filters
- **Multiple output formats**: JSON configuration or raw filters
- **Comprehensive service support**: All services from resource counter
- **Audit-ready**: Pre-configured with security-focused actions
- **Configurable exclusions**: Built-in support for service account filtering

## 🔧 Prerequisites

### Required Tools
- **Google Cloud SDK** (`gcloud`)
- **BigQuery CLI** (`bq`)
- **Python 3.6+**
- **Bash 4.0+**

### GCP Permissions
The following IAM roles are required:
- `roles/browser` (for project discovery)
- `roles/viewer` (for resource counting)
- `roles/logging.viewer` (for filter generation)

### Authentication
```bash
# Authenticate with GCP
gcloud auth login

# Set default project (optional)
gcloud config set project YOUR_PROJECT_ID
```

## 📦 Installation

1. **Clone the repository**
```bash
git clone https://github.com/your-username/gcp-resource-tools.git
cd gcp-resource-tools
```

2. **Make scripts executable**
```bash
chmod +x count_gcp_resources.sh
chmod +x generate_dynamic_filter.py
```

3. **Verify prerequisites**
```bash
# Check gcloud installation
gcloud --version

# Check Python installation
python3 --version

# Test GCP authentication
gcloud auth list
```

## 🚀 Usage

### Resource Counting

#### Basic Usage
```bash
# Scan default folder
./count_gcp_resources.sh

# Scan specific folder
./count_gcp_resources.sh 123456789

# Scan single project
./count_gcp_resources.sh my-project-id

# Enable debug mode
./count_gcp_resources.sh my-project-id true

# Run in background
./count_gcp_resources.sh 123456789 false true
```

#### Advanced Usage
```bash
# Scan with debug and background mode
./count_gcp_resources.sh my-project-id true true

# Monitor background process
tail -f YYYYMMDD_HHMMSS_gcp_resource_summary.log

# Check background process status
ps -p $(cat YYYYMMDD_HHMMSS_gcp_resource_summary.log.pid)
```

### Filter Generation

#### Basic Usage
```bash
# Generate default filter
./generate_dynamic_filter.py my-project-id

# Generate service-specific filter
./generate_dynamic_filter.py my-project-id --services compute storage

# Show filter explanation
./generate_dynamic_filter.py my-project-id --services gke bigquery --explain

# Generate raw filter only
./generate_dynamic_filter.py my-project-id --services compute --filter-only
```

#### Advanced Usage
```bash
# Save configuration to file
./generate_dynamic_filter.py my-project-id --services compute storage gke --output config.json

# Generate filters for all services
./generate_dynamic_filter.py my-project-id --services compute storage gke cloudsql functions vertexai firestore bigquery cloudrun iam pubsub
```

## 🎯 Supported Services

| Service | Resource Counter | Filter Generator | Description |
|---------|:----------------:|:----------------:|-------------|
| **Compute Engine** | ✅ | ✅ | VMs, disks, networks |
| **Cloud Storage** | ✅ | ✅ | Storage buckets |
| **Google Kubernetes Engine** | ✅ | ✅ | Clusters, nodes, pods |
| **Cloud SQL** | ✅ | ✅ | Database instances |
| **Cloud Functions** | ✅ | ✅ | Serverless functions |
| **Cloud Run** | ✅ | ✅ | Container services |
| **IAM** | ✅ | ✅ | Service accounts |
| **Pub/Sub** | ✅ | ✅ | Topics and subscriptions |
| **Vertex AI** | ✅ | ✅ | ML platform |
| **Firestore** | ✅ | ✅ | NoSQL database |
| **BigQuery** | ✅ | ✅ | Data warehouse |
| **VPC Networks** | ✅ | ❌ | Virtual networks |
| **Firewall Rules** | ✅ | ❌ | Network security |

## 📝 Examples

### Example 1: Complete Resource Audit
```bash
# Scan entire organization folder
./count_gcp_resources.sh 123456789 true

# Expected output:
# 📊 SUMMARY
# 📁 Projects scanned:         25
# 💻 Total VMs:                157
# 🌐 Total VPCs:               89
# 📦 Total Storage Buckets:    234
# ...
```

### Example 2: Generate Monitoring Filters
```bash
# Detect services and generate filters
./generate_dynamic_filter.py my-project-id --services compute storage gke

# Output: JSON configuration with multiple filter types
{
  "description": "Configuration dynamique pour le projet my-project-id",
  "detected_services": ["compute", "storage", "gke"],
  "filters": {
    "dynamic": "((resource.type=\"gce_instance\"...))",
    "compute_only": "...",
    "storage_only": "...",
    "gke_only": "..."
  }
}
```

### Example 3: Background Processing
```bash
# Start long-running scan in background
./count_gcp_resources.sh 123456789 false true

# Monitor progress
tail -f 20250716_143022_gcp_resource_summary.log

# Check process status
ps -p $(cat 20250716_143022_gcp_resource_summary.log.pid)
```

## � Background Mode

The resource counter supports background execution for long-running scans:

### Features
- **Detached execution**: Continues running after terminal disconnect
- **Process management**: Automatic PID file creation
- **Progress monitoring**: Real-time log file updates
- **Clean termination**: Automatic cleanup on completion

### Usage
```bash
# Start background process
./count_gcp_resources.sh folder-id false true

# Monitor progress
tail -f [LOG_FILE]

# Stop process
kill $(cat [LOG_FILE].pid)
```

## 📊 Output Format

### Resource Counter Output
```
📊 SUMMARY
------------------------------
📁 Projects scanned:         15
⚠️  Projects with errors:     2
📈 TOTAL COUNTS BY RESOURCE TYPE
------------------------------
💻 Total VMs:                42
🌐 Total VPCs:               28
🧩 Total Subnetworks:        156
🔥 Total Firewall Rules:     89
📦 Total Storage Buckets:    67
🐳 Total GKE Clusters:       12
🗃️  Total SQL Instances:     8
⚙️  Total Cloud Functions:   23
☁️  Total Cloud Run Services: 15
🔐 Total IAM Service Accounts: 45
📢 Total Pub/Sub Topics:     34
📥 Total Pub/Sub Subscriptions: 67
🤖 Projects with Vertex AI:  5
📁 Projects with Firestore:  8
🔍 BigQuery Datasets:        12
```

### Filter Generator Output
```json
{
  "description": "Configuration dynamique pour le projet my-project",
  "project_id": "my-project",
  "detected_services": ["compute", "storage"],
  "filters": {
    "dynamic": "((resource.type=\"gce_instance\"...))",
    "compute_only": "...",
    "storage_only": "...",
    "default": "...",
    "warning_and_above": "...",
    "error_and_above": "..."
  }
}
```

## 🛠️ Configuration

### Environment Variables
```bash
# Optional: Set default folder ID
export GCP_DEFAULT_FOLDER_ID=123456789

# Optional: Set default timeout
export GCP_TIMEOUT=60
```

### Customization
- **Excluded principals**: Edit `excluded_principals` array in `generate_dynamic_filter.py`
- **Monitored actions**: Modify `allowed_actions` list for custom audit scope
- **Timeout values**: Adjust timeout settings in `count_gcp_resources.sh`

## 🐛 Troubleshooting

### Common Issues

1. **Permission denied errors**
   ```bash
   # Check authentication
   gcloud auth list
   
   # Verify project access
   gcloud projects describe PROJECT_ID
   ```

2. **Command timeouts**
   ```bash
   # Enable debug mode
   ./count_gcp_resources.sh PROJECT_ID true
   ```

3. **Filter generation issues**
   ```bash
   # Check service availability
   ./generate_dynamic_filter.py PROJECT_ID --explain
   ```

### Debug Mode
Enable debug mode for detailed logging:
```bash
./count_gcp_resources.sh PROJECT_ID true
```

## � Performance

### Resource Counter
- **Small projects** (< 10 resources): ~30 seconds
- **Medium projects** (10-100 resources): 1-3 minutes
- **Large folders** (100+ projects): 30+ minutes (use background mode)

### Filter Generator
- **Response time**: < 5 seconds
- **Memory usage**: < 50MB
- **Dependencies**: Python 3.6+ only

## 🤝 Contributing

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Commit your changes**
   ```bash
   git commit -m 'Add amazing feature'
   ```
4. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
5. **Open a Pull Request**

### Development Guidelines
- Follow existing code style
- Add tests for new features
- Update documentation
- Test with multiple GCP project configurations

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Google Cloud Platform for comprehensive APIs
- The open-source community for inspiration and tools
- Contributors and users for feedback and improvements

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-username/gcp-resource-tools/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/gcp-resource-tools/discussions)
- **Documentation**: [Wiki](https://github.com/your-username/gcp-resource-tools/wiki)

---

**Made with ❤️ for the GCP community**
