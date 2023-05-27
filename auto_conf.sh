#!/bin/bash

# Vérification des privilèges de superutilisateur
if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté avec des privilèges de superutilisateur."
  exit 1
fi

# Installation de msmtp
apt update
apt install msmtp -y

# Vérification des arguments de ligne de commande
if [ $# -ne 5 ]; then
  echo "Utilisation : $0 <serveur_SMTP> <port_SMTP> <utilisateur_SMTP> <mot_de_passe_SMTP> <adresse_email>"
  exit 1
fi

# Récupération des arguments
smtp_server=$1
smtp_port=$2
smtp_user=$3
smtp_password=$4
email_address=$5

# Configuration de msmtp
echo "configuration msmtp..."
cat << EOF > /etc/msmtprc
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        /var/log/msmtp.log

account        default
host           $smtp_server
port           $smtp_port
from           $smtp_user
user           $smtp_user
password       $smtp_password

syslog         LOG_MAIL
EOF

# Configuration de cron-apt
echo "configuration cron-apt..."
cat << EOF > /etc/cron-apt/config
# Configurations pour cron-apt

# Mettre à jour les listes de paquets
OPTIONS="-o quiet=1 -o Dir::Etc::SourceList=/etc/apt/sources.list"

# Sélectionner le niveau de sécurité de la mise à jour
# Niveau 1 : Mises à jour critiques seulement
# Niveau 2 : Mises à jour de sécurité et corrections de bogues
# Niveau 3 : Mises à jour de sécurité, corrections de bogues et mises à jour recommandées
SECLEVEL="3"

# Envoyer un e-mail avec les résultats de la mise à jour
MAILON="always"
MAILTO="$email_address"
EOF

# Configuration des permissions
chmod 600 /etc/msmtprc
chown root: /etc/msmtprc
chmod 644 /etc/cron-apt/config
chown root: /etc/cron-apt/config

# Affichage de la configuration
echo "Configuration de msmtp terminée. Voici le contenu du fichier /etc/msmtprc :"
cat /etc/msmtprc

echo "Configuration de cron-apt terminée. Voici le contenu du fichier /etc/cron-apt/config :"
cat /etc/cron-apt/config

echo "Les fichiers de configuration se trouvent dans /etc/msmtprc et /etc/cron-apt/config. Assurez-vous de les protéger en conséquence."

exit 0
