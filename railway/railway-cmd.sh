#!/bin/sh

echo "-> PORT is: ${PORT}"

echo "-> Clearing cache"
su frappe -c "bench execute frappe.cache_manager.clear_global_cache" || echo "-> WARN: Cache clear failed (Redis may not be ready yet), continuing..."

echo "-> Bursting env into config"
envsubst '$RFP_DOMAIN_NAME,$PORT' < /home/$systemUser/temp_nginx.conf > /etc/nginx/conf.d/default.conf
envsubst '$PATH,$HOME,$NVM_DIR,$NODE_VERSION' < /home/$systemUser/temp_supervisor.conf > /home/$systemUser/supervisor.conf

echo "-> Nginx config:"
cat /etc/nginx/conf.d/default.conf | head -15

echo "-> Starting nginx"
nginx

echo "-> Starting supervisor"
/usr/bin/supervisord -c /home/$systemUser/supervisor.conf
