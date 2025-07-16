#!/usr/bin/env python3

import argparse
import json
import sys
from typing import List, Dict, Any

class DynamicFilterGenerator:
    """Générateur de filtres dynamiques basé sur les services détectés."""
    
    def __init__(self):
        # Mapping des services vers les types de ressources GCP
        self.service_mappings = {
            "compute": {
                "resource_types": ["gce_instance", "gce_disk", "gce_network"],
                "log_names": ["compute.googleapis.com"],
                "description": "Compute Engine (VMs, disques, réseaux)"
            },
            "storage": {
                "resource_types": ["gcs_bucket"],
                "log_names": ["storage.googleapis.com"],
                "description": "Cloud Storage (buckets)"
            },
            "gke": {
                "resource_types": ["k8s_cluster", "k8s_node", "k8s_pod"],
                "log_names": ["container.googleapis.com"],
                "description": "Google Kubernetes Engine"
            },
            "cloudsql": {
                "resource_types": ["cloudsql_database"],
                "log_names": ["cloudsql.googleapis.com"],
                "description": "Cloud SQL"
            },
            "functions": {
                "resource_types": ["cloud_function"],
                "log_names": ["cloudfunctions.googleapis.com"],
                "description": "Cloud Functions"
            },
            "vertexai": {
                "resource_types": ["aiplatform.googleapis.com"],
                "log_names": ["aiplatform.googleapis.com"],
                "description": "Vertex AI"
            },
            "firestore": {
                "resource_types": ["firestore.googleapis.com"],
                "log_names": ["firestore.googleapis.com"],
                "description": "Firestore"
            },
            "bigquery": {
                "resource_types": ["bigquery_dataset", "bigquery_table"],
                "log_names": ["bigquery.googleapis.com"],
                "description": "BigQuery"
            },
            "cloudrun": {
                "resource_types": ["cloud_run_revision"],
                "log_names": ["run.googleapis.com"],
                "description": "Cloud Run"
            },
            "iam": {
                "resource_types": ["service_account"],
                "log_names": ["iam.googleapis.com"],
                "description": "IAM Service Accounts"
            },
            "pubsub": {
                "resource_types": ["pubsub_topic", "pubsub_subscription"],
                "log_names": ["pubsub.googleapis.com"],
                "description": "Pub/Sub Topics and Subscriptions"
            }
        }
        
        # Actions autorisées pour les logs d'audit
        self.allowed_actions = [
            "get", "list", "read", "describe", "search", 
            "lookup", "query", "testIamPermissions"
        ]
        
        # Comptes à exclure
        self.excluded_principals = [
            "prisma-cloud-serv-owyee@prisma-306509.iam.gserviceaccount.com"
        ]

    def generate_service_filter(self, services: List[str]) -> str:
        """Génère un filtre pour les services spécifiés."""
        if not services:
            return self.generate_default_filter()
        
        resource_filters = []
        
        for service in services:
            if service in self.service_mappings:
                mapping = self.service_mappings[service]
                resource_types = mapping["resource_types"]
                
                # Créer un filtre pour ce service
                if len(resource_types) == 1:
                    resource_filter = f'resource.type="{resource_types[0]}"'
                else:
                    resource_parts = [f'resource.type="{rt}"' for rt in resource_types]
                    resource_filter = f'({" OR ".join(resource_parts)})'
                
                resource_filters.append(resource_filter)
        
        # Combiner tous les filtres de ressources
        if len(resource_filters) == 1:
            combined_resource_filter = resource_filters[0]
        else:
            combined_resource_filter = f'({" OR ".join(resource_filters)})'
        
        # Générer le filtre complet
        actions_filter = self.generate_actions_filter()
        exclusion_filter = self.generate_exclusion_filter()
        severity_filter = 'severity >= "WARNING"'
        
        filter_parts = [
            f'({combined_resource_filter} AND {actions_filter})',
            f'({severity_filter})'
        ]
        
        complete_filter = f'({" OR ".join(filter_parts)}) AND {exclusion_filter}'
        
        return complete_filter

    def generate_actions_filter(self) -> str:
        """Génère le filtre pour les actions autorisées."""
        action_patterns = []
        
        # Actions exactes
        exact_actions = ' OR '.join([f'"{action}"' for action in self.allowed_actions])
        action_patterns.append(f'protoPayload.methodName:({exact_actions})')
        
        # Patterns regex
        for action in self.allowed_actions:
            action_patterns.append(f'protoPayload.methodName=~".*\\\\.{action}.*"')
        
        return f'({" OR ".join(action_patterns)})'

    def generate_exclusion_filter(self) -> str:
        """Génère le filtre d'exclusion pour les comptes non désirés."""
        exclusions = []
        for principal in self.excluded_principals:
            exclusions.append(f'protoPayload.authenticationInfo.principalEmail="{principal}"')
        
        return f'NOT ({" OR ".join(exclusions)})'

    def generate_default_filter(self) -> str:
        """Génère le filtre par défaut pour tous les logs d'audit."""
        audit_logs = [
            'logName:"logs/cloudaudit.googleapis.com%2Factivity"',
            'logName:"logs/cloudaudit.googleapis.com%2Fsystem_event"',
            'logName:"logs/cloudaudit.googleapis.com%2Fpolicy"'
        ]
        
        actions_filter = self.generate_actions_filter()
        exclusion_filter = self.generate_exclusion_filter()
        severity_filter = 'severity >= "WARNING"'
        
        audit_filter = f'({" OR ".join(audit_logs)}) AND {actions_filter}'
        
        filter_parts = [
            f'({audit_filter})',
            f'({severity_filter})'
        ]
        
        complete_filter = f'({" OR ".join(filter_parts)}) AND {exclusion_filter}'
        
        return complete_filter

    def generate_config_file(self, project_id: str, services: List[str]) -> Dict[str, Any]:
        """Génère un fichier de configuration complet."""
        config = {
            "description": f"Configuration dynamique pour le projet {project_id}",
            "project_id": project_id,
            "detected_services": services,
            "ack_deadline_seconds": 600,
            "excluded_principals": self.excluded_principals,
            "monitored_actions": self.allowed_actions,
            "filters": {}
        }
        
        # Générer le filtre principal basé sur les services détectés
        if services:
            main_filter = self.generate_service_filter(services)
            config["filters"]["dynamic"] = main_filter
            
            # Générer des filtres spécifiques par service
            for service in services:
                if service in self.service_mappings:
                    service_filter = self.generate_service_filter([service])
                    config["filters"][f"{service}_only"] = service_filter
        
        # Ajouter le filtre par défaut
        config["filters"]["default"] = self.generate_default_filter()
        
        # Ajouter des filtres par niveau de sévérité
        config["filters"]["warning_and_above"] = f'severity >= "WARNING" AND {self.generate_exclusion_filter()}'
        config["filters"]["error_and_above"] = f'severity >= "ERROR" AND {self.generate_exclusion_filter()}'
        
        return config

    def print_filter_explanation(self, services: List[str]):
        """Affiche une explication des filtres générés."""
        print("🔍 EXPLICATION DES FILTRES GÉNÉRÉS")
        print("=" * 50)
        
        if services:
            print(f"📊 Services détectés: {', '.join(services)}")
            print()
            
            for service in services:
                if service in self.service_mappings:
                    mapping = self.service_mappings[service]
                    print(f"🎯 {service.upper()}:")
                    print(f"   Description: {mapping['description']}")
                    print(f"   Types de ressources: {', '.join(mapping['resource_types'])}")
                    print()
        
        print("✅ Actions surveillées:")
        for action in self.allowed_actions:
            print(f"   - {action}")
        
        print()
        print("❌ Comptes exclus:")
        for principal in self.excluded_principals:
            print(f"   - {principal}")
        
        print()
        print("📈 Niveaux de sévérité inclus:")
        print("   - WARNING et plus élevé")
        print("   - Tous les logs d'audit avec actions autorisées")


