#!/bin/bash
############################################################################## 
#                                                                            #
#	SHELL: !/bin/bash       version 2  	                                     #
#									                                                           #
#	NOM: u2pitchjami						                                               #
#									                                                           #
#							  					                                                   #
#									                                                           #
#	DATE: 18/09/2024          	           				                             #
#									                                                           #
#	BUT: Export trakt to letterboxd format                             		     #
#									                                                           #
############################################################################## 
# Trakt backup script (note that user profile must be public)
# Trakt API documentation: http://docs.trakt.apiary.io
# Trakt client API key: http://docs.trakt.apiary.io/#introduction/create-an-app
SCRIPT_DIR=$(dirname "$(realpath "$0")")
source ${SCRIPT_DIR}/.config.cfg

refresh_access_token() {
    echo "🔄 Rafraîchissement du token Trakt..."
    
    RESPONSE=$(curl -s -X POST "https://api.trakt.tv/oauth/token" \
        -H "Content-Type: application/json" \
        -d "{
            \"refresh_token\": \"${REFRESH_TOKEN}\",
            \"client_id\": \"${API_KEY}\",
            \"client_secret\": \"${API_SECRET}\",
            \"redirect_uri\": \"${REDIRECT_URI}\",
            \"grant_type\": \"refresh_token\"
        }")

    NEW_ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')
    NEW_REFRESH_TOKEN=$(echo "$RESPONSE" | jq -r '.refresh_token')

    if [[ "$NEW_ACCESS_TOKEN" != "null" && "$NEW_REFRESH_TOKEN" != "null" ]]; then
        echo "✅ Token rafraîchi avec succès."
        sed -i "s|ACCESS_TOKEN=.*|ACCESS_TOKEN=\"$NEW_ACCESS_TOKEN\"|" .config.cfg
        sed -i "s|REFRESH_TOKEN=.*|REFRESH_TOKEN=\"$NEW_REFRESH_TOKEN\"|" .config.cfg
        source .config.cfg  # Recharge les variables mises à jour
    else
        echo "❌ Erreur lors du rafraîchissement du token. Vérifiez votre configuration !" | tee -a "${LOG}"
        exit 1
    fi
}

##########################CONTROLE SI OPTION "COMPLET" ACTIVE################
if [ ! -z $1 ]
	then
	OPTION=$(echo $1 | tr '[:upper:]' '[:lower:]')
	if [ $OPTION == "complet" ]
		then
		echo -e "${SAISPAS}${BOLD}[`date`] - Mode Complet activé${NC}" | tee -a "${LOG}"
    endpoints=(
    watchlist/movies
    watchlist/shows
    watchlist/episodes
    watchlist/seasons
    ratings/movies
    ratings/shows
    ratings/episodes
    ratings/seasons
    collection/movies
    collection/shows
    watched/movies
    watched/shows
    history/movies
    history/shows
    ) 
  elif [ $OPTION == "initial" ]
		then
		echo -e "${SAISPAS}${BOLD}[`date`] - Mode Initial activé${NC}" | tee -a "${LOG}"
    endpoints=(
    ratings/movies
    watched/movies
    )     
	else
		echo -e "${SAISPAS}${BOLD}[`date`] - Variable inconnue, mode normal activé${NC}" | tee -a "${LOG}"
		OPTION=$(echo "normal")
    endpoints=(
    ratings/movies
    ratings/episodes
    history/movies
    history/shows
    history/episodes
    watchlist/movies
    watchlist/shows
    )  
	fi
else
  OPTION=$(echo "normal")
  echo -e "${SAISPAS}${BOLD}[`date`] - Mode normal activé${NC}" | tee -a "${LOG}"
  endpoints=(
    ratings/movies
    ratings/episodes
    history/movies
    history/shows
    history/episodes
    watchlist/movies
    watchlist/shows
    )     
fi

echo -e "Récupération des informations..." | tee -a "${LOG}"

# create backup folder
mkdir -p ${BACKUP_DIR}

# Vérifier si le token est encore valide avant chaque requête
RESPONSE=$(curl -s -X GET "${API_URL}/users/me/history/movies" \
    -H "Content-Type: application/json" \
    -H "trakt-api-key: ${API_KEY}" \
    -H "trakt-api-version: 2" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}")

if echo "$RESPONSE" | grep -q "invalid_grant"; then
    echo "⚠️ Token expiré, tentative de rafraîchissement..."
    refresh_access_token
fi

