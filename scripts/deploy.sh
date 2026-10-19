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

echo "Vérification HTTP..."
curl --fail --retry 10 --retry-delay 2 \
  --retry-connrefused -I http://localhost

echo "DEPLOYMENT SUCCESS"
