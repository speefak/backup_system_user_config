#!/bin/bash
#
# name          : user_config_backup.sh
# desciption    : backup configs in /home/$USER and varios system configs
# autor         : Speefak
# licence       : (CC) BY-NC-SA
# version	: 2.0
# infosource	:
#------------------------------------------------------------------------------------------------------------
############################################################################################################
#######################################   define global variables   ########################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------

 # if [[ $(whoami) == root ]]; then HomeDirectory="/root" ; fi

 BackupTmpDir=$HOME/$(date +%F)_"$USER"@"$HOSTNAME"_backup
 BackupArchiv=$HOME/$(date +%F)_"$USER"@"$HOSTNAME"_backup.7z

 BackupContentUser=' .nano* .bash* .icons .local .config .mozilla* .thunderbird* '
 BackupContentSystem='/etc /usr/local/bin /home/GUI'

 RequiredPackets="bash sed gawk sudo p7zip-full ncdu"

 ErrorLogFile=/tmp/error_bsuc_$(date +%s)

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
		BackupConfigUser;-bu
		BackupConfigSystem;-bs
		BackupConfigAll;-ba

	"

	# set entered vars from optionvarlist
	OptionAllocator=" "										# for option seperator "=" use cut -d "="
	SAVEIFS=$IFS
	IFS=$(echo -en "\n\b")
 	for InputOption in $(echo " $@" | sed -e 's/-[a-z]/\n\0/g' ) ; do
		for VarNameVarValue in $OptionVarList ; do
			VarName=$(echo "$VarNameVarValue" | cut -d ";" -f1)
			VarValue=$(echo "$VarNameVarValue" | cut -d ";" -f2)
			if [[ -n $(echo " $InputOption" | grep " $VarValue" 2>/dev/null) ]]; then
