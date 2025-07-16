# Configuration Terraform pour les logs Pub/Sub - Niveau Folder
# Configuration pour folder et sous-folders récursivement

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Variables pour la configuration folder
variable "folder_id" {
  description = "ID du folder GCP racine"
  type        = string
}

variable "organization_id" {
  description = "ID de l'organisation GCP"
  type        = string
}

variable "project_id" {
  description = "ID du projet GCP où créer les ressources Pub/Sub"
  type        = string
}

variable "prefix" {
  description = "Préfixe pour les ressources"
  type        = string
  default     = "folder-logs"
}

variable "config_file" {
  description = "Fichier de configuration JSON"
  type        = string
  default     = "json"
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

# Configuration locale pour folder
locals {
  # Configuration par défaut pour folder
  default_config = {
    ack_deadline_seconds = 600
    description = "Configuration par défaut des filtres pour les logs d'audit GCP au niveau folder"
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
  }
  
  # Vérifier si le fichier de configuration existe
  config_exists = fileexists(var.config_file)
  config_data = local.config_exists ? jsondecode(file(var.config_file)) : local.default_config
  
  # Noms des ressources pour folder
  prefix = var.prefix
  topic_name = "${local.prefix}-topic"
  subscription_name = "${local.prefix}-sub"
  folder_sink_name = "${local.prefix}-folder-sink"
  gcs_sink_name = "${local.prefix}-gcs-sink"
  bucket_name = "${local.prefix}-bucket"
  service_account_name = "${local.prefix}-sa"
  
  # Filtre par défaut pour folder - s'applique à tous les projets du folder et sous-folders
  folder_log_filter = <<-EOT
    (
      (
        logName:"logs/cloudaudit.googleapis.com%2Factivity" OR
        logName:"logs/cloudaudit.googleapis.com%2Fsystem_event" OR
        logName:"logs/cloudaudit.googleapis.com%2Fpolicy"
      )
      AND (
        protoPayload.methodName:("get" OR "list" OR "read" OR "describe" OR "search" OR "lookup" OR "query" OR "testIamPermissions")
        OR protoPayload.methodName=~".*\\.get.*"
        OR protoPayload.methodName=~".*\\.list.*"
        OR protoPayload.methodName=~".*\\.read.*"
        OR protoPayload.methodName=~".*\\.describe.*"
        OR protoPayload.methodName=~".*\\.search.*"
        OR protoPayload.methodName=~".*\\.lookup.*"
        OR protoPayload.methodName=~".*\\.query.*"
        OR protoPayload.methodName=~".*testIamPermissions.*"
      )
    )
    OR (
      severity >= "WARNING"
    )
    AND NOT (
      protoPayload.authenticationInfo.principalEmail="prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com"
    )
  EOT
  
  ack_deadline_seconds = local.config_data.ack_deadline_seconds
}

# Configuration du provider
provider "google" {
  project = var.project_id
  credentials = null
}

# 1. Création du topic Pub/Sub pour le folder
resource "google_pubsub_topic" "folder_logs_topic" {
  name = local.topic_name
  project = var.project_id
}

# 2. Création de la subscription pour le folder
resource "google_pubsub_subscription" "folder_logs_subscription" {
  name  = local.subscription_name
  topic = google_pubsub_topic.folder_logs_topic.name
  project = var.project_id
  
  ack_deadline_seconds = local.ack_deadline_seconds
}

# 3. Création du sink de logging au niveau folder (couvre tous les projets du folder récursivement)
resource "google_logging_folder_sink" "folder_logs_sink" {
  name   = local.folder_sink_name
  folder = var.folder_id
  
  destination = "pubsub.googleapis.com/projects/${var.project_id}/topics/${google_pubsub_topic.folder_logs_topic.name}"
  
  filter = local.folder_log_filter
  
  description = "Sink logs pour folder ${var.folder_id} - tous projets et sous-folders"
  
  # Inclure les enfants (sous-folders et projets)
  include_children = true
}

# 4. Permissions IAM pour le sink folder (writer identity)
resource "google_pubsub_topic_iam_binding" "folder_logs_sink_publisher" {
  topic = google_pubsub_topic.folder_logs_topic.name
  role  = "roles/pubsub.publisher"
  project = var.project_id
  
  members = [
    google_logging_folder_sink.folder_logs_sink.writer_identity,
  ]
}

# 5. Création du service account pour le folder
resource "google_service_account" "folder_logs_subscriber" {
  account_id   = local.service_account_name
  display_name = "Service Account pour logs folder ${var.folder_id}"
  description  = "Service Account pour souscrire aux logs du folder et sous-folders"
  project      = var.project_id
}

# 6. Permissions du service account sur le topic
resource "google_pubsub_topic_iam_binding" "folder_service_account_subscriber_topic" {
  topic = google_pubsub_topic.folder_logs_topic.name
  role  = "roles/pubsub.subscriber"
  project = var.project_id
  
  members = [
    "serviceAccount:${google_service_account.folder_logs_subscriber.email}",
  ]
}

# 7. Permissions du service account sur la subscription
resource "google_pubsub_subscription_iam_binding" "folder_service_account_subscriber_subscription" {
  subscription = google_pubsub_subscription.folder_logs_subscription.name
  role         = "roles/pubsub.subscriber"
  project      = var.project_id
  
  members = [
    "serviceAccount:${google_service_account.folder_logs_subscriber.email}",
  ]
}

# 8. Permissions supplémentaires pour les opérations de lecture/description
resource "google_pubsub_topic_iam_binding" "folder_service_account_viewer_topic" {
  topic = google_pubsub_topic.folder_logs_topic.name
  role  = "roles/pubsub.viewer"
  project = var.project_id
  
  members = [
    "serviceAccount:${google_service_account.folder_logs_subscriber.email}",
  ]
}

resource "google_pubsub_subscription_iam_binding" "folder_service_account_viewer_subscription" {
  subscription = google_pubsub_subscription.folder_logs_subscription.name
  role         = "roles/pubsub.viewer"
  project      = var.project_id
  
  members = [
    "serviceAccount:${google_service_account.folder_logs_subscriber.email}",
  ]
}

# 9. Permissions au niveau du projet pour les opérations générales
resource "google_project_iam_member" "folder_service_account_pubsub_viewer" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.folder_logs_subscriber.email}"
}

