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
if [ $# -ne 7 ]; then
  echo "Utilisation : $0 <serveur_SMTP> <port_SMTP> <utilisateur_SMTP> <mot_de_passe_SMTP> <adresse_email> <adresse_IP_serveur> <port_serveur>"
  exit 1
fi

# Récupération des arguments
smtp_server=$1
smtp_port=$2
smtp_user=$3
smtp_password=$4
email_address=$5
server_ip=$6
server_port=$7

# Configuration de msmtp
echo "Configuration de msmtp..."
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
echo "Configuration de cron-apt..."
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

# Configuration de rsyslog pour l'envoi des journaux vers un serveur distant
echo "Configuration de rsyslog..."
cat << EOF > /etc/rsyslog.conf
# Configuration de rsyslog

# Modules chargés
module(load="imuxsock") # Permet de recevoir des messages via le socket Unix
module(load="imklog")   # Permet de recevoir les messages du noyau
module(load="omfwd")    # Permet d'envoyer des messages vers un serveur distant

# Journaux à rediriger vers le serveur distant
*.* action(type="omfwd" target="$server_ip" port="$server_port" protocol="udp")

# Journaux à enregistrer localement
auth,authpriv.* /var/log/auth.log
cron.*          /var/log/cron.log
daemon.*        /var/log/daemon.log
kern.*          /var/log/kern.log
lpr.*           /var/log/lpr.log
mail.*          /var/log/mail.log
user.*          /var/log/user.log
uucp.*          /var/log/uucp.log

# Activer le journal des mails
mail.info      -/var/log/mail.info
mail.warning   -/var/log/mail.warn
mail.err       /var/log/mail.err

# Loguer toutes les informations de niveau crit et plus dans /var/log/syslog
*.=crit        /var/log/syslog

# Rediriger les messages de syslog vers le serveur distant
*.* @192.168.88.41:3985

# Règles de filtrage supplémentaires
:msg, contains, "error" /var/log/errors.log
& ~
EOF

# Configuration des permissions
chmod 600 /etc/msmtprc
chown root: /etc/msmtprc
chmod 644 /etc/cron-apt/config
chown root: /etc/cron-apt/config
chmod 644 /etc/rsyslog.conf
chown root: /etc/rsyslog.conf

# Affichage de la configuration
echo "Configuration de msmtp terminée. Voici le contenu du fichier /etc/msmtprc :"
cat /etc/msmtprc

echo "Configuration de cron-apt terminée. Voici le contenu du fichier /etc/cron-apt/config :"
cat /etc/cron-apt/config

echo "Configuration de rsyslog terminée. Voici le contenu du fichier /etc/rsyslog.conf :"
cat /etc/rsyslog.conf

echo "Les fichiers de configuration se trouvent dans /etc/msmtprc, /etc/cron-apt/config et /etc/rsyslog.conf. Assurez-vous de les protéger en conséquence."

# Redémarrage des services
systemctl restart rsyslog
systemctl restart cron

exit 0
