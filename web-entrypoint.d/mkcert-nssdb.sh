#ddev-generated
# Import DDEV's mkcert root CA into the web user's NSS shared database so
# Chromium-based browsers (Playwright, Cypress, Puppeteer, etc.) trust
# *.ddev.site certificates without setting `ignoreHTTPSErrors: true`.
#
# DDEV already adds the CA to the OpenSSL system bundle, which curl, wget,
# openssl, and Node's default HTTPS agent all consult. Chromium on Linux
# does not read that bundle; it uses its built-in root store plus the NSS
# database at ~/.pki/nssdb for user-added roots.
#
# DDEV sources entrypoint scripts from /start.sh rather than executing
# them, so the body runs in a subshell to contain `set -e` and any errors.
# The script runs as the web user (not root); certutil comes from the
# libnss3-tools package installed by Dockerfile.playwright.
(
  set -eo pipefail

  if ! command -v certutil >/dev/null 2>&1; then
    # libnss3-tools is only installed when Playwright is enabled via
    # `ddev install-playwright`. Silently skip otherwise.
    exit 0
  fi

  shopt -s nullglob
  certs=(/usr/local/share/ca-certificates/mkcert_*.crt)
  if [ ${#certs[@]} -eq 0 ]; then
    exit 0
  fi

  nssdb="$HOME/.pki/nssdb"
  mkdir -p "$nssdb"
  chmod 0700 "$HOME/.pki" "$nssdb"

  # Probe the DB; any failure (missing or corrupt) means we re-create it.
  if ! certutil -d "sql:$nssdb" -L >/dev/null 2>&1; then
    rm -f "$nssdb"/cert9.db "$nssdb"/key4.db "$nssdb"/pkcs11.txt
    certutil -d "sql:$nssdb" -N --empty-password
  fi

  for cert in "${certs[@]}"; do
    nick="mkcert $(basename "$cert" .crt)"
    certutil -d "sql:$nssdb" -D -n "$nick" >/dev/null 2>&1 || true
    certutil -d "sql:$nssdb" -A -t "C,," -n "$nick" -i "$cert"
  done
) || echo "mkcert-nssdb: NSS DB import failed (non-fatal)" >&2
