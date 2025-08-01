#!/bin/bash
##############################################################################
# Trakt → Letterboxd Export + BrainOps (avec notes via matching)
# Auteur : toi + ChatGPT
# Date   : 01/08/2025
##############################################################################

SCRIPT_DIR=$(dirname "$(realpath "$0")")
source "${SCRIPT_DIR}/.config.cfg"

mkdir -p "${APPDATA}/TEMP" "${DOSLOG}" "${BACKUP_DIR}" "${BRAIN_OPS}"
LOG="${DOSLOG}/trakt_export.log"

#######################################
# Rafraîchit le token OAuth2 si expiré
#######################################
refresh_access_token() {
    echo "🔄 Rafraîchissement du token Trakt..." | tee -a "${LOG}"
    
    RESPONSE=$(curl -s -w "%{http_code}" -o /tmp/trakt_token.json \
        -X POST "https://api.trakt.tv/oauth/token" \
        -H "Content-Type: application/json" \
        -d "{
            \"refresh_token\": \"${REFRESH_TOKEN}\",
            \"client_id\": \"${API_KEY}\",
            \"client_secret\": \"${API_SECRET}\",
            \"redirect_uri\": \"${REDIRECT_URI}\",
            \"grant_type\": \"refresh_token\"
        }")

    if [ "$RESPONSE" -eq 200 ]; then
        NEW_ACCESS_TOKEN=$(jq -r '.access_token' /tmp/trakt_token.json)
        NEW_REFRESH_TOKEN=$(jq -r '.refresh_token' /tmp/trakt_token.json)

        if [[ "$NEW_ACCESS_TOKEN" != "null" && "$NEW_REFRESH_TOKEN" != "null" ]]; then
            echo "✅ Token rafraîchi avec succès." | tee -a "${LOG}"
            sed -i "s|ACCESS_TOKEN=.*|ACCESS_TOKEN=\"$NEW_ACCESS_TOKEN\"|" "${SCRIPT_DIR}/.config.cfg"
            sed -i "s|REFRESH_TOKEN=.*|REFRESH_TOKEN=\"$NEW_REFRESH_TOKEN\"|" "${SCRIPT_DIR}/.config.cfg"
            source "${SCRIPT_DIR}/.config.cfg"
        fi
    else
        echo "❌ Erreur lors du rafraîchissement du token (HTTP $RESPONSE)" | tee -a "${LOG}"
        cat /tmp/trakt_token.json | tee -a "${LOG}"
        exit 1
    fi
}

#######################################
# Vérifie si le token est valide
#######################################
check_token_and_refresh() {
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -X GET "${API_URL}/users/me/history/movies" \
        -H "Content-Type: application/json" \
        -H "User-Agent: Export_Trakt_4_Letterboxd/1.0.0" \
        -H "trakt-api-key: ${API_KEY}" \
        -H "trakt-api-version: 2" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}")

    if [ "$HTTP_CODE" -eq 401 ]; then
        echo "⚠️ Token expiré ou invalide (HTTP 401)" | tee -a "${LOG}"
        refresh_access_token
    fi
}

#######################################
# Choix des endpoints selon option
#######################################
OPTION=$(echo "${1:-normal}" | tr '[:upper:]' '[:lower:]')

case $OPTION in
    complet)
        endpoints=(
            ratings/movies ratings/episodes
            history/movies history/shows history/episodes
            watchlist/movies watchlist/shows
        )
        ;;
    initial)
        endpoints=(ratings/movies watched/movies)
        ;;
    *)
        endpoints=(
            ratings/movies ratings/episodes
            history/movies history/shows history/episodes
            watchlist/movies watchlist/shows
        )
        ;;
esac

echo "📥 Mode $OPTION activé – récupération des endpoints..." | tee -a "${LOG}"

#######################################
# Récupération des données
#######################################
for endpoint in "${endpoints[@]}"; do
    check_token_and_refresh

    filename="${USERNAME}-${endpoint//\//_}.json"
    OUTPUT="${BACKUP_DIR}/${filename}"

    echo "➡️  $endpoint" | tee -a "${LOG}"
    curl -s -X GET "${API_URL}/users/me/${endpoint}" \
        -H "Content-Type: application/json" \
        -H "User-Agent: Export_Trakt_4_Letterboxd/1.0.0" \
        -H "trakt-api-key: ${API_KEY}" \
        -H "trakt-api-version: 2" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -o "$OUTPUT"

    if jq empty "$OUTPUT" 2>/dev/null; then
        echo "✅ ${endpoint} récupéré dans $OUTPUT" | tee -a "${LOG}"
    else
        echo "❌ Erreur JSON pour $endpoint" | tee -a "${LOG}"
    fi
done

