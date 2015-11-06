#!/bin/bash
	#Variables
	dateNow=$(date +"%d-%m-%Y")
	#Dossier pattern export
	patternRollBack="${HOME}/Migrate/_project_/_date_-_branch_-rollback"	
	patternMigrate="${HOME}/Migrate/_project_/_date_-_branch_-migrate"	
	
	#FUNCTION
	
	#Message d'affichage
	function flashmessage() {
		echo "----------------------------------------------------------"
		echo $1
		echo "----------------------------------------------------------" 
	}

	# Déterminer le path seelon win ou Linux
	function getPathWork() {
		
		if [[ $(uname) == 'Linux' ]]; then
			pathWork="/srv/${USER}/scm"
		else
			pathWork='/s'
		fi
	}

	# Switcher entre rsync et cp 
	function switchCommandeCopy() {
		if [[ $(uname) == 'Linux' ]]; then
			rsync -Rv "$@"
		else
			cp -p --parent "$@"
		fi
	}

	# Switcher pour ouvrir le répertoire
	function switchOpenFolderMigrate() {
		if [[ $(uname) == 'Linux' ]]; then
			nautilus $1 &
		else
			start $1
		fi
	}

	##Selectionner le projet
	function selectProject(){
		local workDir=()
		local numDir=''
		returnProjectFunc=''
		workDir=($(ls -d */.git | cut -d/ -f1))
		
		for i in "${!workDir[@]}"
		do
			echo $i - ${workDir[$i]}
		done

		read -p "Sélectionnez votre projet ? " numDir
				
		if [ -z ${workDir[$numDir]} ]; then
			echo "Le projet n° $numDir n'existe pas"
			selectProject $1
		else
			returnProjectFunc=${workDir[$numDir]}
		fi
	}
	
	##Selectionner une branche
	function selectBranch(){
		local branch=()
		branchSelect=''
		returnBranchFunc=''
		#Affichage du choix de la branche Source
		eval "$(git for-each-ref --shell --format='branch+=(%(refname:short))' refs/heads )"
		eval "$(git for-each-ref --shell --format='branch+=(%(refname:short))' refs/remotes )"

		#Choix
		for b in "${!branch[@]}" 
		do
			echo $b - ${branch[$b]}
		done

		read -p "Sélectionnez votre branche ? " branchSelect
		
		if [[ -z ${branch[$branchSelect]} ]]; then
			echo "La branche n° $branchSelect n'existe pas"
			selectBranch $1
		else
			returnBranchFunc=${branch[$branchSelect]}
		fi
	}
		
	
	#Génération des paths d'export
	function getReplacePath(){
		varFolder=$1
		varFolder=${varFolder/_project_/$2}
		varFolder=${varFolder/_date_/$3}
		varFolder=${varFolder/_branch_/$4}
		echo $varFolder
	}	
	
	#RUN ..............
	getPathWork
	cd $pathWork

	#Récupération de la liste des projets
	#Affichage du choix du projet
	flashmessage "Selection du projet"
	selectProject
	project=$returnProjectFunc
	
	#Projet choisi
	if [[ $project ]]; then 
		clear
		flashmessage "Vous avez choisi le projet : $project"

		cd $pathWork/$project
		
		#Récupération de la liste des branches
		#Affichage du choix de la branche Source
		flashmessage "Selection de la branche Source"
		selectBranch #'refs/heads'
		branchSelectLocal=$returnBranchFunc
		
		#Récupération de la liste des branches sur origin
		#Affichage du choix de la branche de comparaison
		flashmessage "Selection de la branche de comparaison"
		selectBranch #'refs/remotes'
		branchSelectOrigin=$returnBranchFunc

		#branche Choisie
		if [[ $branchSelectLocal ]] && [[ $branchSelectOrigin ]]; then

			#Verification du dépot, si tout est correct
			clear
			flashmessage "Vérification du dépot en cours : $project > $branchSelectLocal"
			verifDepot=$(git status -su | wc -l)

			#Si verif OK
			if [[ $verifDepot -eq 0 ]]; then
				clear
				flashmessage "Génération du contenu pour la Branche : $project > $branchSelectLocal "
				flashmessage "Comparaison avec la branche > $branchSelectOrigin "
				
				#On génére les path pour enregistrer les fichiers
				folderRollBack=$(getReplacePath "$patternRollBack" "$project" "$dateNow" "$branchSelectLocal")
				folderMigrate=$(getReplacePath "$patternMigrate" "$project" "$dateNow" "$branchSelectLocal")	

				#Nettoyage et création des dossiers
				rm -rf $folderRollBack $folderMigrate
				mkdir -p $folderRollBack $folderMigrate
				
				# on génére les fichiers en cas de RollBack
				git checkout $branchSelectOrigin
				switchCommandeCopy $(git diff $branchSelectLocal..$branchSelectOrigin  --name-only) $folderRollBack

				# on génére les fichiers pour la migration
				git checkout $branchSelectLocal
				switchCommandeCopy $(git diff $branchSelectOrigin..$branchSelectLocal --name-only) $folderMigrate
				git log $branchSelectOrigin...$branchSelectLocal --diff-filter=D --summary | grep delete > $folderMigrate/files_delete.txt

				flashmessage " Les dossiers se trouvent dans : ${HOME}/$project"
				switchOpenFolderMigrate $(dirname "$folderMigrate") 
            else 
                flashmessage "Il faut nettoyer le dépot actuel qui a : $verifDepot modifications(s)"
			fi
		fi		
	else
		flashmessage " Mais heuuu tu n'as pas choisi le bon chiffre boloss"
	fi
