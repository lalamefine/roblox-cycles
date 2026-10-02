#!/usr/bin/env bash
# Construit le jeu avec Rojo et le publie via Roblox Open Cloud.
# Usage : bash scripts/publish.sh test|prod
# Variables (ou fichier .env) : ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_TEST_PLACE_ID, ROBLOX_PROD_PLACE_ID
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
	set -a
	# shellcheck disable=SC1091
	source .env
	set +a
fi

target="${1:-test}"
case "$target" in
	test) place="${ROBLOX_TEST_PLACE_ID:?ROBLOX_TEST_PLACE_ID manquant}" ;;
	prod) place="${ROBLOX_PROD_PLACE_ID:?ROBLOX_PROD_PLACE_ID manquant}" ;;
	*) echo "Cible inconnue : $target (test ou prod)" >&2; exit 1 ;;
esac
: "${ROBLOX_API_KEY:?ROBLOX_API_KEY manquant}"
: "${ROBLOX_UNIVERSE_ID:?ROBLOX_UNIVERSE_ID manquant}"

mkdir -p build
rojo build -o build/place.rbxl

# On garde le corps de la réponse même en cas d'erreur : Roblox y explique la cause.
response_file=$(mktemp)
status=$(curl -sS -o "$response_file" -w "%{http_code}" -X POST \
	"https://apis.roblox.com/universes/v1/${ROBLOX_UNIVERSE_ID}/places/${place}/versions?versionType=Published" \
	-H "x-api-key: ${ROBLOX_API_KEY}" \
	-H "Content-Type: application/octet-stream" \
	--data-binary @build/place.rbxl)
response=$(cat "$response_file")
rm -f "$response_file"

if [ "$status" -lt 200 ] || [ "$status" -ge 300 ]; then
	echo "Échec de publication (HTTP $status) : $response" >&2
	if [ "$status" = "409" ]; then
		echo "Un 409 signifie en général que la création en équipe (Team Create) est active sur la place." >&2
	fi
	exit 1
fi

echo "Publié sur la place $target ($place) : $response"
