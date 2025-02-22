#! /bin/sh

# Entry point for rsnapshot backup
# This will create the config file (using environment variables),
# a crontab, and start cron

# First part of rsnapshot config
cat > /etc/rsnapshot.conf <<EOF
config_version	1.2
snapshot_root	/backup/
no_create_root	1
cmd_cp		/bin/cp
cmd_rm		/bin/rm
cmd_rsync	/usr/bin/rsync
cmd_ssh		/usr/bin/ssh
ssh_args	-i /ssh-id -o StrictHostKeychecking=no ${BACKUP_SSH_ARGS}
verbose		1
logfile		/var/log/rsnapshot
lockfile	/var/run/rsnapshot.pid
backup		${BACKUP_SOURCE}	${BACKUP_NAME}/	${BACKUP_OPTS}
EOF

# create empty crontab for root
# empty file, otherwise the cronjobs will be added with every container start.
> /etc/crontabs/root

# Dynamic parts - depending on the retain settings
# This will also create the crontab
if [ "${BACKUP_HOURLY}" -gt 0 ]
then
  echo "retain	hourly	${BACKUP_HOURLY}">> /etc/rsnapshot.conf
  echo "${CRON_HOURLY} nice -n ${RSYNC_NICE} ionice -c ${RSYNC_IONICE} rsnapshot hourly ; /bin/sh /report.sh" >> /etc/crontabs/root
fi
if [ "${BACKUP_DAILY}" -gt 0 ]
then
  echo "retain	daily	${BACKUP_DAILY}">> /etc/rsnapshot.conf
  echo "${CRON_DAILY} nice -n ${RSYNC_NICE} ionice -c ${RSYNC_IONICE} rsnapshot daily ; /bin/sh /report.sh" >> /etc/crontabs/root
fi
if [ "${BACKUP_WEEKLY}" -gt 0 ]
then
  echo "retain	weekly	${BACKUP_WEEKLY}">> /etc/rsnapshot.conf
  echo "${CRON_WEEKLY} nice -n ${RSYNC_NICE} ionice -c ${RSYNC_IONICE} rsnapshot weekly ; /bin/sh /report.sh" >> /etc/crontabs/root
fi
if [ "${BACKUP_MONTHLY}" -gt 0 ]
then
  echo "retain	monthly	${BACKUP_MONTHLY}">> /etc/rsnapshot.conf
  echo "${CRON_MONTHLY} nice -n ${RSYNC_NICE} ionice -c ${RSYNC_IONICE} rsnapshot monthly ; /bin/sh /report.sh" >> /etc/crontabs/root
fi
if [ "${BACKUP_YEARLY}" -gt 0 ]
then
  echo "retain	yearly	${BACKUP_YEARLY}">> /etc/rsnapshot.conf
  echo "${CRON_YEARLY} nice -n ${RSYNC_NICE} ionice -c ${RSYNC_IONICE} rsnapshot yearly ; /bin/sh /report.sh" >> /etc/crontabs/root
fi

# Add the user-provided config file
cat /backup.cfg >> /etc/rsnapshot.conf

# Test the config
CONFIGTEST=$(rsnapshot configtest)
echo "${CONFIGTEST}"
if [ "${CONFIGTEST}" = "Syntax OK" ]
then
  # And call the report script
  chmod +x /report.sh
  echo "Container started, running report script" >> /var/log/rsnapshot
  REPORT=$(/bin/sh /report.sh)
  echo "Report script response: ${REPORT}"
  # Syntax is OK, start cron
  /usr/sbin/crond -f
fi
