#!/usr/bin/env bash
set -euo pipefail

IMAGE="ghcr.io/dassierod/static-website:latest"
CONTAINER="static-website-prod"
OLD_IMAGE=""
OLD_RUNNING=false
DEPLOY_STARTED=false

check_http() {
    for i in $(seq 1 15); do
        if curl --fail --silent --output /dev/null \
            --max-time 3 http://localhost/; then
            return 0
        fi

        echo "Tentative $i/15 : serveur pas encore prêt"
        sleep 2
    done

    return 1
}

rollback() {
    echo "ÉCHEC DU DÉPLOIEMENT !"

    if [ "$DEPLOY_STARTED" != true ]; then
        echo "Ancien conteneur non remplacé."
        exit 1
    fi

    echo "Démarrage du rollback..."

    docker rm -f "$CONTAINER" 2>/dev/null || true

    if [ "$OLD_RUNNING" = true ] && [ -n "$OLD_IMAGE" ]; then
        if docker run -d \
            --name "$CONTAINER" \
            --restart unless-stopped \
            -p 80:80 \
            "$OLD_IMAGE"; then

            if check_http; then
                echo "ROLLBACK SUCCESS"
            else
                echo "ERREUR : ancienne version non accessible."
            fi
        else
            echo "ERREUR : impossible de restaurer l'ancien conteneur."
        fi
    else
        echo "Aucun ancien conteneur actif à restaurer."
    fi

    exit 1
}

trap rollback ERR

echo "=== DÉBUT DU DÉPLOIEMENT ==="

# Sauvegarder l'image actuelle
if docker container inspect "$CONTAINER" >/dev/null 2>&1; then
    OLD_IMAGE=$(docker inspect \
        --format '{{.Image}}' "$CONTAINER")

    if [ "$(docker inspect \
        --format '{{.State.Running}}' "$CONTAINER")" = true ]; then
        OLD_RUNNING=true
    fi

    echo "Ancienne image : $OLD_IMAGE"
fi

# Télécharger avant de toucher à la production
echo "Téléchargement de la nouvelle image..."
docker pull "$IMAGE"

# Remplacer le conteneur
DEPLOY_STARTED=true

echo "Arrêt de l'ancien conteneur..."
docker rm -f "$CONTAINER" 2>/dev/null || true

echo "Démarrage de la nouvelle version..."
docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    -p 80:80 \
    "$IMAGE"

# Vérification
echo "Vérification HTTP..."
check_http

trap - ERR

echo "DEPLOYMENT SUCCESS"
