#!/bin/bash
#
# name          : user_config_backup.sh
# desciption    : backup configs in /home/$USER
# autor         : Speefak
# licence       : (CC) BY-NC-SA
# version	: 1.0
# infosource	:
#
#######################
### include scripts ###
#######################
#
########################
### define variables ###
########################

user=$USER@hostname
backuptmpdir=$HOME/$(date +%F)_"$USER"@"$HOSTNAME"_backup
backuparchiv=/home/$USER/$(date +%F)_"$USER"@"$HOSTNAME"_backup.7z
userbackupcontent='.sc .nano* .bash* .icons .local .config .mozilla* .thunderbird* .icedove .armory '
systembackupcontent='/etc /usr/local/bin /home/GUI'

###################
##  start script ##
###################
## get root permissions
#-----------------------------------------------------------------------------------------------------------
sudo echo
#-----------------------------------------------------------------------------------------------------------
rm -rf $backuptmpdir
mkdir $backuptmpdir
#-----------------------------------------------------------------------------------------------------------
## backup system files
## copy backupcontent to tmp backupdir
echo "gathering backupfiles"
cd /home/$USER
cp -r --parents $userbackupcontent $backuptmpdir
sudo cp -r --parents $systembackupcontent $backuptmpdir
#-----------------------------------------------------------------------------------------------------------
## delete obsolete data
sudo rm -r $backuptmpdir/.local/share/Trash/
#-----------------------------------------------------------------------------------------------------------
## check backupcontent via ncdu
cd $backuptmpdir
sudo ncdu 
cd -
#-----------------------------------------------------------------------------------------------------------
## compress entire backupcontent
echo -e "\ncompress following directoris to archiv $backuparchiv : \n"
sudo ls -al "$backuptmpdir"
sleep 5
sudo rm -f $backuparchiv
sudo 7z a -olr  "$backuparchiv" "$backuptmpdir/*"
sudo chown $USER.$USER $backuparchiv
#-----------------------------------------------------------------------------------------------------------
sudo rm -rf $backuptmpdir


