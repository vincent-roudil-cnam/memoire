# Configuration Terraform pour les logs Pub/Sub
# Équivalent du script fix_config_pubsub_log

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Variables
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
  default     = "log_config.json"
}

variable "filter_type" {
  description = "Type de filtre à utiliser (default, storage_only, compute_only, all_audit, storage_and_compute)"
  type        = string
  default     = "default"
}

# Lire la configuration depuis le fichier JSON
locals {
  # Vérifier si le fichier existe, sinon utiliser des valeurs par défaut
  config_exists = fileexists(var.config_file)
  
  # Configuration par défaut si le fichier n'existe pas
  default_config = {
    ack_deadline_seconds = 600
    description = "Configuration par défaut des filtres pour les logs d'audit GCP"
    excluded_principals = [
      "prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com"
    ]
    monitored_actions = [
      "get",
      "list", 
      "read",
      "describe",
      "search",
      "lookup", 
      "query",
      "testIamPermissions"
    ]
    log_types = [
      "cloudaudit.googleapis.com/activity",
      "cloudaudit.googleapis.com/system_event",
      "cloudaudit.googleapis.com/policy"
    ]
    severity_levels = [
      "DEFAULT",
      "DEBUG", 
      "INFO",
      "NOTICE",
      "WARNING",
      "ERROR",
      "CRITICAL",
      "ALERT",
      "EMERGENCY"
    ]
    filters = {
      default = "((logName:\"logs/cloudaudit.googleapis.com%2Factivity\" OR logName:\"logs/cloudaudit.googleapis.com%2Fsystem_event\" OR logName:\"logs/cloudaudit.googleapis.com%2Fpolicy\") AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\")) OR (severity >= \"WARNING\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      storage_only = "resource.type=\"gcs_bucket\" AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      compute_only = "resource.type=\"gce_instance\" AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      all_audit = "logName:\"logs/cloudaudit.googleapis.com%2Factivity\" AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      storage_and_compute = "(resource.type=\"gcs_bucket\" OR resource.type=\"gce_instance\") AND (protoPayload.methodName:(\"get\" OR \"list\" OR \"read\" OR \"describe\" OR \"search\" OR \"lookup\" OR \"query\" OR \"testIamPermissions\") OR protoPayload.methodName=~\".*\\.get.*\" OR protoPayload.methodName=~\".*\\.list.*\" OR protoPayload.methodName=~\".*\\.read.*\" OR protoPayload.methodName=~\".*\\.describe.*\" OR protoPayload.methodName=~\".*\\.search.*\" OR protoPayload.methodName=~\".*\\.lookup.*\" OR protoPayload.methodName=~\".*\\.query.*\" OR protoPayload.methodName=~\".*testIamPermissions.*\") AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      warning_and_above = "severity >= \"WARNING\" AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
      error_and_above = "severity >= \"ERROR\" AND NOT (protoPayload.authenticationInfo.principalEmail=\"prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com\")"
    }
  }
  
  config_data = local.config_exists ? jsondecode(file(var.config_file)) : local.default_config
  
  # Noms des ressources
  prefix = var.prefix != "" ? var.prefix : "${var.project_id}"
  topic_name = "${local.prefix}-logs-topic"
  subscription_name = "${local.prefix}-logs-sub"
  sink_name = "${local.prefix}-logs-sink"
  gcs_sink_name = "${local.prefix}-logs-gcs-sink"
  bucket_name = "${local.prefix}-logs-bucket"
  service_account_name = "${local.prefix}-sa-log"
  
  # Filtre par défaut pour Admin Activity, System Event et Policy + severity >= WARNING
  default_log_filter = <<-EOT
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
  
  # Utiliser le filtre depuis le fichier de configuration ou le filtre par défaut
  log_filter = var.filter_type == "default" ? local.default_log_filter : lookup(local.config_data.filters, var.filter_type, local.default_log_filter)
  ack_deadline_seconds = local.config_data.ack_deadline_seconds
}

# Configuration du provider avec gestion des métadonnées
provider "google" {
  project = var.project_id
  # En Cloud Shell, utiliser les métadonnées de l'instance
  credentials = null
}

# Note: Les APIs sont supposées déjà activées
# Si ce n'est pas le cas, activez-les manuellement :
# gcloud services enable pubsub.googleapis.com logging.googleapis.com iam.googleapis.com --project=win-windata-0-sbx

# 1. Création du topic Pub/Sub
resource "google_pubsub_topic" "logs_topic" {
  name = local.topic_name
}

# 2. Création de la subscription
resource "google_pubsub_subscription" "logs_subscription" {
  name  = local.subscription_name
  topic = google_pubsub_topic.logs_topic.name
  
  ack_deadline_seconds = local.ack_deadline_seconds
}

# 3. Création du sink de logging
resource "google_logging_project_sink" "logs_sink" {
  name = local.sink_name
  
  destination = "pubsub.googleapis.com/projects/${var.project_id}/topics/${google_pubsub_topic.logs_topic.name}"
  
  filter = local.log_filter
  
  description = "Sink logs pour Admin Activity, System Event et Policy - projet ${var.project_id}"
  
  unique_writer_identity = true
}

# 4. Permissions IAM pour le sink (writer identity)
resource "google_pubsub_topic_iam_binding" "logs_sink_publisher" {
  topic = google_pubsub_topic.logs_topic.name
  role  = "roles/pubsub.publisher"
  
  members = [
    google_logging_project_sink.logs_sink.writer_identity,
  ]
}

# 5. Création du service account
resource "google_service_account" "logs_subscriber" {
  account_id   = local.service_account_name
  display_name = "Service Account pour souscription logs ${var.project_id}"
  description  = "Service Account pour souscrire au topic de logs"
}

# 6. Permissions du service account sur le topic
resource "google_pubsub_topic_iam_binding" "service_account_subscriber_topic" {
  topic = google_pubsub_topic.logs_topic.name
  role  = "roles/pubsub.subscriber"
  
  members = [
    "serviceAccount:${google_service_account.logs_subscriber.email}",
  ]
}

# 7. Permissions du service account sur la subscription
resource "google_pubsub_subscription_iam_binding" "service_account_subscriber_subscription" {
  subscription = google_pubsub_subscription.logs_subscription.name
  role         = "roles/pubsub.subscriber"
  
  members = [
    "serviceAccount:${google_service_account.logs_subscriber.email}",
  ]
}

# 8. Permissions supplémentaires pour les opérations de lecture/description
resource "google_pubsub_topic_iam_binding" "service_account_viewer_topic" {
  topic = google_pubsub_topic.logs_topic.name
  role  = "roles/pubsub.viewer"
  
  members = [
    "serviceAccount:${google_service_account.logs_subscriber.email}",
  ]
}

resource "google_pubsub_subscription_iam_binding" "service_account_viewer_subscription" {
  subscription = google_pubsub_subscription.logs_subscription.name
  role         = "roles/pubsub.viewer"
  
  members = [
    "serviceAccount:${google_service_account.logs_subscriber.email}",
  ]
}

# 9. Permissions au niveau du projet pour les opérations générales
resource "google_project_iam_member" "service_account_pubsub_viewer" {
  project = var.project_id
  role    = "roles/pubsub.viewer"
  member  = "serviceAccount:${google_service_account.logs_subscriber.email}"
}

# 10. Génération de la clé du service account
resource "google_service_account_key" "logs_subscriber_key" {
  service_account_id = google_service_account.logs_subscriber.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# Sauvegarde de la clé dans un fichier local
resource "local_file" "service_account_key" {
  content  = base64decode(google_service_account_key.logs_subscriber_key.private_key)
  filename = "${local.service_account_name}-key.json"
  
  file_permission = "0600"
}

# 1bis. Création du bucket GCS pour les logs
resource "google_storage_bucket" "logs_bucket" {
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
    purpose     = "log-storage"
    environment = var.environment
    project     = var.project_id
  }
}

# 3bis. Création du sink de logging vers GCS
resource "google_logging_project_sink" "logs_gcs_sink" {
  name = local.gcs_sink_name
  
  destination = "storage.googleapis.com/${google_storage_bucket.logs_bucket.name}"
  
  filter = local.log_filter
  
  description = "Sink logs vers GCS pour Admin Activity, System Event et Policy - projet ${var.project_id}"
  
  unique_writer_identity = true
}

# 4bis. Permissions IAM pour le sink GCS (writer identity)
resource "google_storage_bucket_iam_binding" "logs_gcs_sink_writer" {
  bucket = google_storage_bucket.logs_bucket.name
  role   = "roles/storage.objectCreator"
  
  members = [
    google_logging_project_sink.logs_gcs_sink.writer_identity,
  ]
}

# Variables supplémentaires pour le bucket GCS
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

# Outputs pour informations
output "project_id" {
  description = "ID du projet GCP"
  value       = var.project_id
}

output "topic_name" {
  description = "Nom du topic Pub/Sub"
  value       = google_pubsub_topic.logs_topic.name
}

output "subscription_name" {
  description = "Nom de la subscription"
  value       = google_pubsub_subscription.logs_subscription.name
}

output "sink_name" {
  description = "Nom du sink de logging"
  value       = google_logging_project_sink.logs_sink.name
}

output "service_account_email" {
  description = "Email du service account"
  value       = google_service_account.logs_subscriber.email
}

output "service_account_key_file" {
  description = "Fichier de clé du service account"
  value       = local_file.service_account_key.filename
}

output "writer_identity" {
  description = "Writer identity du sink"
  value       = google_logging_project_sink.logs_sink.writer_identity
}

output "bucket_name" {
  description = "Nom du bucket GCS"
  value       = google_storage_bucket.logs_bucket.name
}

output "bucket_url" {
  description = "URL du bucket GCS"
  value       = google_storage_bucket.logs_bucket.url
}

output "gcs_sink_name" {
  description = "Nom du sink vers GCS"
  value       = google_logging_project_sink.logs_gcs_sink.name
}

output "gcs_sink_writer_identity" {
  description = "Writer identity du sink GCS"
  value       = google_logging_project_sink.logs_gcs_sink.writer_identity
}

output "test_commands" {
  description = "Commandes pour tester la configuration"
  value = <<-EOT
    # Test basique Pub/Sub
    gcloud pubsub subscriptions pull ${google_pubsub_subscription.logs_subscription.name} --limit=5 --auto-ack --project=${var.project_id}
    
    # Test avec impersonation du service account
    gcloud pubsub subscriptions pull ${google_pubsub_subscription.logs_subscription.name} --limit=5 --auto-ack --project=${var.project_id} --impersonate-service-account=${google_service_account.logs_subscriber.email}
    
    # Vérifier les logs dans le bucket GCS
    gsutil ls gs://${google_storage_bucket.logs_bucket.name}/
    
    # Lister les fichiers de logs récents dans GCS
    gsutil ls -l gs://${google_storage_bucket.logs_bucket.name}/ | head -10
    
    # Test avec la clé directement
    export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/${local_file.service_account_key.filename}
    gcloud auth activate-service-account --key-file=${local_file.service_account_key.filename}
    gcloud pubsub subscriptions describe ${google_pubsub_subscription.logs_subscription.name} --project=${var.project_id} --format="yaml(name, topic, filter)"
  EOT
}

output "troubleshooting_commands" {
  description = "Commandes pour diagnostiquer les permissions"
  value = <<-EOT
    # Vérifier si le service account existe
    gcloud iam service-accounts list --filter="email:${google_service_account.logs_subscriber.email}" --project=${var.project_id}
    
    # Vérifier les permissions du service account
    gcloud projects get-iam-policy ${var.project_id} --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:${google_service_account.logs_subscriber.email}"
    
    # Vérifier les permissions sur le topic
    gcloud pubsub topics get-iam-policy ${google_pubsub_topic.logs_topic.name} --project=${var.project_id}
    
    # Vérifier les permissions sur la subscription
    gcloud pubsub subscriptions get-iam-policy ${google_pubsub_subscription.logs_subscription.name} --project=${var.project_id}
    
    # Vérifier les permissions sur le bucket GCS
    gsutil iam get gs://${google_storage_bucket.logs_bucket.name}
    
    # Vérifier les sinks de logging
    gcloud logging sinks list --project=${var.project_id}
    gcloud logging sinks describe ${google_logging_project_sink.logs_sink.name} --project=${var.project_id}
    gcloud logging sinks describe ${google_logging_project_sink.logs_gcs_sink.name} --project=${var.project_id}
    
    # Tester l'écriture dans le bucket (nécessite des permissions)
    echo "test log entry" | gsutil cp - gs://${google_storage_bucket.logs_bucket.name}/test-$(date +%s).txt
  EOT
}

output "architecture_summary" {
  description = "Résumé de l'architecture de logging"
  value = <<-EOT
    Architecture de logging déployée:
    
    📊 Sources de logs:
    - Admin Activity logs (cloudaudit.googleapis.com/activity)
    - System Event logs (cloudaudit.googleapis.com/system_event)
    - Policy logs (cloudaudit.googleapis.com/policy)
    - Logs avec severity >= WARNING
    
    🎯 Destinations:
    1. Pub/Sub Topic: ${google_pubsub_topic.logs_topic.name}
       - Subscription: ${google_pubsub_subscription.logs_subscription.name}
       - Service Account: ${google_service_account.logs_subscriber.email}
       
    2. GCS Bucket: ${google_storage_bucket.logs_bucket.name}
       - Location: ${var.bucket_location}
       - Storage Class: ${var.bucket_storage_class}
       - Rétention: ${var.log_retention_days} jours
    
    🔐 Sécurité:
    - Writer identities uniques pour chaque sink
    - Service account dédié avec permissions minimales
    - Chiffrement des logs en transit et au repos
    - Chiffrement par défaut Google
    
    ⚡ Performance:
    - Ack deadline: ${local.ack_deadline_seconds} secondes
    - Timeout des commandes: 30 secondes
    ${var.enable_versioning ? "- Versioning du bucket activé" : "- Versioning du bucket désactivé"}
  EOT
}

output "log_filter_used" {
  description = "Filtre de log utilisé"
  value       = local.log_filter
}

output "filter_explanation" {
  description = "Explication du filtre utilisé"
  value = <<-EOT
    Filtre configuré pour capturer:
    
    1. Logs d'audit spécifiques:
       - Admin Activity logs (cloudaudit.googleapis.com/activity)
       - System Event logs (cloudaudit.googleapis.com/system_event)  
       - Policy logs (cloudaudit.googleapis.com/policy)
       
       Actions incluses pour les logs d'audit:
       - get: Récupération d'objets spécifiques
       - list: Énumération des ressources
       - read/describe: Consultation de métadonnées
       - search/lookup: Recherche de ressources
       - query: Interrogation active
       - testIamPermissions: Vérification des autorisations
    
    2. Tous les logs avec severity >= WARNING:
       - WARNING: Avertissements
       - ERROR: Erreurs
       - CRITICAL: Erreurs critiques
       - ALERT: Alertes
       - EMERGENCY: Urgences
    
    Exclusions:
    - Service account Prisma Cloud: prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com
  EOT
}

output "config_file" {
  description = "Fichier de configuration utilisé"
  value       = var.config_file
}

output "config_file_status" {
  description = "Statut du fichier de configuration"
  value = local.config_exists ? "Fichier ${var.config_file} trouvé et utilisé" : "Fichier ${var.config_file} non trouvé, configuration par défaut utilisée"
}