# Trakt requests
for endpoint in ${endpoints[*]}
do
  filename="${USERNAME}-${endpoint//\//_}.json"
 
  curl -X GET "${API_URL}/users/me/${endpoint}" \
    -H "Content-Type: application/json" \
    -H "trakt-api-key: ${API_KEY}" \
    -H "trakt-api-version: 2" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -o ${BACKUP_DIR}/${filename} \
    && echo -e "\e[32m${USERNAME}/${endpoint}\e[0m Récupération ok" \
    || echo -e "\e[31m${USERNAME}/${endpoint}\e[0m La demande a échoué" | tee -a "${LOG}"
    
done

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
      cat ${BACKUP_DIR}/${USERNAME}-ratings_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .last_watched_at, .rating]|@csv' >> "./TEMP/temp_rating.csv"
      cat ${BACKUP_DIR}/${USERNAME}-watched_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .last_watched_at, .rating]|@csv' >> "./TEMP/temp.csv"
    else
      cat ${BACKUP_DIR}/${USERNAME}-ratings_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .watched_at, .rating]|@csv' >> "./TEMP/temp_rating.csv"
      cat ${BACKUP_DIR}/${USERNAME}-ratings_episodes.json | jq -r '.[]|[.show.title, .show.year, .episode.title, .episode.season, .episode.number, .show.ids.imdb, .show.ids.tmdb, .watched_at, .rating]|@csv' >> "./TEMP/temp_rating_episodes.csv"
      cat ${BACKUP_DIR}/${USERNAME}-history_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .watched_at, .rating]|@csv' >> "./TEMP/temp.csv"
      cat ${BACKUP_DIR}/${USERNAME}-history_shows.json | jq -r '.[]|[.show.title, .show.year, .episode.title, .episode.season, .episode.number, .show.ids.imdb, .show.ids.tmdb, .watched_at, .rating]|@csv' >> "./TEMP/temp_show.csv"
      cat ${BACKUP_DIR}/${USERNAME}-watchlist_movies.json | jq -r '.[]|[.type, .movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .listed_at]|@csv' >> "./TEMP/temp_watchlist.csv"
      cat ${BACKUP_DIR}/${USERNAME}-watchlist_shows.json | jq -r '.[]|[.type, .show.title, .show.year, .show.ids.imdb, .show.ids.tmdb, .listed_at]|@csv' >> "./TEMP/temp_watchlist.csv"
      #diff -u <(cut -d "," -f1,2,3,4 temp_rating.csv) <(cut -d "," -f1,2,3,4 temp.csv) | grep '^+' | sed 's/^+//' 
    fi   
    COUNT=$(cat "${SCRIPT_DIR}/TEMP/temp.csv" | wc -l)
    for ((o=1; o<=$COUNT; o++))
    do
      LIGNE=$(cat "${SCRIPT_DIR}/TEMP/temp.csv" | head -$o | tail +$o)
      DEBUT=$(echo "$LIGNE" | cut -d "," -f1,2,3,4)
      SCENEIN=$(grep -e "^${DEBUT}" ${SCRIPT_DIR}/TEMP/temp_rating.csv)
      
        if [[ -n $SCENEIN ]]
          then
          NOTE=$(echo "${SCENEIN}" | cut -d "," -f6 )
          
          sed -i ""$o"s|$|$NOTE|" ${SCRIPT_DIR}/TEMP/temp.csv
        fi
     
    done