# 10. Génération de la clé du service account
resource "google_service_account_key" "folder_logs_subscriber_key" {
  service_account_id = google_service_account.folder_logs_subscriber.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Sauvegarde de la clé dans un fichier local
resource "local_file" "folder_service_account_key" {
  content  = base64decode(google_service_account_key.folder_logs_subscriber_key.private_key)
  filename = "${local.service_account_name}-key.json"
  
  file_permission = "0600"
}

# 11. Création du bucket GCS pour les logs du folder
resource "google_storage_bucket" "folder_logs_bucket" {
  name          = local.bucket_name
  location      = var.bucket_location
  storage_class = var.bucket_storage_class
  project       = var.project_id
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
    purpose     = "folder-log-storage"
    environment = var.environment
    folder_id   = var.folder_id
  }
}

# 12. Création du sink de logging vers GCS pour le folder
resource "google_logging_folder_sink" "folder_logs_gcs_sink" {
  name   = local.gcs_sink_name
  folder = var.folder_id
  
  destination = "storage.googleapis.com/${google_storage_bucket.folder_logs_bucket.name}"
  
  filter = local.folder_log_filter
  
  description = "Sink logs vers GCS pour folder ${var.folder_id} - tous projets et sous-folders"
  
  # Inclure les enfants (sous-folders et projets)
  include_children = true
}

# 13. Permissions IAM pour le sink GCS folder (writer identity)
resource "google_storage_bucket_iam_binding" "folder_logs_gcs_sink_writer" {
  bucket = google_storage_bucket.folder_logs_bucket.name
  role   = "roles/storage.objectCreator"
  
  members = [
    google_logging_folder_sink.folder_logs_gcs_sink.writer_identity,
  ]
}

# Outputs pour le folder
output "folder_id" {
  description = "ID du folder GCP"
  value       = var.folder_id
}

output "folder_topic_name" {
  description = "Nom du topic Pub/Sub pour le folder"
  value       = google_pubsub_topic.folder_logs_topic.name
}

output "folder_subscription_name" {
  description = "Nom de la subscription pour le folder"
  value       = google_pubsub_subscription.folder_logs_subscription.name
}

output "folder_sink_name" {
  description = "Nom du sink de logging pour le folder"
  value       = google_logging_folder_sink.folder_logs_sink.name
}

output "folder_service_account_email" {
  description = "Email du service account pour le folder"
  value       = google_service_account.folder_logs_subscriber.email
}

output "folder_service_account_key_file" {
  description = "Fichier de clé du service account pour le folder"
  value       = local_file.folder_service_account_key.filename
}

output "folder_writer_identity" {
  description = "Writer identity du sink pour le folder"
  value       = google_logging_folder_sink.folder_logs_sink.writer_identity
}

output "folder_bucket_name" {
  description = "Nom du bucket GCS pour le folder"
  value       = google_storage_bucket.folder_logs_bucket.name
}

output "folder_bucket_url" {
  description = "URL du bucket GCS pour le folder"
  value       = google_storage_bucket.folder_logs_bucket.url
}

output "folder_gcs_sink_name" {
  description = "Nom du sink vers GCS pour le folder"
  value       = google_logging_folder_sink.folder_logs_gcs_sink.name
}

output "folder_gcs_sink_writer_identity" {
  description = "Writer identity du sink GCS pour le folder"
  value       = google_logging_folder_sink.folder_logs_gcs_sink.writer_identity
}

output "folder_log_filter_used" {
  description = "Filtre de log utilisé pour le folder"
  value       = local.folder_log_filter
}

