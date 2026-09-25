#ddev-generated
# Playwright runs many browser workers against this web container. The DDEV
# default of eight PHP-FPM children saturates before the host CPUs do, causing
# unrelated requests to queue and sometimes fail during a full test run.
#
# DDEV sources entrypoint scripts from /start.sh rather than executing them,
# so use a subshell to keep these settings and any failure local to this script.
(
  set -e

  pool_config="/etc/php/${DDEV_PHP_VERSION}/fpm/pool.d/www.conf"
  if [ ! -f "$pool_config" ]; then
    echo "php-fpm-capacity: pool configuration not found: $pool_config" >&2
    exit 1
  fi

  # Browsers issue several simultaneous requests per Playwright worker. Keep
  # room for queued PHP requests even when worker count nears the CPU count.
  max_children=$(($(nproc) * 2))
  if (( max_children < 8 )); then max_children=8; fi
  if (( max_children > 96 )); then max_children=96; fi

  # The default pool starts three children and retains only four idle ones.
  # A full Playwright run opens many pages at once, so PHP-FPM otherwise spends
  # the first minutes spawning children while browser navigations time out.
  start_servers=$((max_children / 2))
  min_spare_servers=$((max_children / 3))
  max_spare_servers=$((max_children * 2 / 3))

  sed -i "s/^pm.max_children = [0-9][0-9]*$/pm.max_children = $max_children/" "$pool_config"
  sed -i "s/^pm.start_servers = [0-9][0-9]*$/pm.start_servers = $start_servers/" "$pool_config"
  sed -i "s/^pm.min_spare_servers = [0-9][0-9]*$/pm.min_spare_servers = $min_spare_servers/" "$pool_config"
  sed -i "s/^pm.max_spare_servers = [0-9][0-9]*$/pm.max_spare_servers = $max_spare_servers/" "$pool_config"
)
