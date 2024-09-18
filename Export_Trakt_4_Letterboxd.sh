#!/bin/bash
############################################################################## 
#                                                                            #
#	SHELL: !/bin/bash       version 1   	                                     #
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


source ./.config.cfg


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
    history/movies
    )  
	fi
else
  OPTION=$(echo "normal")
  echo -e "${SAISPAS}${BOLD}[`date`] - Mode normal activé${NC}" | tee -a "${LOG}"
  endpoints=(
    ratings/movies
    history/movies
    )     
fi

echo -e "Récupération des informations..." | tee -a "${LOG}"

# create backup folder
mkdir -p ${BACKUP_DIR}

# Trakt requests
for endpoint in ${endpoints[*]}
do
  filename="${USERNAME}-${endpoint//\//_}.json"
 

  wget --quiet \
    -O ${BACKUP_DIR}/${filename} \
    --header "Content-Type: application/json" \
    --header "trakt-api-key: ${API_KEY}" \
    --header "trakt-api-version: 2" \
    "${API_URL}/users/${USERNAME}/${endpoint}" \
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
      cat ${BACKUP_DIR}/${USERNAME}-ratings_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .last_watched_at, .rating]|@csv' >> "./TEMP/temp.csv"
      cat ${BACKUP_DIR}/${USERNAME}-watched_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .last_watched_at, .rating]|@csv' >> "./TEMP/temp.csv"
    else
      cat ${BACKUP_DIR}/${USERNAME}-ratings_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .watched_at, .rating]|@csv' >> "./TEMP/temp_rating.csv"
      cat ${BACKUP_DIR}/${USERNAME}-history_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .watched_at, .rating]|@csv' >> "./TEMP/temp.csv"
      #diff -u <(cut -d "," -f1,2,3,4 temp_rating.csv) <(cut -d "," -f1,2,3,4 temp.csv) | grep '^+' | sed 's/^+//' 
    
    COUNT=$(cat "./TEMP/temp.csv" | wc -l)
    for ((o=1; o<=$COUNT; o++))
    do
      LIGNE=$(cat "./TEMP/temp.csv" | head -$o | tail +$o)
      
      DEBUT=$(echo "$LIGNE" | cut -d "," -f1,2,3,4)
      SCENEIN=$(grep -e "^${DEBUT}" ./TEMP/temp_rating.csv)
        if [[ -n $SCENEIN ]]
          then
          echo "${SCENEIN}" >> "./TEMP/temp.csv"
        fi
      
      done
    
    fi


    if [[ -f "letterboxd_import.csv" ]]
        then
        echo -e "Fichier existant, nouveaux films à la suite" | tee -a "${LOG}"
    else
        echo -e "Génération du fichier letterboxd_import.csv" | tee -a "${LOG}"
        echo "Title, Year, imdbID, tmdbID, WatchedDate, Rating10" >> "letterboxd_import.csv"
    fi
    echo -e "Ajouts des données suivantes : " | tee -a "${LOG}"
    COUNTTEMP=$(cat "./TEMP/temp.csv" | wc -l)
    for ((p=1; p<=$COUNTTEMP; p++))
    do
      LIGNETEMP=$(cat "./TEMP/temp.csv" | head -$p | tail +$p)
      DEBUT=$(echo "$LIGNETEMP" | cut -d "," -f1,2,3,4)
      DEBUTCOURT=$(echo "$LIGNETEMP" | cut -d "," -f1,2)
      MILIEU=$(echo "$LIGNETEMP" | cut -d "," -f5 | cut -d "T" -f1 | tr -d "\"")
      FIN=$(echo "$LIGNETEMP" | cut -d "," -f6)
      SCENEIN2=$(grep -e "^${DEBUT},${MILIEU},${FIN}" letterboxd_import.csv)
        if [[ -n $SCENEIN2 ]]
          then
          echo "Film : ${DEBUTCOURT} déjà présent dans le fichier d'import" | tee -a "${LOG}"
        else
          echo "${DEBUT},${MILIEU},${FIN}"
          echo "${DEBUT},${MILIEU},${FIN}" | tee -a "${LOG}" >> "letterboxd_import.csv"
        fi  
    done
    #while IFS= read -r line; do
      
    #done < "./TEMP/temp.csv"
    cp letterboxd_import.csv "$DOSCOPY/letterboxd_import.csv"
    echo " " | tee -a "${LOG}"
    echo -e "Fichier letterboxd_import.csv copié dans le dossier $DOSCOPY" | tee -a "${LOG}"
    echo -e "${BOLD}A intégrer à l'adresse suivante : https://letterboxd.com/import/ ${NC}" | tee -a "${LOG}"
    echo " " | tee -a "${LOG}"
    echo -e "${BOLD}N'oubliez pas de supprimer le ficher csv !!! ${NC}" | tee -a "${LOG}"
fi
rm -r ${BACKUP_DIR}/
rm -r ./TEMP/