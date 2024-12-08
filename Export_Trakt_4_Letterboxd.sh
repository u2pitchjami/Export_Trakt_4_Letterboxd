#!/bin/bash
############################################################################## 
#                                                                            #
#	SHELL: !/bin/bash       version 1.5  	                                     #
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
      cat ${BACKUP_DIR}/${USERNAME}-ratings_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .last_watched_at, .rating]|@csv' >> "./TEMP/temp_rating.csv"
      cat ${BACKUP_DIR}/${USERNAME}-watched_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .last_watched_at, .rating]|@csv' >> "./TEMP/temp.csv"
    else
      cat ${BACKUP_DIR}/${USERNAME}-ratings_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .watched_at, .rating]|@csv' >> "./TEMP/temp_rating.csv"
      cat ${BACKUP_DIR}/${USERNAME}-history_movies.json | jq -r '.[]|[.movie.title, .movie.year, .movie.ids.imdb, .movie.ids.tmdb, .watched_at, .rating]|@csv' >> "./TEMP/temp.csv"
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
fi
rm -r ${BACKUP_DIR}/
rm -r ${SCRIPT_DIR}/TEMP/
