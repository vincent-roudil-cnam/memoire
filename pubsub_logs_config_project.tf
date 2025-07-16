# Configuration Terraform pour les logs Pub/Sub - Niveau Project
# Configuration avec filtres dynamiques basés sur les services détectés

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Variables pour la configuration project
variable "project_id" {
  description = "ID du projet GCP"
  type        = string
}

variable "prefix" {
  description = "Préfixe pour les ressources"
  type        = string
  default     = ""
}

variable "config_file" {
  description = "Fichier de configuration JSON"
  type        = string
  default     = "project_id_filter.json"
}

variable "filter_type" {
  description = "Type de filtre à utiliser (default, all_services, ou service spécifique)"
  type        = string
  default     = "all_services"
}

variable "detected_services" {
  description = "Liste des services détectés dans le projet"
  type        = list(string)
  default     = ["compute", "storage", "gke", "cloudsql", "functions", "cloudrun", "iam", "pubsub", "vertexai", "firestore", "bigquery"]
}

variable "bucket_location" {
  description = "Location du bucket GCS"
  type        = string
  default     = "EU"
}

variable "bucket_storage_class" {
  description = "Classe de stockage du bucket GCS"
  type        = string
  default     = "STANDARD"
}

variable "log_retention_days" {
  description = "Nombre de jours de rétention des logs dans GCS"
  type        = number
  default     = 365
}

variable "enable_versioning" {
  description = "Activer le versioning du bucket GCS"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environnement (dev, staging, prod)"
  type        = string
  default     = "prod"
}

