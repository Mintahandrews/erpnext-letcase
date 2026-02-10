#!/bin/sh

echo "-> Entrypoint starting"

echo "-> Set ownership of sites folder"
chown frappe:frappe /home/frappe/bench/sites || echo "-> WARN: chown sites failed, continuing..."

echo "-> Linking assets"
su frappe -c "ln -sf /home/frappe/bench/built_sites/assets /home/frappe/bench/sites/assets" || echo "-> WARN: link assets failed"
su frappe -c "ln -sf /home/frappe/bench/built_sites/apps.json /home/frappe/bench/sites/apps.json" || echo "-> WARN: link apps.json failed"
su frappe -c "ln -sf /home/frappe/bench/built_sites/apps.txt /home/frappe/bench/sites/apps.txt" || echo "-> WARN: link apps.txt failed"

echo "-> Entrypoint done, executing CMD"
exec "$@"