output "folder_config_file" {
  description = "Fichier de configuration utilisé pour le folder"
  value       = var.config_file
}

output "folder_config_file_status" {
  description = "Statut du fichier de configuration pour le folder"
  value = local.config_exists ? "Fichier ${var.config_file} trouvé et utilisé" : "Fichier ${var.config_file} non trouvé, configuration par défaut utilisée"
}

output "folder_test_commands" {
  description = "Commandes pour tester la configuration du folder"
  value = <<-EOT
    # Test basique Pub/Sub pour le folder
    gcloud pubsub subscriptions pull ${google_pubsub_subscription.folder_logs_subscription.name} --limit=10 --auto-ack --project=${var.project_id}
    
    # Test avec impersonation du service account
    gcloud pubsub subscriptions pull ${google_pubsub_subscription.folder_logs_subscription.name} --limit=10 --auto-ack --project=${var.project_id} --impersonate-service-account=${google_service_account.folder_logs_subscriber.email}
    
    # Vérifier les logs dans le bucket GCS
    gsutil ls gs://${google_storage_bucket.folder_logs_bucket.name}/
    
    # Test avec la clé directement
    export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/${local_file.folder_service_account_key.filename}
    gcloud auth activate-service-account --key-file=${local_file.folder_service_account_key.filename}
    gcloud pubsub subscriptions describe ${google_pubsub_subscription.folder_logs_subscription.name} --project=${var.project_id} --format="yaml(name, topic, filter)"
  EOT
}

output "folder_architecture_summary" {
  description = "Résumé de l'architecture de logging pour le folder"
  value = <<-EOT
    Architecture de logging déployée pour le folder ${var.folder_id}:
    
    📊 Portée:
    - Folder racine: ${var.folder_id}
    - Tous les sous-folders récursivement
    - Tous les projets dans le folder et sous-folders
    - Nouveaux projets automatiquement inclus
    
    📊 Sources de logs:
    - Admin Activity logs (cloudaudit.googleapis.com/activity)
    - System Event logs (cloudaudit.googleapis.com/system_event)
    - Policy logs (cloudaudit.googleapis.com/policy)
    - Logs avec severity >= WARNING
    
    🎯 Destinations:
    1. Pub/Sub Topic: ${google_pubsub_topic.folder_logs_topic.name}
       - Subscription: ${google_pubsub_subscription.folder_logs_subscription.name}
       - Service Account: ${google_service_account.folder_logs_subscriber.email}
       
    2. GCS Bucket: ${google_storage_bucket.folder_logs_bucket.name}
       - Location: ${var.bucket_location}
       - Storage Class: ${var.bucket_storage_class}
       - Rétention: ${var.log_retention_days} jours
    
    🔐 Sécurité:
    - Writer identities uniques pour chaque sink
    - Service account dédié avec permissions minimales
    - Chiffrement des logs en transit et au repos
    - Scope limité au folder spécifié
    
    ⚡ Performance:
    - Ack deadline: ${local.ack_deadline_seconds} secondes
    - Configuration JSON: ${var.config_file}
    ${var.enable_versioning ? "- Versioning du bucket activé" : "- Versioning du bucket désactivé"}
  EOT
}

output "folder_troubleshooting_commands" {
  description = "Commandes pour diagnostiquer les permissions du folder"
  value = <<-EOT
    # Vérifier si le service account existe
    gcloud iam service-accounts list --filter="email:${google_service_account.folder_logs_subscriber.email}" --project=${var.project_id}
    
    # Vérifier les permissions du service account
    gcloud projects get-iam-policy ${var.project_id} --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:${google_service_account.folder_logs_subscriber.email}"
    
    # Vérifier les permissions sur le topic
    gcloud pubsub topics get-iam-policy ${google_pubsub_topic.folder_logs_topic.name} --project=${var.project_id}
    
    # Vérifier les permissions sur la subscription
    gcloud pubsub subscriptions get-iam-policy ${google_pubsub_subscription.folder_logs_subscription.name} --project=${var.project_id}
    
    # Vérifier les permissions sur le bucket GCS
    gsutil iam get gs://${google_storage_bucket.folder_logs_bucket.name}
    
    # Vérifier les sinks de logging au niveau folder
    gcloud logging sinks list --folder=${var.folder_id}
    gcloud logging sinks describe ${google_logging_folder_sink.folder_logs_sink.name} --folder=${var.folder_id}
    gcloud logging sinks describe ${google_logging_folder_sink.folder_logs_gcs_sink.name} --folder=${var.folder_id}
    
    # Tester l'écriture dans le bucket (nécessite des permissions)
    echo "test log entry from folder ${var.folder_id}" | gsutil cp - gs://${google_storage_bucket.folder_logs_bucket.name}/test-$(date +%s).txt
    
    # Lister les projets du folder pour vérifier la portée
    gcloud projects list --filter="parent.id:${var.folder_id}" --format="value(projectId)"
  EOT
}
