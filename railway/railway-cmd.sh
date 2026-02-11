#!/bin/sh

# Default PORT to 80 if Railway hasn't set it
export PORT="${PORT:-80}"

# Full path to bench CLI (installed in frappe user's pip)
BENCH_CMD="/home/frappe/.local/bin/bench"

# Railway private networking defaults (IPv6)
# These match the service names from the Railway ERPNext template
export RFP_DB_HOST="${RFP_DB_HOST:-mariadb.railway.internal}"
export RFP_REDIS_CACHE_URL="${RFP_REDIS_CACHE_URL:-redis://redis-cache.railway.internal:6379}"
export RFP_REDIS_QUEUE_URL="${RFP_REDIS_QUEUE_URL:-redis://redis-queue.railway.internal:6379}"
export RFP_REDIS_SOCKETIO_URL="${RFP_REDIS_SOCKETIO_URL:-redis://redis-queue.railway.internal:6379}"

echo "-> [DEBUG] PORT=${PORT}"
echo "-> [DEBUG] RFP_DOMAIN_NAME=${RFP_DOMAIN_NAME}"
echo "-> [DEBUG] RFP_DB_HOST=${RFP_DB_HOST}"
echo "-> [DEBUG] RFP_REDIS_CACHE_URL=${RFP_REDIS_CACHE_URL}"
echo "-> [DEBUG] RFP_REDIS_QUEUE_URL=${RFP_REDIS_QUEUE_URL}"
echo "-> [DEBUG] systemUser=${systemUser}"
echo "-> [DEBUG] bench exists: $(ls -la ${BENCH_CMD} 2>&1)"

cd /home/frappe/bench

###############################################
# First-time setup: auto-detect and create site
###############################################
SETUP_MARKER="/home/frappe/bench/sites/.setup_complete"

if [ ! -f "$SETUP_MARKER" ]; then
    echo "============================================="
    echo "-> FIRST TIME SETUP DETECTED"
    echo "============================================="

    echo "-> Creating common_site_config.json with DB and Redis connection info"
    cat > /tmp/common_site_config.json << EOF
{
    "db_host": "${RFP_DB_HOST}",
    "db_port": 3306,
    "redis_cache": "${RFP_REDIS_CACHE_URL}",
    "redis_queue": "${RFP_REDIS_QUEUE_URL}",
    "redis_socketio": "${RFP_REDIS_SOCKETIO_URL}"
}
EOF
    cp /tmp/common_site_config.json /home/frappe/bench/sites/common_site_config.json
    chown frappe:frappe /home/frappe/bench/sites/common_site_config.json

    echo "-> common_site_config.json contents:"
    cat /home/frappe/bench/sites/common_site_config.json

    echo "-> Creating new site: ${RFP_DOMAIN_NAME}"
    su frappe -c "cd /home/frappe/bench && ${BENCH_CMD} new-site ${RFP_DOMAIN_NAME} \
        --admin-password ${RFP_SITE_ADMIN_PASSWORD} \
        --no-mariadb-socket \
        --db-root-password ${RFP_DB_ROOT_PASSWORD} \
        --install-app erpnext" 2>&1

    if [ $? -eq 0 ]; then
        echo "-> Setting default site"
        su frappe -c "cd /home/frappe/bench && ${BENCH_CMD} use ${RFP_DOMAIN_NAME}" 2>&1

        echo "-> Enabling scheduler"
        su frappe -c "cd /home/frappe/bench && ${BENCH_CMD} enable-scheduler" 2>&1

        echo "-> Marking setup as complete"
        su frappe -c "touch ${SETUP_MARKER}"

        echo "============================================="
        echo "-> FIRST TIME SETUP COMPLETE"
        echo "============================================="
    else
        echo "-> ERROR: Site creation failed! Check DB connectivity and env vars."
        echo "-> Will continue to start nginx/supervisor anyway for debugging."
    fi
else
    echo "-> Site already set up, skipping first-time setup"
    echo "-> Updating common_site_config.json with latest connection info"
    cat > /tmp/common_site_config.json << EOF
{
    "db_host": "${RFP_DB_HOST}",
    "db_port": 3306,
    "redis_cache": "${RFP_REDIS_CACHE_URL}",
    "redis_queue": "${RFP_REDIS_QUEUE_URL}",
    "redis_socketio": "${RFP_REDIS_SOCKETIO_URL}"
}
EOF
    cp /tmp/common_site_config.json /home/frappe/bench/sites/common_site_config.json
    chown frappe:frappe /home/frappe/bench/sites/common_site_config.json
fi

###############################################
# Normal startup
###############################################
echo "-> [DEBUG] Listing sites directory:"
ls -la /home/frappe/bench/sites/ 2>&1 || echo "-> WARN: Cannot list sites dir"

echo "-> Clearing cache"
su frappe -c "cd /home/frappe/bench && ${BENCH_CMD} execute frappe.cache_manager.clear_global_cache" 2>&1 || echo "-> WARN: Cache clear failed, continuing..."

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
