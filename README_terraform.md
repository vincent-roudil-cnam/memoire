# Guide d'utilisation du Terraform pour la configuration Pub/Sub Logs

## Prérequis

1. **Terraform installé** (version >= 1.0)
2. **Google Cloud SDK** (gcloud) installé et configuré
3. **Authentification GCP** configurée :
   ```bash
   gcloud auth application-default login
   ```

## Configuration

### 1. Préparer les variables

Copiez le fichier d'exemple et personnalisez-le :
```bash
cp terraform.tfvars.example terraform.tfvars
```

Éditez `terraform.tfvars` :
```hcl
project_id = "votre-project-id-gcp"
# prefix = "custom-prefix"  # Optionnel
```

### 2. Initialiser Terraform

```bash
terraform init
```

### 3. Planifier les changements

```bash
terraform plan
```

### 4. Appliquer la configuration

```bash
terraform apply
```

## Ressources créées

Le Terraform va créer :

1. **📡 Topic Pub/Sub** : `${prefix}-logs-topic`
2. **📥 Subscription** : `${prefix}-logs-sub`
3. **🔄 Logging Sink** : `${prefix}-logs-sink`
4. **👤 Service Account** : `${prefix}-sa-log`
5. **🔑 Clé du Service Account** : `${prefix}-sa-log-key.json`
6. **🛡️ Permissions IAM** appropriées

## Après déploiement

### Test de la configuration

Les commandes de test seront affichées dans les outputs :

```bash
# Afficher tous les outputs
terraform output

# Afficher les commandes de test
terraform output test_commands
```

### Exemple de test manuel

```bash
# Test basique
gcloud pubsub subscriptions pull ow-PROJECT_ID-logs-sub --limit=5 --auto-ack --project=PROJECT_ID

# Test avec service account
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/ow-PROJECT_ID-sa-log-key.json
gcloud auth activate-service-account --key-file=ow-PROJECT_ID-sa-log-key.json

# Test de description (nécessite les bonnes permissions)
gcloud pubsub subscriptions describe ow-PROJECT_ID-logs-sub --project=PROJECT_ID --format="yaml(name, topic, filter)"
```

## Résolution des problèmes de permissions

Si vous obtenez une erreur `PERMISSION_DENIED` comme :
```
ERROR: (gcloud.pubsub.subscriptions.describe) PERMISSION_DENIED: User not authorized to perform this action.
```

### Solution 1: Réappliquer le Terraform avec les nouvelles permissions

Le Terraform a été mis à jour pour inclure les permissions `pubsub.viewer` :

```bash
terraform apply
```

### Solution 2: Ajouter manuellement les permissions manquantes

```bash
# Ajouter le rôle viewer au service account
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:ow-PROJECT_ID-sa-log@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/pubsub.viewer"

# Ou sur des ressources spécifiques
gcloud pubsub topics add-iam-policy-binding ow-PROJECT_ID-logs-topic \
  --member="serviceAccount:ow-PROJECT_ID-sa-log@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/pubsub.viewer" \
  --project=PROJECT_ID
```

### Commandes de diagnostic

```bash
# Vérifier les permissions actuelles du service account
terraform output troubleshooting_commands
```

## Nettoyage

Pour supprimer toutes les ressources :

```bash
terraform destroy
```

## Équivalence avec le script bash

Ce Terraform remplace complètement le script `fix_config_pubsub_log` :

| Script Bash | Terraform Resource |
|-------------|-------------------|
| `gcloud services enable` | `google_project_service` |
| `gcloud pubsub topics create` | `google_pubsub_topic` |
| `gcloud pubsub subscriptions create` | `google_pubsub_subscription` |
| `gcloud logging sinks create` | `google_logging_project_sink` |
| `gcloud iam service-accounts create` | `google_service_account` |
| `gcloud iam service-accounts keys create` | `google_service_account_key` |
| Bindings IAM Publisher | `google_pubsub_topic_iam_binding` |
| Bindings IAM Subscriber | `google_pubsub_subscription_iam_binding` |
| Bindings IAM Viewer | `google_project_iam_member` |

## Avantages du Terraform

- ✅ **Idempotent** : Peut être exécuté plusieurs fois sans problème
- ✅ **État géré** : Suivi des ressources dans le state file
- ✅ **Planification** : Voir les changements avant application
- ✅ **Destruction propre** : Suppression ordonnée des ressources
- ✅ **Versioning** : Configuration versionnée avec Git
