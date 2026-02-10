#!/bin/bash
set -e

# -> Run entrypoint
# somehow when specify custom cmd in railway,
# it doesn't run entrypoint first, so we need to run it here.
/usr/local/bin/railway-entrypoint.sh echo "setup"

echo "-> Create empty common site config"
su frappe -c "echo '{}' > /home/frappe/bench/sites/common_site_config.json"

echo "-> Create new site with ERPNext"
cd /home/frappe/bench
su frappe -c "bench new-site ${RFP_DOMAIN_NAME} --admin-password ${RFP_SITE_ADMIN_PASSWORD} --no-mariadb-socket --db-root-password ${RFP_DB_ROOT_PASSWORD} --install-app erpnext"
su frappe -c "bench use ${RFP_DOMAIN_NAME}"

echo "-> Enable scheduler"
su frappe -c "bench enable-scheduler"

echo "-> Setup complete! Remove the start command override, set port to 80, and redeploy."