#######################################
# Post-traitement avec injection des notes
#######################################
echo -e "tous les fichiers ont bien été récupérés\n Démarrage du retraitement" | tee -a "${LOG}"

if [ $OPTION == "complet" ]
	then
# compress backup folder
echo -e "Compression de la sauvegarde..." | tee -a "${LOG}"
tar -czvf ${BACKUP_DIR}.tar.gz ${BACKUP_DIR}
echo -e "Sauvegarde compressée: \e[32m${BACKUP_DIR}.tar.gz\e[0m\n" | tee -a "${LOG}"
echo -e "Voilà c'est fini, sauvegarde réalisée" | tee -a "${LOG}"
else
    if [ $OPTION == "initial" ]
      then
      cat ${BACKUP_DIR}/${USERNAME}-ratings_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .last_watched_at, (.rating // "")]|@csv' >> "${APPDATA}/TEMP/temp_rating.csv"
      cat ${BACKUP_DIR}/${USERNAME}-watched_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .last_watched_at, (.rating // "")]|@csv' >> "${APPDATA}/TEMP/temp.csv"
    else
      cat ${BACKUP_DIR}/${USERNAME}-ratings_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .watched_at, (.rating // "")]|@csv' >> "${APPDATA}/TEMP/temp_rating.csv"
      cat ${BACKUP_DIR}/${USERNAME}-ratings_episodes.json | jq -r '.[]|[.show.title, .show.year, .episode.title, .episode.season, .episode.number, .show.ids.imdb, .show.ids.tmdb, .watched_at, (.rating // "")]|@csv' >> "${APPDATA}/TEMP/temp_rating_episodes.csv"
      cat ${BACKUP_DIR}/${USERNAME}-history_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .watched_at, (.rating // "")]|@csv' >> "${APPDATA}/TEMP/temp.csv"
      cat ${BACKUP_DIR}/${USERNAME}-history_shows.json | jq -r '.[]|[.show.title, .show.year, .episode.title, .episode.season, .episode.number, .show.ids.imdb, .show.ids.tmdb, .watched_at, (.rating // "")]|@csv' >> "${APPDATA}/TEMP/temp_show.csv"
      cat ${BACKUP_DIR}/${USERNAME}-watchlist_movies.json | jq -r '.[]|[.type, .movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .listed_at]|@csv' >> "${APPDATA}/TEMP/temp_watchlist.csv"
      cat ${BACKUP_DIR}/${USERNAME}-watchlist_shows.json | jq -r '.[]|[.type, .show.title, .show.year, .show.ids.imdb, .show.ids.tmdb, .listed_at]|@csv' >> "${APPDATA}/TEMP/temp_watchlist.csv"
      #diff -u <(cut -d "," -f1,2,3,4 temp_rating.csv) <(cut -d "," -f1,2,3,4 temp.csv) | grep '^+' | sed 's/^+//' 
    fi   
    awk -F, '
    NR==FNR { key=$1 FS $2 FS $3 FS $4; note[key]=$6; next }
    {
        key=$1 FS $2 FS $3 FS $4;
        if (key in note) { print $0 "," note[key] } else { print $0 }
    }
' "${APPDATA}/TEMP/temp_rating.csv" "${APPDATA}/TEMP/temp.csv" > "${APPDATA}/TEMP/temp_with_notes.csv"

mv "${APPDATA}/TEMP/temp_with_notes.csv" "${APPDATA}/TEMP/temp.csv"


awk -F, '
    NR==FNR { key=$1 FS $2 FS $3 FS $4; note[key]=$9; next }
    {
        key=$1 FS $2 FS $3 FS $4;
        if (key in note) { print $0 "," note[key] } else { print $0 }
    }
' "${APPDATA}/TEMP/temp_rating_episodes.csv" "${APPDATA}/TEMP/temp_show.csv" > "${APPDATA}/TEMP/temp_show_with_notes.csv"

mv "${APPDATA}/TEMP/temp_show_with_notes.csv" "${APPDATA}/TEMP/temp_show.csv"
    

    if [[ -f "${APPDATA}/letterboxd_import.csv" ]]
        then
        echo -e "Fichier existant, nouveaux films à la suite" | tee -a "${LOG}"
    else
        echo -e "Génération du fichier letterboxd_import.csv" | tee -a "${LOG}"
        echo "Title, Year, imdbID, tmdbID, WatchedDate, Rating10" >> "${APPDATA}/letterboxd_import.csv"
    fi
    echo -e "Ajouts des données suivantes : " | tee -a "${LOG}"
    COUNTTEMP=$(cat "${APPDATA}/TEMP/temp.csv" | wc -l)
    for ((p=1; p<=$COUNTTEMP; p++))
    do
      LIGNETEMP=$(cat "${APPDATA}/TEMP/temp.csv" | head -$p | tail +$p)
      DEBUT=$(echo "$LIGNETEMP" | cut -d "," -f1,2,3,4)
      #echo "debut $DEBUT"
      DEBUTCOURT=$(echo "$LIGNETEMP" | cut -d "," -f1,2)
      MILIEU=$(echo "$LIGNETEMP" | cut -d "," -f5 | cut -d "T" -f1 | tr -d "\"")
      #echo "MILIEU $MILIEU"
      FIN=$(echo "$LIGNETEMP" | cut -d "," -f7)
     # echo "FIN $FIN"
      SCENEIN1=$(grep -e "^${DEBUT},${MILIEU}" ${APPDATA}/letterboxd_import.csv)
      
      #echo "SCENEIN1 $SCENEIN1"
      if [[ -n $SCENEIN1 ]]
        then
        FIN1=$(echo "$SCENEIN1" | cut -d "," -f6)
        #echo "fin1 $FIN1"
        SCENEIN2=$(grep -n "^${DEBUT},${MILIEU}" ${APPDATA}/letterboxd_import.csv | cut -d ":" -f 1)
        #echo "scenein2 $SCENEIN2"
        if [[ "${DEBUT},${MILIEU},${FIN}" == "${DEBUT},${MILIEU},${FIN1}" ]]
          then
          echo "Film : ${DEBUTCOURT} déjà présent dans le fichier d'import" | tee -a "${LOG}"
        else
          #FIN2=$(echo "$SCENEIN2" | cut -d "," -f6)
          if [[ -n $FIN1 ]]
            then
            sed -i ""$SCENEIN2"s/$FIN1/$FIN/" ${APPDATA}/letterboxd_import.csv
            else
            sed -i ""$SCENEIN2"s/$/$FIN/" ${APPDATA}/letterboxd_import.csv
            fi
          echo "Film : ${DEBUTCOURT} déjà présent mais ajout de la note $FIN" | tee -a "${LOG}"
        fi
      else
        echo "${DEBUT},${MILIEU},${FIN}"
        echo "${DEBUT},${MILIEU},${FIN}" | tee -a "${LOG}" >> "${APPDATA}/letterboxd_import.csv"
      fi  
    done
    #while IFS= read -r line; do
      
    #done < "./TEMP/temp.csv"
    cp ${APPDATA}/letterboxd_import.csv "$DOSCOPY/letterboxd_import.csv"
    echo " " | tee -a "${LOG}"
    echo -e "Fichier letterboxd_import.csv copié dans le dossier $DOSCOPY" | tee -a "${LOG}"
    echo -e "${BOLD}A intégrer à l'adresse suivante : https://letterboxd.com/import/ ${NC}" | tee -a "${LOG}"
    echo " " | tee -a "${LOG}"
    echo -e "${BOLD}N'oubliez pas de supprimer le ficher csv !!! ${NC}" | tee -a "${LOG}"

  #awk -F, 'BEGIN {OFS=","} {gsub(/"/, "", $1); $2=$2",NULL,NULL,NULL"}1' ${APPDATA}/TEMP/temp.csv > ${APPDATA}/TEMP/temp2.csv
# Nettoyage pour BrainOps : on supprime la colonne vide avant import
awk -F, 'BEGIN {OFS=","} {
    # Films : si 7 colonnes, on saute la 6e
    if (NF==7) print $1,$2,$3,$4,$5,$7
    else print $0
}' "${APPDATA}/TEMP/temp.csv" > "${APPDATA}/TEMP/temp2.csv"

awk -F, 'BEGIN {OFS=","} {
    # Séries : si 10 colonnes, on saute la 9e
    if (NF==10) print $1,$2,$3,$4,$5,$6,$7,$8,$10
    else print $0
}' "${APPDATA}/TEMP/temp_show.csv" > "${APPDATA}/TEMP/temp_show_clean.csv"

# Prépare les fichiers avec préfixe Movie/Show/Watchlist
sed -i 's/^/Movie,/; s/"//g' "${APPDATA}/TEMP/temp2.csv"
sed -i 's/^/Show,/; s/"//g' "${APPDATA}/TEMP/temp_show_clean.csv"
sed -i 's/"//g' "${APPDATA}/TEMP/temp_watchlist.csv"

# Copie vers BrainOps
# cat "${APPDATA}/TEMP/temp2.csv" >> "${BRAIN_OPS}/watched_${DATE}.csv"
# cat "${APPDATA}/TEMP/temp_show_clean.csv" >> "${BRAIN_OPS}/watched_${DATE}.csv"
# cat "${APPDATA}/TEMP/temp_watchlist.csv" >> "${BRAIN_OPS}/watchlist_${DATE}.csv"

# echo "🧠 Données exportées vers BrainOps : ${BRAIN_OPS}" | tee -a "${LOG}"
 
fi

rm -r ${APPDATA}/TEMP/
