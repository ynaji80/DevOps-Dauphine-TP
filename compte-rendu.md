## Partie 1 : Infrastructure as Code

1. Done.
2. Done.
3. Done.
4. Done.

5. Il existe un nouvel utilisateur : wordpress
6. Il existe 4 bases de données de type Système.

## Partie 2 : Docker

Wordpress dispose d'une image Docker officielle disponible sur [DockerHub](https://hub.docker.com/_/wordpress)

1. Done.

2. Lancer l'image docker et ouvrez un shell à l'intérieur de votre container:
   1. Quel est le répertoire courant du container (WORKDIR) ? /var/www/html
   2. Que contient le fichier `index.php` ? J'ai pas trouvé

3. Supprimez le container puis relancez en un en spécifiant un port binding (une correspondance de port).

   1. docker run -d -p 8080:80  --name=container-wordpress  wordpress

   2. Done.

   3. 
    WordPress not found in /var/www/html - copying now...
    Complete! WordPress has been successfully copied to /var/www/html
    AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 172.18.0.2. Set the 'ServerName' directive globally to suppress this message
    AH00558: apache2: Could not reliably determine the server's fully qualified domain name, using 172.18.0.2. Set the 'ServerName' directive globally to suppress this message
    [Thu Oct 05 08:10:33.946556 2023] [mpm_prefork:notice] [pid 1] AH00163: Apache/2.4.56 (Debian) PHP/8.0.30 configured -- resuming normal operations
    [Thu Oct 05 08:10:33.946685 2023] [core:notice] [pid 1] AH00094: Command line: 'apache2 -D FOREGROUND'

   4. Utilisez l'aperçu web pour afficher le résultat du navigateur qui se connecte à votre container wordpress
      1. Utiliser la fonction `Aperçu sur le web`
        ![web_preview](images/wordpress_preview.png)
      2. j'ai exposé sur 8080
      3. une page web

4. A partir de la documentation, remarquez les paramètres requis pour la configuration de la base de données.

5. Dans la partie 1 du TP (si pas déjà fait), nous allons créer cette base de donnée. Dans cette partie 2 nous allons créer une image docker qui utilise des valeurs spécifiques de paramètres pour la base de données.
   1. Done
   2. Done
   3. Done
   4. `echo $WORDPRESS_DB_PASSWORD` donne le mot de passe "root"

6. Pipeline d'Intégration Continue (CI):
   1. Créer un dépôt de type `DOCKER` sur artifact registry (si pas déjà fait, sinon utiliser celui appelé `website-tools`)
   2. Créer une configuration cloudbuild pour construire l'image docker et la publier sur le depôt Artifact Registry
   3. Envoyer (`submit`) le job sur Cloud Build et vérifier que l'image a bien été créée

## Partie 3 : Déployer Wordpress sur Cloud Run 🔥

Nous allons maintenant mettre les 2 parties précédentes ensemble.

Notre but, ne l'oublions pas est de déployer wordpress sur Cloud Run !

### Configurer l'adresse IP de la base MySQL utilisée par Wordpress

1. Rendez vous sur : https://console.cloud.google.com/sql/instances/main-instance/connections/summary?
   L'instance de base données dispose d'une `Adresse IP publique`. Nous allons nous servir de cette valeur pour configurer notre image docker Wordpress qui s'y connectera.

2. Reprendre le Dockerfile de la [Partie 2](#partie-2--docker) et le modifier pour que `WORDPRESS_DB_HOST` soit défini avec l'`Adresse IP publique` de notre instance de base de donnée.
3. Reconstruire notre image docker et la pousser sur notre Artifact Registry en utilisant cloud build

### Déployer notre image docker sur Cloud Run

1. Ajouter une ressource Cloud Run à votre code Terraform. Veiller à renseigner le bon tag de l'image docker que l'on vient de publier sur notre dépôt dans le champs `image` :

   ```hcl
   resource "google_cloud_run_service" "default" {
   name     = "serveur-wordpress"
   location = "us-central1"

   template {
      spec {
         containers {
         image = "us-docker.pkg.dev/cloudrun/container/hello"
         }
      }

      metadata {
         annotations = {
         "autoscaling.knative.dev/maxScale"      = "1000"
         "run.googleapis.com/cloudsql-instances" = "main-instance"
         "run.googleapis.com/client-name"        = "terraform"
         }
      }
   }

   traffic {
      percent         = 100
      latest_revision = true
   }
   }
   ```

   Afin d'autoriser tous les appareils à se connecter à notre Cloud Run, on définit les ressources :

   ```hcl
   data "google_iam_policy" "noauth" {
      binding {
         role = "roles/run.invoker"
         members = [
            "allUsers",
         ]
      }
   }

   resource "google_cloud_run_service_iam_policy" "noauth" {
      location    = google_cloud_run_service.default.location
      project     = google_cloud_run_service.default.project
      service     = google_cloud_run_service.default.name

      policy_data = data.google_iam_policy.noauth.policy_data
   }
   ```

   ☝️ Vous aurez besoin d'activer l'API : `run.googleapis.com` pour créer la ressource de type `google_cloud_run_service`. Faites en sorte que l'API soit activé avant de créer votre instance Cloud Run 😌

   Appliquer les changements sur votre projet gcp avec les commandes terraform puis rendez vous sur https://console.cloud.google.com/run pendant le déploiement.

2. Observer les journaux de Cloud Run (logs) sur : https://console.cloud.google.com/run/detail/us-central1/serveur-wordpress/logs.
   1. Véirifer la présence de l'entrée `No 'wp-config.php' found in /var/www/html, but 'WORDPRESS_...' variables supplied; copying 'wp-config-docker.php' (WORDPRESS_DB_HOST WORDPRESS_DB_PASSWORD WORDPRESS_DB_USER)`
   2. Au bout de 5 min, que se passe-t-il ? 🤯🤯🤯
   3. Regarder le resultat de votre commande `terraform apply` et observer les logs de Cloud Run
   4. Quelle est la raison de l'erreur ? Que faut-il changer dans les paramètre de notre ressource terraform `google_cloud_run_service` ?

3. A l'aide de la documentation terraform, d'internet ou de ChatGPT, ou même d'un certain TP 😌 faites en sorte que Cloud Run soit correctement configuré pour utiliser votre image Docker wordpress.

4. Autoriser toutes les adresses IP à se connecter à notre base MySQL (sous réserve d'avoir l'utilisateur et le mot de passe évidemment)
   1. Pour le faire, exécuter la commande
      ```bash
      gcloud sql instances patch main-instance \
      --authorized-networks=0.0.0.0/0
      ```

5. Accéder à notre Wordpress déployé 🚀
   1. Aller sur : https://console.cloud.google.com/run/detail/us-central1/serveur-wordpress/metrics?
   2. Cliquer sur l'URL de votre Cloud Run : similaire à https://serveur-wordpress-oreldffftq-uc.a.run.app
   3. Que voyez vous ? 🙈


## BONUS : Partie 4

1. Utiliser Cloud Build pour appliquer les changements d'infrastructure
2. Quelles critiques du TP pouvez vous faire ? Quels sont les éléments redondants de notre configuration ?
   1. Quels paramètres avons nous dû recopier plusieurs fois ?
   2. Comment pourrions nous faire pour ne pas avoir à les recopier ?
   3. Quels paramètres de la ressource Cloud Run peuvent être utilisés pour simplifier la gestion de notre application ?
   4. Créer une nouvelle ressource terraform de Cloud Run et appliquer lui les améliorations 😌