#!/bin/bash
#
# name          : user_config_backup.sh
# desciption    : backup configs in /home/$USER and varios system configs
# autor         : Speefak
# licence       : (CC) BY-NC-SA
# version	: 1.1
# infosource	:
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 BackupTmpDir=$HOME/$(date +%F)_"$USER"@"$HOSTNAME"_backup
 BackupArchiv=/home/$USER/$(date +%F)_"$USER"@"$HOSTNAME"_backup.7z

 BackupContentUser='.sc .nano* .bash* .icons .local .config .mozilla* .thunderbird* .icedove .armory '
 BackupContentSystem='/etc /usr/local/bin /home/GUI'

 RequiredPackets="bash sed awk sudo p7zip-full ncdu"

 Version=$(cat $(readlink -f $(which $0)) | grep "# version" | head -n1 | awk -F ":" '{print $2}' | sed 's/ //g')
 ScriptFile=$(readlink -f $(which $0))
 ScriptName=$(basename $ScriptFile)

 SystemUserList=$(cat /etc/passwd | grep home | awk -F ":/" '{printf $2 "\n"}' | tr -d "\n"| sed 's/home\// /g')

#------------------------------------------------------------------------------------------------------------
############################################################################################################
########################################   set vars from options  ##########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	OptionVarList="

		HelpDialog;-h
		Monochrome;-m
		ScriptInformation;-si
		CheckForRequiredPackages;-cfrp
		BackupConfigUser;-cu
		BackupConfigSystem;-cs
		BackupConfigAll;-ca

	"

	# set entered vars from optionvarlist
	OptionAllocator=" "										# for option seperator "=" use cut -d "="
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
 	for InputOption in $(echo " $@" | sed -e 's/-[a-z]/\n\0/g' ) ; do
		for VarNameVarValue in $OptionVarList ; do
			VarName=$(echo "$VarNameVarValue" | cut -d ";" -f1)
			VarValue=$(echo "$VarNameVarValue" | cut -d ";" -f2)
#			if [[ -n $(echo " $InputOption" | grep " $VarValue" 2>/dev/null) ]]; then
			if [[ $InputOption == "$VarValue" ]]; then
				eval $(echo "$VarName"='$InputOption')					# if [[ -n Option1 ]]; then echo "Option1 set";fi
				#eval $(echo "$VarName"="true")
			elif [[ $(echo $InputOption | cut -d "$OptionAllocator" -f1) == "$VarValue" ]]; then	
				eval $(echo "$VarName"='$(echo $InputOption | cut -d "$OptionAllocator" -f 2-10)')
			fi
		done
	done
	IFS=$SAVEIFS