# Configuration locale pour project avec services dynamiques
locals {
  # Configuration par défaut avec tous les services
  default_config = {
    ack_deadline_seconds = 600
    description = "Configuration dynamique des filtres pour les logs d'audit GCP par services"
    excluded_principals = [
      "prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com"
    ]
    monitored_actions = [
      "get", "list", "read", "describe", "search", "lookup", "query", "testIamPermissions"
    ]
    log_types = [
      "cloudaudit.googleapis.com/activity",
      "cloudaudit.googleapis.com/system_event",
      "cloudaudit.googleapis.com/policy"
    ]
    severity_levels = [
      "DEFAULT", "DEBUG", "INFO", "NOTICE", "WARNING", "ERROR", "CRITICAL", "ALERT", "EMERGENCY"
    ]
    # Mapping des services vers leurs resource types
    service_resource_types = {
      compute = ["gce_instance", "gce_disk", "gce_network", "gce_firewall", "gce_router", "gce_subnetwork"]
      storage = ["gcs_bucket"]
      gke = ["gke_cluster", "k8s_cluster", "k8s_node"]
      cloudsql = ["cloudsql_database"]
      functions = ["cloud_function"]
      cloudrun = ["cloud_run_revision"]
      iam = ["service_account", "iam_role"]
      pubsub = ["pubsub_topic", "pubsub_subscription"]
      vertexai = ["aiplatform_endpoint", "aiplatform_model"]
      firestore = ["firestore_database"]
      bigquery = ["bigquery_dataset", "bigquery_table"]
    }
    # Filtres pré-construits par service
    filters = {
      compute = "resource.type=~\"gce_.*\" AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      storage = "resource.type=\"gcs_bucket\" AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      gke = "(resource.type=\"gke_cluster\" OR resource.type=\"k8s_cluster\" OR resource.type=\"k8s_node\") AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      cloudsql = "resource.type=\"cloudsql_database\" AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      functions = "resource.type=\"cloud_function\" AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      cloudrun = "resource.type=\"cloud_run_revision\" AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      iam = "(resource.type=\"service_account\" OR resource.type=\"iam_role\") AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      pubsub = "(resource.type=\"pubsub_topic\" OR resource.type=\"pubsub_subscription\") AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      vertexai = "(resource.type=\"aiplatform_endpoint\" OR resource.type=\"aiplatform_model\") AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      firestore = "resource.type=\"firestore_database\" AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      bigquery = "(resource.type=\"bigquery_dataset\" OR resource.type=\"bigquery_table\") AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      default = "((logName:\"logs/cloudaudit.googleapis.com%2Factivity\" OR logName:\"logs/cloudaudit.googleapis.com%2Fsystem_event\" OR logName:\"logs/cloudaudit.googleapis.com%2Fpolicy\") AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\")) OR (severity >= \"WARNING\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      warning_and_above = "severity >= \"WARNING\" AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      error_and_above = "severity >= \"ERROR\" AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
    }
  }
  
  # Vérifier si le fichier de configuration existe
  config_exists = fileexists(var.config_file)
  config_data = local.config_exists ? jsondecode(file(var.config_file)) : local.default_config
  
  # Noms des ressources
  prefix = var.prefix != "" ? var.prefix : var.project_id
  topic_name = "${local.prefix}-logs-topic"
  subscription_name = "${local.prefix}-logs-sub"
  sink_name = "${local.prefix}-logs-sink"
  gcs_sink_name = "${local.prefix}-logs-gcs-sink"
  bucket_name = "${local.prefix}-logs-bucket"
  service_account_name = "${local.prefix}-sa-log"
  
  # Configuration du nom du fichier de filtre basé sur project_id
  filter_config_file = "${var.project_id}_filter.json"
  
  # Sélectionner le filtre approprié selon le type
  log_filter = var.filter_type == "all_services" ? local.config_data.filters.default : var.filter_type == "default" ? local.config_data.filters.default : lookup(local.config_data.filters, var.filter_type, local.config_data.filters.default)
  
  ack_deadline_seconds = local.config_data.ack_deadline_seconds
}

# Configuration du provider
provider "google" {
  project = var.project_id
  credentials = null
}

# 1. Création du topic Pub/Sub pour le project
resource "google_pubsub_topic" "project_logs_topic" {
  name = local.topic_name
}

# 2. Création de la subscription pour le project
resource "google_pubsub_subscription" "project_logs_subscription" {
  name  = local.subscription_name
  topic = google_pubsub_topic.project_logs_topic.name
  
  ack_deadline_seconds = local.ack_deadline_seconds
}

# 3. Création du sink de logging pour le project
resource "google_logging_project_sink" "project_logs_sink" {
  name = local.sink_name
  
  destination = "pubsub.googleapis.com/projects/${var.project_id}/topics/${google_pubsub_topic.project_logs_topic.name}"
  
  filter = local.log_filter
  
  description = "Sink logs pour project ${var.project_id} avec services: ${join(", ", var.detected_services)}"
  
  unique_writer_identity = true
}

# 4. Permissions IAM pour le sink project (writer identity)
resource "google_pubsub_topic_iam_binding" "project_logs_sink_publisher" {
  topic = google_pubsub_topic.project_logs_topic.name
  role  = "roles/pubsub.publisher"
  
  members = [
    google_logging_project_sink.project_logs_sink.writer_identity,
  ]
}

# 5. Création du service account pour le project
resource "google_service_account" "project_logs_subscriber" {
  account_id   = local.service_account_name
  display_name = "Service Account pour logs project ${var.project_id}"
  description  = "Service Account pour souscrire aux logs du projet avec services: ${join(", ", var.detected_services)}"
}

# 6. Permissions du service account sur le topic
resource "google_pubsub_topic_iam_binding" "project_service_account_subscriber_topic" {
  topic = google_pubsub_topic.project_logs_topic.name
  role  = "roles/pubsub.subscriber"
  
  members = [
    "serviceAccount:${google_service_account.project_logs_subscriber.email}",
  ]
}

# 7. Permissions du service account sur la subscription
resource "google_pubsub_subscription_iam_binding" "project_service_account_subscriber_subscription" {
  subscription = google_pubsub_subscription.project_logs_subscription.name
  role         = "roles/pubsub.subscriber"
  
  members = [
    "serviceAccount:${google_service_account.project_logs_subscriber.email}",
  ]
}

# 8. Permissions supplémentaires pour les opérations de lecture/description
resource "google_pubsub_topic_iam_binding" "project_service_account_viewer_topic" {
  topic = google_pubsub_topic.project_logs_topic.name
  role  = "roles/pubsub.viewer"
  
  members = [
    "serviceAccount:${google_service_account.project_logs_subscriber.email}",
  ]
}

resource "google_pubsub_subscription_iam_binding" "project_service_account_viewer_subscription" {
  subscription = google_pubsub_subscription.project_logs_subscription.name
  role         = "roles/pubsub.viewer"
  
  members = [
    "serviceAccount:${google_service_account.project_logs_subscriber.email}",
  ]
}

# 9. Permissions au niveau du projet pour les opérations générales
resource "google_project_iam_member" "project_service_account_pubsub_viewer" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.project_logs_subscriber.email}"
}

# 10. Génération de la clé du service account
resource "google_service_account_key" "project_logs_subscriber_key" {
  service_account_id = google_service_account.project_logs_subscriber.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Sauvegarde de la clé dans un fichier local
resource "local_file" "project_service_account_key" {
  content  = base64decode(google_service_account_key.project_logs_subscriber_key.private_key)
  filename = "${local.service_account_name}-key.json"
  
  file_permission = "0600"
}

# 11. Génération du fichier de configuration JSON avec les services détectés
resource "local_file" "project_filter_config" {
  content = jsonencode({
    description = "Configuration dynamique pour le projet ${var.project_id}"
    project_id = var.project_id
    detected_services = var.detected_services
    filter_type = var.filter_type
    ack_deadline_seconds = local.ack_deadline_seconds
    excluded_principals = local.config_data.excluded_principals
    monitored_actions = local.config_data.monitored_actions
    log_types = local.config_data.log_types
    severity_levels = local.config_data.severity_levels
    service_resource_types = local.config_data.service_resource_types
    filters = merge(
      {
        dynamic = local.log_filter
        default = local.config_data.filters.default
        warning_and_above = local.config_data.filters.warning_and_above
        error_and_above = local.config_data.filters.error_and_above
      },
      {
        for service in var.detected_services :
        "${service}_only" => lookup(local.config_data.filters, service, "")
      }
    )
  })
  filename = local.filter_config_file
  file_permission = "0644"
}

# 12. Création du bucket GCS pour les logs du project
resource "google_storage_bucket" "project_logs_bucket" {
  name          = local.bucket_name
  location      = var.bucket_location
  storage_class = var.bucket_storage_class
  uniform_bucket_level_access = true
  
  # Configuration de lifecycle pour gérer la rétention
  lifecycle_rule {
    condition {
      age = var.log_retention_days
    }
    action {
      type = "Delete"
    }
  }
  
  # Configuration de versioning
  versioning {
    enabled = var.enable_versioning
  }
  
  # Étiquettes
  labels = {
    purpose     = "project-log-storage"
    environment = var.environment
    project_id  = var.project_id
  }
}

# 13. Création du sink de logging vers GCS pour le project
resource "google_logging_project_sink" "project_logs_gcs_sink" {
  name = local.gcs_sink_name
  
  destination = "storage.googleapis.com/${google_storage_bucket.project_logs_bucket.name}"
  
  filter = local.log_filter
  
  description = "Sink logs vers GCS pour project ${var.project_id} avec services: ${join(", ", var.detected_services)}"
  
  unique_writer_identity = true
}

# 14. Permissions IAM pour le sink GCS project (writer identity)
resource "google_storage_bucket_iam_binding" "project_logs_gcs_sink_writer" {
  bucket = google_storage_bucket.project_logs_bucket.name
  role   = "roles/storage.objectCreator"
  
  members = [
    google_logging_project_sink.project_logs_gcs_sink.writer_identity,
  ]
}

# Outputs pour le project
output "project_id" {
  description = "ID du projet GCP"
  value       = var.project_id
}

output "project_topic_name" {
  description = "Nom du topic Pub/Sub pour le project"
  value       = google_pubsub_topic.project_logs_topic.name
}

output "project_subscription_name" {
  description = "Nom de la subscription pour le project"
  value       = google_pubsub_subscription.project_logs_subscription.name
}

output "project_sink_name" {
  description = "Nom du sink de logging pour le project"
  value       = google_logging_project_sink.project_logs_sink.name
}

output "project_service_account_email" {
  description = "Email du service account pour le project"
  value       = google_service_account.project_logs_subscriber.email
}

output "project_service_account_key_file" {
  description = "Fichier de clé du service account pour le project"
  value       = local_file.project_service_account_key.filename
}

output "project_writer_identity" {
  description = "Writer identity du sink pour le project"
  value       = google_logging_project_sink.project_logs_sink.writer_identity
}

output "project_bucket_name" {
  description = "Nom du bucket GCS pour le project"
  value       = google_storage_bucket.project_logs_bucket.name
}

output "project_bucket_url" {
  description = "URL du bucket GCS pour le project"
  value       = google_storage_bucket.project_logs_bucket.url
}

output "project_gcs_sink_name" {
  description = "Nom du sink vers GCS pour le project"
  value       = google_logging_project_sink.project_logs_gcs_sink.name
}

output "project_gcs_sink_writer_identity" {
  description = "Writer identity du sink GCS pour le project"
  value       = google_logging_project_sink.project_logs_gcs_sink.writer_identity
}

output "project_detected_services" {
  description = "Services détectés dans le projet"
  value       = var.detected_services
}

output "project_filter_type" {
  description = "Type de filtre utilisé"
  value       = var.filter_type
}

output "project_log_filter_used" {
  description = "Filtre de log utilisé pour le project"
  value       = local.log_filter
}

output "project_config_file" {
  description = "Fichier de configuration généré pour le project"
  value       = local.filter_config_file
}

output "project_config_file_status" {
  description = "Statut du fichier de configuration pour le project"
  value = local.config_exists ? "Fichier ${var.config_file} trouvé et utilisé" : "Fichier ${var.config_file} non trouvé, configuration par défaut utilisée"
}

output "project_test_commands" {
  description = "Commandes pour tester la configuration du project"
  value = <<-EOT
    # Test basique Pub/Sub pour le project
    gcloud pubsub subscriptions pull ${google_pubsub_subscription.project_logs_subscription.name} --limit=10 --auto-ack --project=${var.project_id}
    
    # Test avec impersonation du service account
    gcloud pubsub subscriptions pull ${google_pubsub_subscription.project_logs_subscription.name} --limit=10 --auto-ack --project=${var.project_id} --impersonate-service-account=${google_service_account.project_logs_subscriber.email}
    
    # Vérifier les logs dans le bucket GCS
    gsutil ls gs://${google_storage_bucket.project_logs_bucket.name}/
    
    # Test avec la clé directement
    export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/${local_file.project_service_account_key.filename}
    gcloud auth activate-service-account --key-file=${local_file.project_service_account_key.filename}
    gcloud pubsub subscriptions describe ${google_pubsub_subscription.project_logs_subscription.name} --project=${var.project_id} --format="yaml(name, topic, filter)"
    
    # Générer un filtre dynamique avec les services détectés
    ./generate_dynamic_filter.py ${var.project_id} --services ${join(" ", var.detected_services)} --output ${local.filter_config_file}
    
    # Tester le comptage des ressources
    ./count_gcp_resources.sh ${var.project_id}
  EOT
}

output "project_architecture_summary" {
  description = "Résumé de l'architecture de logging pour le project"
  value = <<-EOT
    Architecture de logging déployée pour le projet ${var.project_id}:
    
    📊 Portée:
    - Projet spécifique: ${var.project_id}
    - Services détectés: ${join(", ", var.detected_services)}
    - Type de filtre: ${var.filter_type}
    
    📊 Sources de logs par service:
    %{for service in var.detected_services}
    - ${service}: ${lookup(local.config_data.service_resource_types, service, "ressources spécifiques")}
    %{endfor}
    - Logs avec severity >= WARNING pour tous les services
    
    🎯 Destinations:
    1. Pub/Sub Topic: ${google_pubsub_topic.project_logs_topic.name}
       - Subscription: ${google_pubsub_subscription.project_logs_subscription.name}
       - Service Account: ${google_service_account.project_logs_subscriber.email}
       
    2. GCS Bucket: ${google_storage_bucket.project_logs_bucket.name}
       - Location: ${var.bucket_location}
       - Storage Class: ${var.bucket_storage_class}
       - Rétention: ${var.log_retention_days} jours
    
    🔐 Sécurité:
    - Writer identities uniques pour chaque sink
    - Service account dédié avec permissions minimales
    - Chiffrement des logs en transit et au repos
    - Filtres spécifiques par service
    
    ⚡ Performance:
    - Ack deadline: ${local.ack_deadline_seconds} secondes
    - Configuration JSON: ${local.filter_config_file}
    - Filtres dynamiques par service
    ${var.enable_versioning ? "- Versioning du bucket activé" : "- Versioning du bucket désactivé"}
  EOT
}

output "project_troubleshooting_commands" {
  description = "Commandes pour diagnostiquer les permissions du project"
  value = <<-EOT
    # Vérifier si le service account existe
    gcloud iam service-accounts list --filter="email:${google_service_account.project_logs_subscriber.email}" --project=${var.project_id}
    
    # Vérifier les permissions du service account
    gcloud projects get-iam-policy ${var.project_id} --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:${google_service_account.project_logs_subscriber.email}"
    
    # Vérifier les permissions sur le topic
    gcloud pubsub topics get-iam-policy ${google_pubsub_topic.project_logs_topic.name} --project=${var.project_id}
    
    # Vérifier les permissions sur la subscription
    gcloud pubsub subscriptions get-iam-policy ${google_pubsub_subscription.project_logs_subscription.name} --project=${var.project_id}
    
    # Vérifier les permissions sur le bucket GCS
    gsutil iam get gs://${google_storage_bucket.project_logs_bucket.name}
    
    # Vérifier les sinks de logging au niveau project
    gcloud logging sinks list --project=${var.project_id}
    gcloud logging sinks describe ${google_logging_project_sink.project_logs_sink.name} --project=${var.project_id}
    gcloud logging sinks describe ${google_logging_project_sink.project_logs_gcs_sink.name} --project=${var.project_id}
    
    # Tester l'écriture dans le bucket (nécessite des permissions)
    echo "test log entry from project ${var.project_id}" | gsutil cp - gs://${google_storage_bucket.project_logs_bucket.name}/test-$(date +%s).txt
    
    # Vérifier les services détectés avec le script de comptage
    ./count_gcp_resources.sh ${var.project_id} true
    
    # Générer des filtres dynamiques
    ./generate_dynamic_filter.py ${var.project_id} --services ${join(" ", var.detected_services)} --explain
    
    # Vérifier la configuration JSON générée
    cat ${local.filter_config_file} | python3 -m json.tool
  EOT
}

output "project_integration_examples" {
  description = "Exemples d'intégration avec les outils de comptage"
  value = <<-EOT
    # Intégration avec count_gcp_resources.sh
    
    1. Détecter les services dans un projet:
       ./count_gcp_resources.sh ${var.project_id} true
    
    2. Utiliser la sortie pour configurer les filtres:
       DETECTED_SERVICES=$(./count_gcp_resources.sh ${var.project_id} | grep -E "(VMs|Storage|GKE|SQL|Functions|CloudRun|IAM|PubSub)" | awk '{print $1}')
    
    3. Générer la configuration Terraform:
       terraform apply -var="project_id=${var.project_id}" -var="detected_services=[\$DETECTED_SERVICES]" -var="filter_type=all_services"
    
    4. Générer des filtres dynamiques:
       ./generate_dynamic_filter.py ${var.project_id} --services compute storage gke cloudsql functions cloudrun iam pubsub --output ${local.filter_config_file}
    
    5. Test des filtres générés:
       # Vérifier que les logs sont capturés pour chaque service
       gcloud logging read "resource.type=gce_instance" --limit=5 --project=${var.project_id}
       gcloud logging read "resource.type=gcs_bucket" --limit=5 --project=${var.project_id}
       gcloud logging read "resource.type=gke_cluster" --limit=5 --project=${var.project_id}
  EOT
}
