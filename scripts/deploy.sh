#!/usr/bin/env bash
set -euo pipefail

IMAGE="ghcr.io/dassierod/static-website:latest"
CONTAINER="static-website-prod"

echo "Téléchargement de la nouvelle image..."
docker pull "$IMAGE"

echo "Arrêt de l'ancien conteneur..."
docker rm -f "$CONTAINER" 2>/dev/null || true

echo "Démarrage de la nouvelle version..."
docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -p 80:80 \
  "$IMAGE"

echo "Vérification HTTP avec plusieurs tentatives..."

SUCCESS=0

for i in $(seq 1 15); do
    if curl -fsS --max-time 3 http://localhost/ -o /dev/null; then
        SUCCESS=1
        break
    fi

    echo "Tentative $i/15 : serveur pas encore prêt"
    sleep 2
done

if [ "$SUCCESS" -ne 1 ]; then
    echo "ERREUR : le serveur ne répond pas"
    docker logs --tail 30 "$CONTAINER"
    exit 1
fi

echo "DEPLOYMENT SUCCESS"