#------------------------------------------------------------------------------------------------------------
############################################################################################################
###########################################   define functions   ###########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
load_color_codes () {
	# parse required colours for echo/printf usage: printf "%s\n" "Text in ${Red}red${Reset}, white and ${Blue}blue${Reset}."
	Black='\033[0;30m'	&&	DGray='\033[1;30m'
	LRed='\033[0;31m'	&&	Red='\033[1;31m'
	LGreen='\033[0;32m'	&&	Green='\033[1;32m'
	LYellow='\033[0;33m'	&&	Yellow='\033[1;33m'
	LBlue='\033[0;34m'	&&	Blue='\033[1;34m'
	LPurple='\033[0;35m'	&&	Purple='\033[1;35m'
	LCyan='\033[0;36m'	&&	Cyan='\033[1;36m'
	LLGrey='\033[0;37m'	&&	White='\033[1;37m'
	Reset='\033[0m'

	BG='\033[47m'
	FG='\033[0;30m'

	# parse required colours for sed usage: sed 's/status=sent/'${Green}'status=sent'${Reset}'/g' |\
	if [[ $1 == sed ]]; then
		for ColorCode in $(cat $0 | sed -n '/^load_color_codes/,/FG/p' | tr "&" "\n" | grep "='"); do
			eval $(sed 's|\\|\\\\|g' <<< $ColorCode)						# sed parser '\033[1;31m' => '\\033[1;31m'
		done
	fi
}
#------------------------------------------------------------------------------------------------------------
usage() {

	printf "\n"
	printf " Usage: $(basename $0) <options> "
	printf "\n\n"
	printf " -h		=> help dialog \n"
	printf " -m		=> monochrome output \n"
	printf " -si		=> show script information \n"
	printf " -cfrp		=> check for required packets \n"
	printf "\n"
	printf " -c(u|s|a)	=> backup (u)ser, (s)ystem, (a)ll configs\n"
	printf " -cu <username>	=> backup user <username> (disable root check)\n"
#	printf " -k		=> keep tmp directory ($BackupTmpDir)\n"
	printf  "\n${LRed} $1 ${Reset}\n"
	printf "\n"
	exit
}
#------------------------------------------------------------------------------------------------------------
script_information () {
	printf "\n"
	printf " Scriptname: $ScriptName\n"
	printf " Version:    $Version \n"
	printf " Location:   $(pwd)/$ScriptName\n"
	printf " Filesize:   $(ls -lh $0 | cut -d " " -f5)\n"
	printf "\n"
	exit 0
}
#------------------------------------------------------------------------------------------------------------
check_permissions_scriptexecution () {

	if [[ -n $BackupConfigAll ]]; then BackupConfigUser=$BackupConfigAll ; fi	

	if   [[ $(whoami) == root ]] && [[ -n $BackupConfigSystem ]] || [[ $(whoami) == root ]] && [[ -n $BackupConfigUser ]]; then	
		GetUserName=true
		SudoCMD=sudo
	elif [[ ! $(whoami) == root ]] && [[ -n $BackupConfigSystem ]] || [[ ! $(whoami) == root ]] && [[ -n $BackupConfigSystem ]] ; then
		GetRootAccess=true
	fi

	if [[ -n $BackupConfigAll ]] && [[ $(whoami) == root ]] ; then
		GetUserName=true
	elif [[ -n $BackupConfigAll ]] && [[ ! $(whoami) == root ]]; then
		GetRootAccess=true		
	fi

	# get missing vars / permissions
	if [[ $GetRootAccess == true ]]; then get_root_access ;	fi
	if [[ $GetUserName   == true ]]; then get_user_name   ;	fi
}
#------------------------------------------------------------------------------------------------------------
get_root_access () {

		printf "$LYellow root access required$Reset\n" 	
		sudo printf "$LGreen root access granted$Reset\n"
		if [[ ! $? == 0 ]]; then 
			usage " no root access granted"
		fi
}
#------------------------------------------------------------------------------------------------------------
get_user_name () {

	# set username for non sudo execution
	if [[ ! $(whoami) == root ]]; then BackupConfigUser=$(whoami) ; fi

	# get username for sudo from input vars
	if [[ $(whoami) == root ]]; then 

		if [[ $BackupConfigUser == "-ca" ]]; then

			SystemUserList=$(cat /etc/passwd | grep home | awk -F ":/" '{printf $2 "\n"}' | sed 's/home\///g' | grep -v ^$ | nl  )

			printf " detected user ($(hostname)):$LYellow$SystemUser $Reset\n\n"

			# print systemuser list, select systemuser and set BackupConfigUser var
			printf "$SystemUserList\n\n"
			read -e -p " select a user " -i "1" BackupConfigUserCount
			BackupConfigUser=$(echo "$SystemUserList" | sed 's/^[[:space:]]*//' | grep -w "^$BackupConfigUserCount" | awk -F " " '{printf $2}')
		fi	
	fi
}
#------------------------------------------------------------------------------------------------------------
get_user_home_dir () {

	# set user home directory
	UserHome="/$(cat /etc/passwd | grep "$BackupConfigUser" | awk -F ":/" '{printf $2 "\n"}')"

	# check for existing user and home directory
	id $BackupConfigUser >/dev/null
	if [[ ! $? == 0  ]] && [[ ! $BackupConfigUser == "-cu" ]] ; then usage "user not found: $Reset $BackupConfigUser" ; fi 
	if [[ ! -d $UserHome ]] ; then usage "directory not found: $Reset $UserHome " ; fi 

	printf "$LGreen user found:$Reset ($BackupConfigUser) \n"

	# check for existing user
	id $BackupConfigUser >/dev/null
	if [[ ! $? == 0  ]] && [[ ! $BackupConfigUser == "-cu" ]] ; then
		usage "user not found: $Reset $BackupConfigUser"
	fi 
	printf "$LGreen user access granted$Reset ($BackupConfigUser) \n"

}
#------------------------------------------------------------------------------------------------------------
create_backup () {





echo "
whoami => $(whoami)
02=> |$UserHome|
04=> |$BackupConfigUserCount|
06=> |$BackupConfigUser|
08=> |$BackupConfigSystem|
10=> |$BackupConfigAll|
"

	# parse variables
#	BackupConfigUser=${BackupConfigUser//-ca/$(whoami)}



	echo "ERRORLOG ($(date)): gathering backupfiles" > /tmp/bsuc_cp.log

	printf " gathering backupfiles \n"

	if [[ -n $BackupConfigUser$BackupConfigAll ]]; then
		# copy user backupfiles
		printf " copy backupfiles ($BackupConfigUser) ... "
		cd $UserHome
		cp -r --parents $BackupContentUser $BackupTmpDir/$BackupContentUser #2>> /tmp/bsuc_cp.log
		if [[ $? == 0 ]]; then printf "$LGreen done $Reset \n" ; else printf "$LRed ERROR $Reset \n" ; fi
		cd - >/dev/null
	fi
exit

	if [[ -n $BackupConfigSystem$BackupConfigAll ]]; then
		# copy system backupfiles 
		printf " copy backupfiles (system) ... "
#		$SudoCMD cp -r --parents $BackupContentSystem $BackupTmpDir 2>> /tmp/bsuc_cp.log
		if [[ $? == 0 ]]; then printf "$LGreen done $Reset \n" ; else printf "$LRed ERROR $Reset \n" ; fi
	fi

	# print errors
	printf "\n\n"
	cat /tmp/bsuc_cp.log 2> /dev/null
	printf "\n\n"


	## delete obsolete data in tmp directory
	$SudoCMD rm -r $BackupTmpDir/.local/share/Trash/
}
#------------------------------------------------------------------------------------------------------------
check_for_required_packages () {

	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2 $3}')

	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w "$Packet"$ <<< $InstalledPacketList) ]]; then
			MissingPackets=$(echo $MissingPackets $Packet)
   		fi
	done

	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf  "missing packets: ${LRed}  $MissingPackets ${Reset} \n"
		read -e -p "install required packets ? (Y/N) "	-i "Y" 	InstallMissingPackets
		if   [[ $InstallMissingPackets == [Yy] ]]; then

			# install software packets
			sudo apt update
			sudo apt install -y $MissingPackets
			if [[ ! $? == 0 ]]; then
				exit
			fi
		else
			printf  "programm error: ${LRed} missing packets : $MissingPackets ${Reset} \n"
			exit 1
		fi

	else
		printf "${LGreen} all required packets detected ${Reset}\n"
	fi
}
#------------------------------------------------------------------------------------------------------------
Countdown_request () {

	RequestCountdown=10
	CountdownRequestMessage="proceed ?"
	tput civis 
	for i in $(seq 1 $RequestCountdown) ;do
		read -t1 -n1 -s -p "$CountdownRequestMessage (y/n) " Request
		request () {
			if   [[ "$Request" == "[yY]" ]]; then
				DeleteUserConfigs=true
				break	
			elif [[ "$Request" == "[nN]" ]]; then
				DeleteUserConfigs=false
				break
			elif   [[ -n "$Request" ]] ;then 
				request	
			fi
			DeleteUserConfigs=true
			printf '%2s\r' $(echo $(($RequestCountdown-$i)))
		}
		request
	done
	printf '%50s\r'
	tput cnorm
}
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#############################################   start script   #############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

	# check for cronjob execution and cronjob options
	CronExecution=
	if [ -z $(grep "/" <<< "$(tty)") ]; then
		CronExecution=true
		Monochrome=true
	fi