def main():
    parser = argparse.ArgumentParser(
        description="Générateur de filtres dynamiques pour les logs GCP",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples d'utilisation:
  %(prog)s my-project --services compute storage
  %(prog)s my-project --services gke bigquery --output custom_config.json
  %(prog)s my-project --explain
        """
    )
    
    parser.add_argument("project_id", help="ID du projet GCP")
    parser.add_argument("--services", nargs="*", 
                       choices=["compute", "storage", "gke", "cloudsql", "functions", "vertexai", "firestore", "bigquery", "cloudrun", "iam", "pubsub"],
                       help="Services détectés pour lesquels générer des filtres")
    parser.add_argument("--output", help="Fichier de sortie pour la configuration JSON")
    parser.add_argument("--filter-only", action="store_true", 
                       help="Afficher uniquement le filtre, sans la configuration complète")
    parser.add_argument("--explain", action="store_true",
                       help="Afficher une explication des filtres générés")
    
    args = parser.parse_args()
    
    generator = DynamicFilterGenerator()
    
    if args.explain:
        generator.print_filter_explanation(args.services or [])
        return
    
    if args.filter_only:
        # Afficher uniquement le filtre
        filter_str = generator.generate_service_filter(args.services or [])
        print(filter_str)
        return
    
    # Générer la configuration complète
    config = generator.generate_config_file(args.project_id, args.services or [])
    
    if args.output:
        # Sauvegarder dans un fichier
        with open(args.output, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)
        print(f"✅ Configuration sauvegardée dans {args.output}")
    else:
        # Afficher sur stdout
        print(json.dumps(config, indent=2, ensure_ascii=False))
    
    # Afficher un résumé
    print(f"\n📊 Configuration générée pour le projet: {args.project_id}")
    if args.services:
        print(f"🎯 Services inclus: {', '.join(args.services)}")
    print(f"🔧 Filtres disponibles: {', '.join(config['filters'].keys())}")


if __name__ == "__main__":
    main()
