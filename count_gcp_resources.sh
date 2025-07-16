#!/bin/bash

# Parse arguments to handle both folder and project modes
TARGET_ID="${1:-380194406045}"
DEBUG="${2:-false}"
BACKGROUND="${3:-false}"
LOG_FILE="$(date '+%Y%m%d_%H%M%S')_gcp_resource_summary.log"

# Determine if target is a project or folder
MODE="folder"  # default mode
if [[ "$TARGET_ID" =~ ^[a-z][a-z0-9-]*[a-z0-9]$ ]] && [[ ${#TARGET_ID} -ge 6 ]] && [[ ${#TARGET_ID} -le 30 ]]; then
    MODE="project"
fi

# Initialize counters
total_projects=0
error_projects=0

count_vms=0
count_vpc=0
count_subnet=0
count_firewalls=0
count_storage=0
count_vertexai=0
count_gke=0
count_sql=0
count_functions=0
count_firestore=0
count_bigquery=0
count_iam=0
count_cloudrun=0
count_pubsub_topics=0
count_pubsub_subscriptions=0

PROJECT_IDS=()

# Add associative arrays to track resources by project
declare -A vm_by_project
declare -A vpc_by_project
declare -A subnet_by_project
declare -A firewall_by_project
declare -A storage_by_project
declare -A gke_by_project
declare -A sql_by_project
declare -A functions_by_project
declare -A vertexai_by_project
declare -A firestore_by_project
declare -A bigquery_by_project
declare -A iam_by_project
declare -A cloudrun_by_project
declare -A pubsub_topics_by_project
declare -A pubsub_subscriptions_by_project

show_usage() {
    echo "Usage: $0 [TARGET_ID] [debug] [background]"
    echo ""
    echo "Arguments:"
    echo "  TARGET_ID       - GCP folder ID or project ID (default: 380194406045)"
    echo "                   - If it looks like a project ID, will scan single project"
    echo "                   - If it looks like a folder ID, will scan all projects in folder"
    echo "  debug           - Enable debug mode (true/false, default: false)"
    echo "  background      - Run in background mode (true/false, default: false)"
    echo "                   - Background mode runs detached from terminal (nohup)"
    echo ""
    echo "Exemples:"
    echo "  $0                                     # Utilise le folder par défaut"
    echo "  $0 123456789                           # Folder spécifique"
    echo "  $0 my-project-id                       # Project spécifique"
    echo "  $0 123456789 true                     # Folder spécifique avec debug"
    echo "  $0 my-project-id true                 # Project spécifique avec debug"
    echo "  $0 '' true                            # Folder par défaut avec debug"
    echo "  $0 123456789 false true               # Folder spécifique en background"
    echo "  $0 my-project-id true true            # Project spécifique avec debug en background"
}

if [[ "$TARGET_ID" == "-h" || "$TARGET_ID" == "--help" ]]; then
    show_usage
    exit 0
fi

# Check if we need to run in background mode
if [[ "$BACKGROUND" == "true" || "$BACKGROUND" == "1" ]]; then
    # If already running in background, continue normally
    if [[ -z "$NOHUP_RUNNING" ]]; then
        echo "🔄 Starting script in background mode..."
        echo "📝 Log file: $LOG_FILE"
        echo "📋 Process will continue even if terminal is disconnected"
        echo "🔍 To monitor progress: tail -f $LOG_FILE"
        echo "🛑 To stop process: pkill -f \"$(basename $0)\""
        echo ""
        
        # Export the flag to indicate we're running in background
        export NOHUP_RUNNING=1
        
        # Run the script in background with nohup
        nohup "$0" "$TARGET_ID" "$DEBUG" false > "$LOG_FILE" 2>&1 &
        
        # Get the PID of the background process
        BG_PID=$!
        echo "🚀 Background process started with PID: $BG_PID"
        echo "📝 Output being written to: $LOG_FILE"
        echo "📋 To check if process is still running: ps -p $BG_PID"
        
        # Save PID to file for easy reference
        echo "$BG_PID" > "${LOG_FILE}.pid"
        echo "💾 PID saved to: ${LOG_FILE}.pid"
        
        exit 0
    fi
    
    # If running in background, disable interactive output
    exec > "$LOG_FILE" 2>&1
    echo "🔄 Background mode activated at $(date)"
fi

# Enable debug mode if requested
if [[ "$DEBUG" == "true" || "$DEBUG" == "1" ]]; then
    DEBUG_MODE=true
    echo "🔧 Debug mode enabled"
else
    DEBUG_MODE=false
fi

debug_log() {
    if [ "$DEBUG_MODE" = true ]; then
        echo "🐛 DEBUG: $*" >&2
    fi
}

# If TARGET_ID is empty string, use default folder
if [ -z "$TARGET_ID" ]; then
    TARGET_ID="380194406045"
    MODE="folder"
fi

echo "🎯 Mode: $MODE" | tee -a "$LOG_FILE"
if [ "$MODE" = "folder" ]; then
    echo "📁 Using folder ID: $TARGET_ID" | tee -a "$LOG_FILE"
else
    echo "📝 Using project ID: $TARGET_ID" | tee -a "$LOG_FILE"
fi
debug_log "Debug mode: $DEBUG_MODE"

# Recursive folder scan
get_all_subfolders() {
  local parent="$1"
  echo "$parent"
  local subs
  mapfile -t subs < <(gcloud resource-manager folders list --folder="$parent" --format="value(name)")
  for sub in "${subs[@]}"; do
    local sub_id="${sub##*/}"
    get_all_subfolders "$sub_id"
  done
}

collect_project_ids() {
  local folder_id="$1"
  local pids
  mapfile -t pids < <(gcloud projects list --filter="parent.type=folder AND parent.id=$folder_id" --format="value(projectId)")
  for pid in "${pids[@]}"; do
    PROJECT_IDS+=("$pid")
  done
}

get_resource_count() {
  local cmd="$1"
  local project_id="$2"
  debug_log "Executing: $cmd --project=$project_id"
  local count
  count=$(timeout 30 $cmd --project="$project_id" --format="value(name)" 2>/dev/null | wc -l)
  local exit_code=$?
  if [ $exit_code -eq 124 ]; then
    debug_log "Command timed out after 30 seconds"
    count=0
  fi
  debug_log "Result: $count resources found"
  echo "$count"
}

# Helper function to create a progress indicator for background mode
log_progress() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message"
    if [[ "$BACKGROUND" == "true" || "$BACKGROUND" == "1" ]] && [[ -n "$NOHUP_RUNNING" ]]; then
        echo "[$timestamp] $message" >> "$LOG_FILE"
    fi
}

log_progress "📝 Scanning projects..."

if [ "$MODE" = "project" ]; then
    # Single project mode
    debug_log "Single project mode: $TARGET_ID"
    PROJECT_IDS=("$TARGET_ID")
else
    # Folder mode (existing logic)
    debug_log "Getting all subfolders..."
    mapfile -t ALL_FOLDER_IDS < <(get_all_subfolders "$TARGET_ID")
    debug_log "Found ${#ALL_FOLDER_IDS[@]} folders: ${ALL_FOLDER_IDS[*]}"

    debug_log "Collecting project IDs from all folders..."
    for folder_id in "${ALL_FOLDER_IDS[@]}"; do
      debug_log "Processing folder: $folder_id"
      collect_project_ids "$folder_id"
    done
fi

debug_log "Total projects found: ${#PROJECT_IDS[@]}"
if [ "$DEBUG_MODE" = true ]; then
    debug_log "Project list: ${PROJECT_IDS[*]}"
fi

# Remove duplicates
IFS=" " read -r -a PROJECT_IDS <<< "$(printf '%s\n' "${PROJECT_IDS[@]}" | sort -u | tr '\n' ' ')"

for project_id in "${PROJECT_IDS[@]}"; do
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "[%s] 🔍 Checking project: %s (%d/%d)\n" "$timestamp" "$project_id" "$((total_projects + 1))" "${#PROJECT_IDS[@]}" | tee -a "$LOG_FILE"
  ((total_projects++))

  # Test project access
  debug_log "Testing access to project: $project_id"
  if ! gcloud projects describe "$project_id" &>/dev/null; then
    ((error_projects++))
    printf "❌ ERROR: Cannot access project %s\n" "$project_id" | tee -a "$LOG_FILE"
    continue
  fi
  debug_log "Access confirmed for project: $project_id"

  # Initialize project counters
  vms=0 vpcs=0 subnets=0 firewalls=0 storage_count=0 sql_count=0
  functions_count=0 gke_count=0 bigquery_count=0 vertex_enabled=0 firestore_enabled=0
  iam_count=0 cloudrun_count=0 pubsub_topics_count=0 pubsub_subscriptions_count=0

  # Check GKE clusters first to determine if we should count VMs
  project_has_gke=false
  debug_log "Checking for GKE clusters in project: $project_id"
  gke_count=$(get_resource_count "gcloud container clusters list" "$project_id")
  
  # Ensure gke_count is a valid number
  if [[ "$gke_count" =~ ^[0-9]+$ ]] && [ "$gke_count" -gt 0 ]; then
    project_has_gke=true
    debug_log "Project $project_id has $gke_count GKE cluster(s)"
  else
    gke_count=0
    debug_log "No GKE clusters found in project: $project_id"
  fi

  # Count VM resources
  debug_log "Counting VM resources for project: $project_id"
  if [ "$project_has_gke" = false ]; then
    debug_log "Counting VMs (no GKE clusters found)"
    vms=$(get_resource_count "gcloud compute instances list" "$project_id")
  else
    vms=0
    printf "⚠️  Project %s has GKE clusters - VMs excluded from count\n" "$project_id" | tee -a "$LOG_FILE"
  fi
  debug_log "Counting VPC networks"
  vpcs=$(get_resource_count "gcloud compute networks list" "$project_id")
  debug_log "Counting subnets"
  subnets=$(get_resource_count "gcloud compute networks subnets list" "$project_id")
  debug_log "Counting firewalls"
  firewalls=$(get_resource_count "gcloud compute firewall-rules list" "$project_id")

  # Count storage resources
  debug_log "Counting storage buckets for project: $project_id"
  storage_count=$(get_resource_count "gcloud storage buckets list" "$project_id")

  # Count SQL resources
  debug_log "Counting SQL instances for project: $project_id"
  sql_count=$(timeout 30 gcloud sql instances list --project="$project_id" --format="value(name)" 2>/dev/null | wc -l)
  if [ $? -eq 124 ]; then
    debug_log "SQL instances command timed out for project: $project_id"
    sql_count=0
  fi
  debug_log "SQL instances found: $sql_count"

  # Count Cloud Functions
  debug_log "Counting Cloud Functions for project: $project_id"
  functions_count=$(get_resource_count "gcloud functions list" "$project_id")

  # Count Cloud Run services
  debug_log "Counting Cloud Run services for project: $project_id"
  cloudrun_count=$(get_resource_count "gcloud run services list" "$project_id")

  # Count IAM service accounts
  debug_log "Counting IAM service accounts for project: $project_id"
  iam_count=$(get_resource_count "gcloud iam service-accounts list" "$project_id")

  # Count Pub/Sub topics
  debug_log "Counting Pub/Sub topics for project: $project_id"
  pubsub_topics_count=$(get_resource_count "gcloud pubsub topics list" "$project_id")

  # Count Pub/Sub subscriptions
  debug_log "Counting Pub/Sub subscriptions for project: $project_id"
  pubsub_subscriptions_count=$(get_resource_count "gcloud pubsub subscriptions list" "$project_id")

  # Count BigQuery datasets
  debug_log "Counting BigQuery datasets for project: $project_id"
  bigquery_count=$(timeout 30 bq ls --project_id="$project_id" 2>/dev/null | grep -v "^Dataset" | wc -l)
  if [ $? -eq 124 ]; then
    debug_log "BigQuery command timed out for project: $project_id"
    bigquery_count=0
  fi
  debug_log "BigQuery datasets found: $bigquery_count"

  # Check services for VertexAI and Firestore
  debug_log "Checking enabled services for project: $project_id"
  enabled_services=$(timeout 30 gcloud services list --enabled --format="value(config.name)" --project="$project_id" 2>/dev/null)
  if [ $? -eq 124 ]; then
    debug_log "Services list command timed out for project: $project_id"
    vertex_enabled=0
    firestore_enabled=0
  else
    vertex_enabled=$(grep -c "aiplatform.googleapis.com" <<< "$enabled_services")
    firestore_enabled=$(grep -c "firestore.googleapis.com" <<< "$enabled_services")
  fi
  debug_log "Vertex AI enabled: $vertex_enabled"
  debug_log "Firestore enabled: $firestore_enabled"

  # Ensure all values are numeric
  vms=$(printf "%d" "$vms" 2>/dev/null || echo 0)
  vpcs=$(printf "%d" "$vpcs" 2>/dev/null || echo 0)
  subnets=$(printf "%d" "$subnets" 2>/dev/null || echo 0)
  firewalls=$(printf "%d" "$firewalls" 2>/dev/null || echo 0)
  storage_count=$(printf "%d" "$storage_count" 2>/dev/null || echo 0)
  sql_count=$(printf "%d" "$sql_count" 2>/dev/null || echo 0)
  functions_count=$(printf "%d" "$functions_count" 2>/dev/null || echo 0)
  cloudrun_count=$(printf "%d" "$cloudrun_count" 2>/dev/null || echo 0)
  iam_count=$(printf "%d" "$iam_count" 2>/dev/null || echo 0)
  pubsub_topics_count=$(printf "%d" "$pubsub_topics_count" 2>/dev/null || echo 0)
  pubsub_subscriptions_count=$(printf "%d" "$pubsub_subscriptions_count" 2>/dev/null || echo 0)
  gke_count=$(printf "%d" "$gke_count" 2>/dev/null || echo 0)
  vertex_enabled=$(printf "%d" "$vertex_enabled" 2>/dev/null || echo 0)
  firestore_enabled=$(printf "%d" "$firestore_enabled" 2>/dev/null || echo 0)
  bigquery_count=$(printf "%d" "$bigquery_count" 2>/dev/null || echo 0)

  debug_log "Project $project_id results: VMs:$vms, VPCs:$vpcs, Subnets:$subnets, Firewalls:$firewalls, Storage:$storage_count, GKE:$gke_count, SQL:$sql_count, Functions:$functions_count, CloudRun:$cloudrun_count, IAM:$iam_count, PubSub-Topics:$pubsub_topics_count, PubSub-Subs:$pubsub_subscriptions_count, VertexAI:$vertex_enabled, Firestore:$firestore_enabled, BQ:$bigquery_count"

  # Update global totals and store per-project data
  count_vms=$((count_vms + vms))
  count_vpc=$((count_vpc + vpcs))
  count_subnet=$((count_subnet + subnets))
  count_firewalls=$((count_firewalls + firewalls))
  count_storage=$((count_storage + storage_count))
  count_sql=$((count_sql + sql_count))
  count_functions=$((count_functions + functions_count))
  count_cloudrun=$((count_cloudrun + cloudrun_count))
  count_iam=$((count_iam + iam_count))
  count_pubsub_topics=$((count_pubsub_topics + pubsub_topics_count))
  count_pubsub_subscriptions=$((count_pubsub_subscriptions + pubsub_subscriptions_count))
  count_gke=$((count_gke + gke_count))
  count_vertexai=$((count_vertexai + vertex_enabled))
  count_firestore=$((count_firestore + firestore_enabled))
  count_bigquery=$((count_bigquery + bigquery_count))

  # Store per-project counts (only if > 0)
  [ "$vms" -gt 0 ] && vm_by_project["$project_id"]=$vms
  [ "$vpcs" -gt 0 ] && vpc_by_project["$project_id"]=$vpcs
  [ "$subnets" -gt 0 ] && subnet_by_project["$project_id"]=$subnets
  [ "$firewalls" -gt 0 ] && firewall_by_project["$project_id"]=$firewalls
  [ "$storage_count" -gt 0 ] && storage_by_project["$project_id"]=$storage_count
  [ "$gke_count" -gt 0 ] && gke_by_project["$project_id"]=$gke_count
  [ "$sql_count" -gt 0 ] && sql_by_project["$project_id"]=$sql_count
  [ "$functions_count" -gt 0 ] && functions_by_project["$project_id"]=$functions_count
  [ "$cloudrun_count" -gt 0 ] && cloudrun_by_project["$project_id"]=$cloudrun_count
  [ "$iam_count" -gt 0 ] && iam_by_project["$project_id"]=$iam_count
  [ "$pubsub_topics_count" -gt 0 ] && pubsub_topics_by_project["$project_id"]=$pubsub_topics_count
  [ "$pubsub_subscriptions_count" -gt 0 ] && pubsub_subscriptions_by_project["$project_id"]=$pubsub_subscriptions_count
  [ "$vertex_enabled" -gt 0 ] && vertexai_by_project["$project_id"]=$vertex_enabled
  [ "$firestore_enabled" -gt 0 ] && firestore_by_project["$project_id"]=$firestore_enabled
  [ "$bigquery_count" -gt 0 ] && bigquery_by_project["$project_id"]=$bigquery_count

  # Display results for this project with timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  printf "[%s] ✅ %s → VMs:%d | VPCs:%d | Subnets:%d | Firewalls:%d | Storage:%d | GKE:%d | SQL:%d | Functions:%d | CloudRun:%d | IAM:%d | PubSub-Topics:%d | PubSub-Subs:%d | VertexAI:%d | Firestore:%d | BQ:%d\n" \
    "$timestamp" "$project_id" "$vms" "$vpcs" "$subnets" "$firewalls" "$storage_count" "$gke_count" "$sql_count" "$functions_count" "$cloudrun_count" "$iam_count" "$pubsub_topics_count" "$pubsub_subscriptions_count" "$vertex_enabled" "$firestore_enabled" "$bigquery_count" | tee -a "$LOG_FILE"
done

debug_log "Processing completed. Total projects: $total_projects, Errors: $error_projects"

# Function to format resource list by project
format_resource_list() {
    local -n array_ref=$1
    local output=""
    for project in "${!array_ref[@]}"; do
        if [ -n "$output" ]; then
            output+=", "
        fi
        output+="$project: ${array_ref[$project]}"
    done
    echo "$output"
}

# Enhanced summary with detailed breakdown
{
echo -e "\n=============================="
echo "📊 SUMMARY"
echo "------------------------------"
echo "📁 Projects scanned:         $total_projects"
echo "⚠️  Projects with errors:     $error_projects"
echo ""
echo "📈 TOTAL COUNTS BY RESOURCE TYPE"
echo "------------------------------"
echo "💻 Total VMs:                $count_vms"
echo "🌐 Total VPCs:               $count_vpc"
echo "🧩 Total Subnetworks:        $count_subnet"
echo "🔥 Total Firewall Rules:     $count_firewalls"
echo "📦 Total Storage Buckets:    $count_storage"
echo "🐳 Total GKE Clusters:       $count_gke"
echo "🗃️  Total SQL Instances:      $count_sql"
echo "⚙️  Total Cloud Functions:    $count_functions"
echo "☁️  Total Cloud Run Services: $count_cloudrun"
echo "🔐 Total IAM Service Accounts: $count_iam"
echo "📢 Total Pub/Sub Topics:     $count_pubsub_topics"
echo "📥 Total Pub/Sub Subscriptions: $count_pubsub_subscriptions"
echo "🤖 Projects with Vertex AI:  $count_vertexai"
echo "📁 Projects with Firestore:  $count_firestore"
echo "🔍 BigQuery Datasets:        $count_bigquery"
echo ""
echo "📋 DETAILED BREAKDOWN BY PROJECT"
echo "------------------------------"

# VMs breakdown
if [ ${#vm_by_project[@]} -gt 0 ]; then
    echo "💻 VMs by project:"
    echo "   $(format_resource_list vm_by_project)"
    echo ""
fi

# VPCs breakdown
if [ ${#vpc_by_project[@]} -gt 0 ]; then
    echo "🌐 VPCs by project:"
    echo "   $(format_resource_list vpc_by_project)"
    echo ""
fi

# Subnets breakdown
if [ ${#subnet_by_project[@]} -gt 0 ]; then
    echo "🧩 Subnetworks by project:"
    echo "   $(format_resource_list subnet_by_project)"
    echo ""
fi

# Firewalls breakdown
if [ ${#firewall_by_project[@]} -gt 0 ]; then
    echo "🔥 Firewall Rules by project:"
    echo "   $(format_resource_list firewall_by_project)"
    echo ""
fi

# Storage breakdown
if [ ${#storage_by_project[@]} -gt 0 ]; then
    echo "📦 Storage Buckets by project:"
    echo "   $(format_resource_list storage_by_project)"
    echo ""
fi

# GKE breakdown
if [ ${#gke_by_project[@]} -gt 0 ]; then
    echo "🐳 GKE Clusters by project:"
    echo "   $(format_resource_list gke_by_project)"
    echo ""
fi

# SQL breakdown
if [ ${#sql_by_project[@]} -gt 0 ]; then
    echo "🗃️  SQL Instances by project:"
    echo "   $(format_resource_list sql_by_project)"
    echo ""
fi

# Functions breakdown
if [ ${#functions_by_project[@]} -gt 0 ]; then
    echo "⚙️  Cloud Functions by project:"
    echo "   $(format_resource_list functions_by_project)"
    echo ""
fi

# Cloud Run breakdown
if [ ${#cloudrun_by_project[@]} -gt 0 ]; then
    echo "☁️  Cloud Run Services by project:"
    echo "   $(format_resource_list cloudrun_by_project)"
    echo ""
fi

# IAM breakdown
if [ ${#iam_by_project[@]} -gt 0 ]; then
    echo "🔐 IAM Service Accounts by project:"
    echo "   $(format_resource_list iam_by_project)"
    echo ""
fi

# Pub/Sub Topics breakdown
if [ ${#pubsub_topics_by_project[@]} -gt 0 ]; then
    echo "📢 Pub/Sub Topics by project:"
    echo "   $(format_resource_list pubsub_topics_by_project)"
    echo ""
fi

# Pub/Sub Subscriptions breakdown
if [ ${#pubsub_subscriptions_by_project[@]} -gt 0 ]; then
    echo "📥 Pub/Sub Subscriptions by project:"
    echo "   $(format_resource_list pubsub_subscriptions_by_project)"
    echo ""
fi

# Vertex AI breakdown
if [ ${#vertexai_by_project[@]} -gt 0 ]; then
    echo "🤖 Vertex AI enabled in projects:"
    echo "   $(format_resource_list vertexai_by_project)"
    echo ""
fi

# Firestore breakdown
if [ ${#firestore_by_project[@]} -gt 0 ]; then
    echo "📁 Firestore enabled in projects:"
    echo "   $(format_resource_list firestore_by_project)"
    echo ""
fi

# BigQuery breakdown
if [ ${#bigquery_by_project[@]} -gt 0 ]; then
    echo "🔍 BigQuery Datasets by project:"
    echo "   $(format_resource_list bigquery_by_project)"
    echo ""
fi

echo "=============================="
echo "📝 Report saved to:           $LOG_FILE"
} | tee -a "$LOG_FILE"

# Final message for background mode
if [[ "$BACKGROUND" == "true" || "$BACKGROUND" == "1" ]] && [[ -n "$NOHUP_RUNNING" ]]; then
    echo ""
    echo "🎉 Background execution completed successfully at $(date)"
    echo "📝 Full report available in: $LOG_FILE"
    echo "🗑️  PID file can be removed: ${LOG_FILE}.pid"
    
    # Clean up PID file
    rm -f "${LOG_FILE}.pid"
fi