#------------------------------------------------------------------------------------------------------------

	# check for monochrome output
	Reset='\033[0m'
	if [[ -z $Monochrome ]]; then
		load_color_codes
	fi

#------------------------------------------------------------------------------------------------------------

	# check help dialog
	if [[ -n $HelpDialog ]] || [[ -z $1 ]]; then usage "help dialog" ; fi

#------------------------------------------------------------------------------------------------------------

	# check for script information
	if [[ -n $ScriptInformation ]]; then script_information ; fi

#------------------------------------------------------------------------------------------------------------

	# check for user/root permissions // get root permissions via sudo
	check_permissions_scriptexecution
	
#------------------------------------------------------------------------------------------------------------

	# check for required package
	if [[ -n $CheckForRequiredPackages ]]; then check_for_required_packages; fi

#------------------------------------------------------------------------------------------------------------

	
	# clear tmp directory
	rm -rf $BackupTmpDir
	mkdir $BackupTmpDir

#------------------------------------------------------------------------------------------------------------

	# gathering backupfiles copy backupcontent to tmp backupdir and create backup
	create_backup

#-----------------------------------------------------------------------------------------------------------

	# open ncdu for manually file selection
	cd $BackupTmpDir
	sudo ncdu 
	cd -

#-----------------------------------------------------------------------------------------------------------

	## compress entire backupcontent
	echo -e "\ncompress following directoris to archiv $BackupArchiv : \n"
	sudo ls -al "$BackupTmpDir"
	sleep 5
	sudo rm -f $BackupArchiv
	sudo 7z a -olr  "$BackupArchiv" "$BackupTmpDir/*"
	sudo chown $USER.$USER $BackupArchiv

