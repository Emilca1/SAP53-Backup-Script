# Script sur la vm 192.168.20.3
# Dans le répertoire /script/backup.sh

#crontab -l
#0 2 * * * /script/backup.sh

#Début du script :

#!/bin/bash
# Configuration
MOUNT_POINT="/mnt/backup"
REMOTE_SERVER="10.193.39.26" #Proxmox Backup Server
REMOTE_DIR="/mnt/datastore/backups/vm"
LOG_DIR="/var/log/backupRsync/"
LOG_FILE="${LOG_DIR}rsync_backup_$(date '+%Y-%m-%d %H:%M:%S').log"
USER="root"
DEVICE="/dev/sdb"
NETWORK_INTERFACE="ens18"

if [ -d $LOG_DIR ]; then
	echo "Répértoire $LOG_DIR existant." >> "$LOG_FILE"
else
	mkdir -p $LOG_DIR
	if [ $? -eq 0 ]; then
		echo "Création du répertoire $LOG_DIR effectué avec succès." >> "$LOG_FILE"
	else
		exit 1
	fi
fi

# Fonction pour loguer les messages
log_message() {
		echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"

log_message "========== Début du script de sauvegarde $(date) ==========" >> "$LOG_FILE"

# Activation de l'interface réseau
log_message "Activation de l'interface réseau ${NETWORK_INTERFACE}."
ip link set "$NETWORK_INTERFACE" up
if [ $? -eq 0 ]; then
		log_message "Interface réseau $NETWORK_INTERFACE activée avec succès."
		systemctl start networking.service
		ping -c 5 $REMOTE_SERVER
		if [ $? -eq 0 ]; then
				log_message "Test de réseau fonctionnel."
		else
				log_message "Le réseau sur l'interface $NETWORK_INTERFACE n'est pas fonctionnel."
				exit 1
		fi
else
		log_message "Erreur lors de l'activation de l'interface réseau ${NETWORK_INTERFACE}."
		exit 1
fi

# Montage du disque
log_message "Montage du disque '$DEVICE' sur '${MOUNT_POINT}'."
if ! mount | grep -q "MOUNT_POINT"; then
		mount "$DEVICE" "$MOUNT_POINT"
		if [ $? -ne 0 ]; then
				log_message "Erreur : Impossible de monter le disque $DEVICE sur le point de montage ${MOUNT_POINT}."
				exit 1
		else
				log_message "Disque monté avec succès."
		fi
else
		log_message "Le disque est déjà monté."
fi

# Vérification du montage
if ! mountpoint -q "$MOUNT_POINT"; then
		log_message "Erreur : Le point de montage $MOUNT_POINT n'est pas valide."
		exit 1
fi

# Synchronisation des backups avec rsync
rsync -avz --delete "${USER}@${REMOTE_SERVER}:${REMOTE_DIR}" "$MOUNT_POINT" >> "$LOG_FILE" 2>&1

if [ $? -rq 0 ]; then
		log_message "Synchronisation terminée avec succès."
else
		log_message "Erreur lors de la synchronisation rsync."
fi

# Démontage du disque
log_message "Démontage du disque ${DEVICE}."
umount "$MOUNT_POINT"
if [ $? -eq 0 ]; then
		log_message "Démontage du disque réussi."
else
		log_message "Erreur lors du démontage du disque."
fi

# Désactivation de l'interface réseau
log_message "Désactivation de l'interface réseau ${NETWORK_INTERFACE}."
ip link set "$NETWORK_INTERFACE" down
if [ $? -eq 0 ]; then
		log_message "Interface réseau $NETWORK_INTERFACE désactivé avec succès."
else
		log_message "Erreur lors de la désactivation de l'interface réseau ${NETWORK_INTERFACE}."
fi

log_message "========== Fin du script de sauvegarde =========="