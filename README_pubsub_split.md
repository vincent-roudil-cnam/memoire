# Guide de déploiement des configurations Pub/Sub pour les logs GCP

Ce guide explique comment utiliser les deux configurations Terraform pour le logging GCP.

## 📋 Fichiers créés

### Configuration Folder
- `pubsub_logs_config_folder.tf` - Configuration pour folder et sous-folders récursivement
- `terraform.tfvars.folder.example` - Exemple de variables pour folder

### Configuration Project
- `pubsub_logs_config_project.tf` - Configuration pour project spécifique avec services détectés
- `terraform.tfvars.project.example` - Exemple de variables pour project

## 🎯 Différences principales

| Aspect | Configuration Folder | Configuration Project |
|--------|---------------------|----------------------|
| **Scope** | Folder + tous sous-folders et projets | Project spécifique uniquement |
| **Sink Type** | `google_logging_folder_sink` | `google_logging_project_sink` |
| **Filtre** | Standard pour tous les projets | Dynamique basé sur les services détectés |
| **Fichier JSON** | `json` | `{project_id}_filter.json` |
| **Nouveaux projets** | Automatiquement inclus | Nécessite reconfiguration |
| **Services** | Filtre générique | Filtre spécifique par service |

## 🚀 Utilisation

### 1. Configuration Folder (Recommandée pour organisations)

```bash
# 1. Préparer le fichier de variables
cp terraform.tfvars.folder.example terraform.tfvars.folder
# Éditer le fichier avec vos valeurs

# 2. Initialiser Terraform
terraform init

# 3. Planifier le déploiement
terraform plan -var-file="terraform.tfvars.folder"

# 4. Déployer
terraform apply -var-file="terraform.tfvars.folder"
```

#### Variables importantes pour folder:
```hcl
folder_id = "123456789"          # ID du folder racine
organization_id = "987654321"    # ID de l'organisation
project_id = "logging-project"   # Projet où créer les ressources Pub/Sub
prefix = "folder-logs"           # Préfixe pour les ressources
config_file = "json"             # Nom du fichier de config JSON
```

### 2. Configuration Project (Recommandée pour projets spécifiques)

```bash
# 1. Détecter les services du projet
./count_gcp_resources.sh my-project-id true

# 2. Préparer le fichier de variables
cp terraform.tfvars.project.example terraform.tfvars.project
# Éditer avec les services détectés

# 3. Optionnel: Générer un filtre dynamique
./generate_dynamic_filter.py my-project-id --services compute storage gke

# 4. Déployer
terraform init
terraform plan -var-file="terraform.tfvars.project"
terraform apply -var-file="terraform.tfvars.project"
```

#### Variables importantes pour project:
```hcl
project_id = "my-project"
detected_services = ["compute", "storage", "gke"]
filter_type = "all_services"     # ou "default", "compute", etc.
config_file = "my-project_filter.json"
```

## 🔧 Intégration avec les outils existants

### Workflow recommandé pour projects:

1. **Découverte des services:**
   ```bash
   ./count_gcp_resources.sh my-project-id true > resources.log
   ```

2. **Génération du filtre:**
   ```bash
   ./generate_dynamic_filter.py my-project-id --services compute storage gke --output my-project_filter.json
   ```

3. **Déploiement Terraform:**
   ```bash
   terraform apply -var="project_id=my-project-id" -var="detected_services=[\"compute\",\"storage\",\"gke\"]"
   ```

### Workflow recommandé pour folders:

1. **Identifier le folder:**
   ```bash
   gcloud resource-manager folders list --organization=YOUR_ORG_ID
   ```

2. **Lister les projets du folder:**
   ```bash
   gcloud projects list --filter="parent.id:FOLDER_ID"
   ```

3. **Déployer la configuration:**
   ```bash
   terraform apply -var="folder_id=FOLDER_ID" -var="organization_id=ORG_ID"
   ```

## 📊 Fichiers de sortie

### Configuration Folder
- **JSON de config**: `json` (nom simple)
- **Clé SA**: `folder-logs-sa-key.json`
- **Scope**: Tous les projets du folder + sous-folders