#-----------------------------------------------------------------------------------------------------------

	# clear tmp directory
	sudo rm -rf $BackupTmpDir

#------------------------------------------------------------------------------------------------------------

exit 0

#------------------------------------------------------------------------------------------------------------
############################################################################################################
##############################################   changelog   ###############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
# TODO write tasks/ issus

# 1.0
# write changes






#!/bin/bash
#
# name          : user_config_backup.sh
# desciption    : backup configs in /home/$USER and varios system configs
# autor         : Speefak
# licence       : (CC) BY-NC-SA
# version	: 1.1
# infosource	:
#
#######################
### include scripts ###
#######################
#
########################
### define variables ###
########################

#user=$USER@hostname
#BackupTmpDir=$HOME/$(date +%F)_"$USER"@"$HOSTNAME"_backup
#BackupArchiv=/home/$USER/$(date +%F)_"$USER"@"$HOSTNAME"_backup.7z
#BackupContentUser='.sc .nano* .bash* .icons .local .config .mozilla* .thunderbird* .icedove .armory '
#BackupContentSystem='/etc /usr/local/bin /home/GUI'

###################
##  start script ##
###################
## get root permissions
#-----------------------------------------------------------------------------------------------------------
#sudo echo

offline () { #-----------------------------------------------------------------------------------------------------------
rm -rf $BackupTmpDir
mkdir $BackupTmpDir
#-----------------------------------------------------------------------------------------------------------
## backup system files
## copy backupcontent to tmp backupdir
echo "gathering backupfiles"
cd /home/$USER
cp -r --parents $BackupContentUser $BackupTmpDir
sudo cp -r --parents $BackupContentSystem $BackupTmpDir
#-----------------------------------------------------------------------------------------------------------
## delete obsolete data
sudo rm -r $BackupTmpDir/.local/share/Trash/
#-----------------------------------------------------------------------------------------------------------
## check backupcontent via ncdu
cd $BackupTmpDir
sudo ncdu 
cd -
#-----------------------------------------------------------------------------------------------------------
## compress entire backupcontent
echo -e "\ncompress following directoris to archiv $BackupArchiv : \n"
sudo ls -al "$BackupTmpDir"
sleep 5
sudo rm -f $BackupArchiv
sudo 7z a -olr  "$BackupArchiv" "$BackupTmpDir/*"
sudo chown $USER.$USER $BackupArchiv
#-----------------------------------------------------------------------------------------------------------
sudo rm -rf $BackupTmpDir

}


















#TODO add config systembackp  userbackup all backup
