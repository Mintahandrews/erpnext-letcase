#!/bin/sh

# Default PORT to 80 if Railway hasn't set it
export PORT="${PORT:-80}"

echo "-> [DEBUG] PORT=${PORT}"
echo "-> [DEBUG] RFP_DOMAIN_NAME=${RFP_DOMAIN_NAME}"
echo "-> [DEBUG] systemUser=${systemUser}"
echo "-> [DEBUG] Listing sites directory:"
ls -la /home/frappe/bench/sites/ 2>&1 || echo "-> WARN: Cannot list sites dir"

echo "-> Clearing cache"
su frappe -c "bench execute frappe.cache_manager.clear_global_cache" 2>&1 || echo "-> WARN: Cache clear failed, continuing..."

echo "-> Bursting env into config"
envsubst '$RFP_DOMAIN_NAME,$PORT' < /home/$systemUser/temp_nginx.conf > /etc/nginx/conf.d/default.conf
envsubst '$PATH,$HOME,$NVM_DIR,$NODE_VERSION' < /home/$systemUser/temp_supervisor.conf > /home/$systemUser/supervisor.conf

echo "-> Generated nginx config (first 15 lines):"
cat /etc/nginx/conf.d/default.conf | head -15

echo "-> Testing nginx config"
nginx -t 2>&1

echo "-> Starting nginx"
nginx 2>&1
echo "-> nginx start exit code: $?"

echo "-> Starting supervisor"
/usr/bin/supervisord -c /home/$systemUser/supervisor.conf
