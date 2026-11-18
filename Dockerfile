# Bizsmith base image.
#
# Thin layer over the official Frappe/ERPNext v16 image (frappe/erpnext:v16 on
# Docker Hub, currently frappe 16.56.0 + erpnext 16.55.0). Adds only the apps
# upstream does not ship.
#
# agency_core is the reason this layer exists: it holds the Bizsmith app-tile
# branding (extend_bootinfo) and the idempotent post_model_sync patch that
# re-asserts the module declutter after every migrate. Without it there is no
# Bizsmith.
FROM frappe/erpnext:v16

USER frappe
WORKDIR /home/frappe/frappe-bench

# helpdesk's desk frontend imports socketio_port from sites/common_site_config.json
# at build time; the official image ships that file as {}. The runtime
# configurator overwrites it, so this only has to satisfy the bundler.
RUN printf '%s' '{"socketio_port": 9000}' > sites/common_site_config.json

RUN bench get-app --branch v16.53.1 https://github.com/frappe/hrms \
 && bench get-app --branch v1.92.0  https://github.com/frappe/crm \
 && bench get-app --branch v16.1.0  https://github.com/frappe/helpdesk \
 && bench get-app --branch develop  https://github.com/frappe/telephony \
 && bench get-app --branch main     https://github.com/whoisshahab/Frappe-White-Label \
 && bench get-app --branch main     https://github.com/ramananbuilds/agency_core \
 && bench build \
 && cp -a sites/assets/. assets/ \
 && rm -rf sites/assets

# bench build MUST run without --app: with --app, assets.json lists only the
# named apps, so frappe/erpnext bundles fall back to bare paths (404) and every
# website page renders unstyled.
#
# The copy into assets/ is required, not redundant: at runtime the `sites`
# volume shadows this image directory and supplies sites/assets as a symlink to
# /home/frappe/frappe-bench/assets, so assets/ is what nginx actually serves.
# Use cp -a, not cp -r, to preserve the per-app symlinks instead of
# dereferencing them into copies of each app's entire public/ tree.