### Configuration Project  
- **JSON de config**: `{project_id}_filter.json` (nom dynamique)
- **Clé SA**: `{project_id}-sa-log-key.json`
- **Scope**: Project spécifique uniquement

## 🔍 Monitoring et tests

### Tests pour folder:
```bash
# Vérifier les logs de plusieurs projets
gcloud pubsub subscriptions pull folder-logs-sub --limit=10 --auto-ack

# Vérifier les projets couverts
gcloud projects list --filter="parent.id:FOLDER_ID"
```

### Tests pour project:
```bash
# Vérifier les logs spécifiques aux services
gcloud pubsub subscriptions pull my-project-logs-sub --limit=10 --auto-ack

# Vérifier les services détectés
./count_gcp_resources.sh my-project-id
```

## 🛡️ Sécurité

### Permissions requises:

**Pour folder:**
- `roles/logging.configWriter` au niveau folder
- `roles/resourcemanager.folderAdmin` 
- `roles/pubsub.admin` sur le projet de logging

**Pour project:**
- `roles/logging.configWriter` au niveau project
- `roles/pubsub.admin` sur le projet

## 📈 Performances

### Configuration Folder:
- **Avantages**: Scaling automatique, gestion centralisée
- **Inconvénients**: Volume de logs plus important, moins de granularité

### Configuration Project:
- **Avantages**: Filtrage précis, logs optimisés par service
- **Inconvénients**: Gestion individuelle, configuration par projet

## 🚨 Considérations importantes

1. **Coûts**: La configuration folder génère plus de logs (tous les projets)
2. **Maintenance**: La configuration project nécessite une maintenance par projet
3. **Nouveaux projets**: Seule la configuration folder les inclut automatiquement
4. **Granularité**: La configuration project offre plus de contrôle sur les services

## 📝 Exemples de déploiement

### Exemple 1: Organisation avec folder principal
```bash
# Configuration folder pour toute l'organisation
terraform apply -var="folder_id=123456789" -var="organization_id=987654321" -var="project_id=central-logging"
```

### Exemple 2: Projet spécifique avec services détectés
```bash
# 1. Détecter les services
./count_gcp_resources.sh my-ml-project

# 2. Générer le filtre
./generate_dynamic_filter.py my-ml-project --services compute storage vertexai bigquery

# 3. Déployer
terraform apply -var="project_id=my-ml-project" -var="detected_services=[\"compute\",\"storage\",\"vertexai\",\"bigquery\"]"
```

### Exemple 3: Déploiement hybride
```bash
# Folder pour la couverture générale
terraform apply -var-file="terraform.tfvars.folder"

# Project pour les projets critiques avec filtres spécifiques
terraform apply -var-file="terraform.tfvars.project"
```

## 🔄 Migration

### De l'ancien fichier vers les nouvelles configurations:

1. **Sauvegarder l'existant:**
   ```bash
   cp pubsub_logs_config.tf pubsub_logs_config.tf.backup
   ```

2. **Choisir la configuration appropriée:**
   - Folder: Pour couverture organisationnelle
   - Project: Pour contrôle granulaire

3. **Migrer les variables:**
   - Adapter les noms des variables
   - Mettre à jour les outputs

4. **Tester le déploiement:**
   ```bash
   terraform plan -var-file="terraform.tfvars.folder"
   ```

## 📞 Support et troubleshooting

### Logs de débogage:
```bash
# Activer les logs Terraform
export TF_LOG=DEBUG

# Vérifier les sinks créés
gcloud logging sinks list --folder=FOLDER_ID
gcloud logging sinks list --project=PROJECT_ID
```

### Problèmes courants:
1. **Permissions insuffisantes**: Vérifier les rôles IAM
2. **Ressources déjà existantes**: Utiliser `terraform import`
3. **Filtres invalides**: Tester avec `gcloud logging read`

---

**Note**: Ces configurations remplacent le fichier `pubsub_logs_config.tf` original et offrent plus de flexibilité selon vos besoins organisationnels.
