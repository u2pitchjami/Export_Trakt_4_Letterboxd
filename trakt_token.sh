#!/bin/bash
SCRIPT_DIR=$(dirname "$(realpath "$0")")
source ${SCRIPT_DIR}/.config.cfg

if [ -z "$CODE" ]; then
  echo -e "Follow this link to obtain the code:\n"
  echo "➡️  https://trakt.tv/oauth/authorize?response_type=code&client_id=${API_KEY}&redirect_uri=${REDIRECT_URL}"
else
  echo "🔄 Obtention du premier token..."
  
  RESPONSE=$(curl -s -X POST "https://api.trakt.tv/oauth/token" \
    -H "Content-Type: application/json" \
    -d @- <<EOF
{
  "code": "${CODE}",
  "client_id": "${API_KEY}",
  "client_secret": "${CLIENT_SECRET}",
  "redirect_uri": "${REDIRECT_URL}",
  "grant_type": "authorization_code"
}
EOF
)

  # Extraction des tokens depuis la réponse JSON
  ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
  REFRESH_TOKEN=$(echo "$RESPONSE" | jq -r '.refresh_token')

  if [[ "$ACCESS_TOKEN" != "null" && "$REFRESH_TOKEN" != "null" ]]; then
    echo "✅ Token reçu avec succès ! Mise à jour du fichier .config.cfg"
    
    # Met à jour le fichier de config avec les nouveaux tokens
    sed -i "s|ACCESS_TOKEN=.*|ACCESS_TOKEN=\"$ACCESS_TOKEN\"|" ${SCRIPT_DIR}/.config.cfg
    sed -i "s|REFRESH_TOKEN=.*|REFRESH_TOKEN=\"$REFRESH_TOKEN\"|" ${SCRIPT_DIR}/.config.cfg
    
    echo "🎉 Tu es maintenant authentifié !"
  else
    echo "❌ Erreur lors de la récupération du token. Vérifie ton code d'autorisation et tes clés API."
    echo "Réponse de l'API : $RESPONSE"
  fi
fi