#			if [[ $InputOption == "$VarValue" ]]; then
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
	printf " -b(u|s|a)	=> backup (u)ser, (s)ystem, (a)ll configs\n"
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
check_for_required_packages () {

	InstalledPacketList=$(dpkg -l | grep ii | awk '{print $2}' | cut -d ":" -f1)

	for Packet in $RequiredPackets ; do
		if [[ -z $(grep -w "$Packet" <<< $InstalledPacketList) ]]; then
			MissingPackets=$(echo $MissingPackets $Packet)
   		fi
	done

	# print status message / install dialog
	if [[ -n $MissingPackets ]]; then
		printf  "missing packets: \e[0;31m $MissingPackets\e[0m\n"$(tput sgr0)
		read -e -p "install required packets ? (Y/N) "		 	-i "Y" 		InstallMissingPackets
		if   [[ $InstallMissingPackets == [Yy] ]]; then

			# install software packets
			sudo apt update
			sudo apt install -y $MissingPackets
			if [[ ! $? == 0 ]]; then
				exit
			fi
		else
			printf  "programm error: $LRed missing packets : $MissingPackets $Reset\n\n"$(tput sgr0)
			exit 1
		fi

	else
		printf "$LGreen all required packets detected$Reset\n"
	fi
}
#------------------------------------------------------------------------------------------------------------
get_root_access () {

		SudoCMD=sudo
		printf "$LYellow root access required$Reset\n" 	
		$SudoCMD printf "$LGreen root access granted$Reset\n"
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

		SystemUserList=$(cat /etc/passwd | grep home | awk -F ":/" '{printf $2 "\n"}' | sed 's/home\///g' | grep -v ^$ | nl  )

		printf " user(s) found on this host ($(hostname)):$LYellow$SystemUser $Reset\n\n"

		# print systemuser list, select systemuser and set BackupConfigUser var
		printf "$SystemUserList\n\n"
		read -e -p " select user: " -i "1" BackupConfigUserCount

		# check input
		if [[ $( wc -l <<< $SystemUserList) -lt $BackupConfigUserCount ]] ; then
			printf "$LRed user number not found$Reset: $BackupConfigUserCount\n\n"
			get_user_name			
		fi

		BackupConfigUser=$(echo "$SystemUserList" | sed 's/^[[:space:]]*//' | grep -w "^$BackupConfigUserCount" | awk -F " " '{printf $2}')
		printf "\n"
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
gathering_files_user () {

	# copy user backupfiles
	printf " copy backupfiles ($BackupConfigUser) ... "
	cd $UserHome
	mkdir -p $BackupTmpDir$UserHome
	cp -r --parents $BackupContentUser $BackupTmpDir$UserHome 2>> $ErrorLogFile-gf
	if [[ $? == 0 ]]; then printf "$LGreen done $Reset \n" ; else printf "$LRed ERROR $Reset \n" ; fi
	cd - >/dev/null

} 
#------------------------------------------------------------------------------------------------------------
gathering_files_system () {

	# copy system backupfiles 
	printf " copy backupfiles (system) ... "
	cd /
	sudo cp -r --parents $BackupContentSystem $BackupTmpDir  2>> $ErrorLogFile-gf
	if [[ $? == 0 ]]; then printf "$LGreen done $Reset \n" ; else printf "$LRed ERROR $Reset \n" ; fi
	cd
}
#------------------------------------------------------------------------------------------------------------
print_error_log () {

	# print error log if errors occure
	if [[ -n $(cat $1) ]]; then
		printf "\n\n"
		cat $1 2> /dev/null | grep -v "^\["
		printf "\n\n"
	fi
}
#------------------------------------------------------------------------------------------------------------
clean_backup_waste () {

		$SudoCMD rm -r $BackupTmpDir/.local/share/Trash/
}
#------------------------------------------------------------------------------------------------------------
clear_tmp_directory () {

	# clear tmp directory
	printf " clear tmp directory ..."
	$SudoCMD rm -rf $BackupTmpDir 	2>> $ErrorLogFile
	if [[ $? == 0 ]]; then printf "$LGreen done $Reset \n" ; else printf "$LRed ERROR $Reset \n" ; fi
	mkdir $BackupTmpDir 		2>> $ErrorLogFile
}
#------------------------------------------------------------------------------------------------------------
clear_backup_files () {

	# clean backup waste / auto
	printf " cleanup backup (default) ... "
	$SudoCMD rm -r $BackupTmpDir$UserHome/.local/share/Trash/ 		2>> $ErrorLogFile-cbw
	$SudoCMD rm -r $BackupTmpDir$UserHome/.local/share/tracker 		2>> $ErrorLogFile-cbw
	if [[ ! -f $ErrorLogFile-cbw ]]; then print_error_log $ErrorLogFile-cbw ; else printf "$LGreen done $Reset\n" ; fi

	# clean backup waste / manually => ncdu for manually file selection
	cd $BackupTmpDir
	$SudoCMD ncdu 
	if [[ $? == 0 ]]; then printf " cleanup backup (manual) ... $LGreen done $Reset \n" ; else printf " cleanup backup (manual) ... $LRed ERROR $Reset \n" ; fi
	cd - >/dev/null

}
#-----------------------------------------------------------------------------------------------------------
compress_content () {

	## compress content
	printf "\n create archiv: $LYellow $BackupArchiv $Reset \n"
	$SudoCMD rm -f $BackupArchiv
	$SudoCMD 7z a -olr  "$BackupArchiv" "$BackupTmpDir/*"
	$SudoCMD chown $USER.$USER $BackupArchiv
}
#-----------------------------------------------------------------------------------------------------------
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

	# check for required package
	if [[ -n $CheckForRequiredPackages ]]; then check_for_required_packages; fi
	
#------------------------------------------------------------------------------------------------------------

	# check for backup options
	if   [[ -n $BackupConfigUser ]]; then	# -cu userbackup
		clear_tmp_directory
		get_user_name
		get_user_home_dir
		gathering_files_user
		clear_backup_files
		compress_content

	elif [[ -n $BackupConfigSystem ]]; then	# -cs systembackup
		clear_tmp_directory
		get_root_access
		gathering_files_system
		clear_backup_files
		compress_content

	elif [[ -n $BackupConfigAll ]]; then	# -ca user and systembackup
		clear_tmp_directory
		get_user_name
		get_user_home_dir
		get_root_access
		gathering_files_user
		gathering_files_system
		clear_backup_files
		compress_content
	fi

#-----------------------------------------------------------------------------------------------------------

	# clear tmp directory
	$SudoCMD rm -rf $BackupTmpDir

#------------------------------------------------------------------------------------------------------------

exit 0



echo "
whoami => $(whoami)
02=> |$UserHome|
04=> |$BackupConfigUserCount|
06=> |$BackupConfigUser|
08=> |$BackupConfigSystem|
10=> |$BackupConfigAll|
"

exit





#------------------------------------------------------------------------------------------------------------
############################################################################################################
##############################################   changelog   ###############################################
############################################################################################################
#------------------------------------------------------------------------------------------------------------
# TODO write tasks/ issus

# Add config file to config directory vars



# 2.0
# write changes