COUNT=$(cat "${SCRIPT_DIR}/TEMP/temp_show.csv" | wc -l)
    for ((o=1; o<=$COUNT; o++))
    do
      LIGNE=$(cat "${SCRIPT_DIR}/TEMP/temp_show.csv" | head -$o | tail +$o)
      DEBUT=$(echo "$LIGNE" | cut -d "," -f1,2,3,4)
      SCENEIN=$(grep -e "^${DEBUT}" ${SCRIPT_DIR}/TEMP/temp_rating_episodes.csv)
      
        if [[ -n $SCENEIN ]]
          then
          NOTE=$(echo "${SCENEIN}" | cut -d "," -f9 )
          
          sed -i ""$o"s|$|$NOTE|" ${SCRIPT_DIR}/TEMP/temp_show.csv
        fi
     
    done    
    

    if [[ -f "${SCRIPT_DIR}/letterboxd_import.csv" ]]
        then
        echo -e "Fichier existant, nouveaux films à la suite" | tee -a "${LOG}"
    else
        echo -e "Génération du fichier letterboxd_import.csv" | tee -a "${LOG}"
        echo "Title, Year, imdbID, tmdbID, WatchedDate, Rating10" >> "${SCRIPT_DIR}/letterboxd_import.csv"
    fi
    echo -e "Ajouts des données suivantes : " | tee -a "${LOG}"
    COUNTTEMP=$(cat "${SCRIPT_DIR}/TEMP/temp.csv" | wc -l)
    for ((p=1; p<=$COUNTTEMP; p++))
    do
      LIGNETEMP=$(cat "${SCRIPT_DIR}/TEMP/temp.csv" | head -$p | tail +$p)
      DEBUT=$(echo "$LIGNETEMP" | cut -d "," -f1,2,3,4)
      #echo "debut $DEBUT"
      DEBUTCOURT=$(echo "$LIGNETEMP" | cut -d "," -f1,2)
      MILIEU=$(echo "$LIGNETEMP" | cut -d "," -f5 | cut -d "T" -f1 | tr -d "\"")
      #echo "MILIEU $MILIEU"
      FIN=$(echo "$LIGNETEMP" | cut -d "," -f6)
     # echo "FIN $FIN"
      SCENEIN1=$(grep -e "^${DEBUT},${MILIEU}" ${SCRIPT_DIR}/letterboxd_import.csv)
      
      #echo "SCENEIN1 $SCENEIN1"
        if [[ -n $SCENEIN1 ]]
          then
          FIN1=$(echo "$SCENEIN1" | cut -d "," -f6)
          #echo "fin1 $FIN1"
          SCENEIN2=$(grep -n "^${DEBUT},${MILIEU}" ${SCRIPT_DIR}/letterboxd_import.csv | cut -d ":" -f 1)
          #echo "scenein2 $SCENEIN2"
          if [[ "${DEBUT},${MILIEU},${FIN}" == "${DEBUT},${MILIEU},${FIN1}" ]]
            then
            echo "Film : ${DEBUTCOURT} déjà présent dans le fichier d'import" | tee -a "${LOG}"
          else
            #FIN2=$(echo "$SCENEIN2" | cut -d "," -f6)
            if [[ -n $FIN1 ]]
              then
              sed -i ""$SCENEIN2"s/$FIN1/$FIN/" ${SCRIPT_DIR}/letterboxd_import.csv
              else
              sed -i ""$SCENEIN2"s/$/$FIN/" ${SCRIPT_DIR}/letterboxd_import.csv
              fi
            echo "Film : ${DEBUTCOURT} déjà présent mais ajout de la note $FIN" | tee -a "${LOG}"
          fi
        else
          echo "${DEBUT},${MILIEU},${FIN}"
          echo "${DEBUT},${MILIEU},${FIN}" | tee -a "${LOG}" >> "${SCRIPT_DIR}/letterboxd_import.csv"
        fi  
    done
    #while IFS= read -r line; do
      
    #done < "./TEMP/temp.csv"
    cp ${SCRIPT_DIR}/letterboxd_import.csv "$DOSCOPY/letterboxd_import.csv"
    echo " " | tee -a "${LOG}"
    echo -e "Fichier letterboxd_import.csv copié dans le dossier $DOSCOPY" | tee -a "${LOG}"
    echo -e "${BOLD}A intégrer à l'adresse suivante : https://letterboxd.com/import/ ${NC}" | tee -a "${LOG}"
    echo " " | tee -a "${LOG}"
    echo -e "${BOLD}N'oubliez pas de supprimer le ficher csv !!! ${NC}" | tee -a "${LOG}"

  awk -F, 'BEGIN {OFS=","} {gsub(/"/, "", $1); $2=$2",NULL,NULL,NULL"}1' ${SCRIPT_DIR}/TEMP/temp.csv > ${SCRIPT_DIR}/TEMP/temp2.csv
  #sed -i 's/^\("\w\+",[0-9]\{4\}\),/\1,NULL,NULL,NULL,/' ${SCRIPT_DIR}/TEMP/temp.csv
  sed -i 's/^/Movie,/; s/"//g' ${SCRIPT_DIR}/TEMP/temp2.csv
  sed -i 's/^/Show,/; s/"//g' ${SCRIPT_DIR}/TEMP/temp_show.csv
 sed -i 's/"//g' ${SCRIPT_DIR}/TEMP/temp_watchlist.csv


  cat ${SCRIPT_DIR}/TEMP/temp2.csv >> /mnt/user/Zin-progress/2nd_brain/mariadb-import/watched_${DATE}.csv
  cat ${SCRIPT_DIR}/TEMP/temp_show.csv >> /mnt/user/Zin-progress/2nd_brain/mariadb-import/watched_${DATE}.csv
  cat ${SCRIPT_DIR}/TEMP/temp_watchlist.csv >> /mnt/user/Zin-progress/2nd_brain/mariadb-import/watchlist_${DATE}.csv
 



fi
rm -r ${BACKUP_DIR}/
rm -r ${SCRIPT_DIR}/TEMP/
