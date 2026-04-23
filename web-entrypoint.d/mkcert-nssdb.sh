#ddev-generated
# Teach Playwright's browsers to trust DDEV's mkcert root CA so
# *.ddev.site certificates load without `ignoreHTTPSErrors: true`.
#
# Two pieces run here:
#   1. Import every /usr/local/share/ca-certificates/mkcert_*.crt into the
#      web user's NSS shared database (~/.pki/nssdb). Chromium on Linux
#      consults NSS for user-added roots; this covers Chromium and
#      Chromium-based tools (Cypress, Puppeteer, etc.). DDEV already adds
#      the CA to the OpenSSL bundle that curl/wget/openssl/Node read, so
#      those were never broken.
#   2. Write a Firefox enterprise-policy JSON containing Certificates.Install
#      and point the PLAYWRIGHT_FIREFOX_POLICIES_JSON env var at it via
#      config.playwright.yml. Playwright patches its bundled Firefox to load
#      policies from that env var (see playwright.cfg in the Firefox build),
#      which lets us inject trust into the ephemeral profile Playwright
#      creates for each test run. WebKit consults the system CA bundle
#      directly and needs no extra handling.
#
# DDEV sources entrypoint scripts from /start.sh rather than executing
# them, so the body runs in a subshell to contain `set -e` and any errors.
# The script runs as the web user (not root); certutil comes from the
# libnss3-tools package installed by Dockerfile.playwright.
(
  set -eo pipefail

  shopt -s nullglob
  certs=(/usr/local/share/ca-certificates/mkcert_*.crt)
  if [ ${#certs[@]} -eq 0 ]; then
    exit 0
  fi

  # --- Chromium / NSS ----------------------------------------------------
  if command -v certutil >/dev/null 2>&1; then
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
  fi

  # --- Firefox / enterprise policy ---------------------------------------
  # Matches PLAYWRIGHT_FIREFOX_POLICIES_JSON set in config.playwright.yml.
  policies_path="/tmp/playwright-firefox-policies.json"
  # Build a JSON array of cert paths. Paths under /usr/local/share/ca-
  # certificates/ are controlled by DDEV and never contain quotes, so a
  # direct literal is safe.
  cert_list=""
  for cert in "${certs[@]}"; do
    [ -n "$cert_list" ] && cert_list+=", "
    cert_list+="\"$cert\""
  done
  cat > "$policies_path" <<EOF
{
  "policies": {
    "Certificates": {
      "Install": [$cert_list]
    }
  }
}
EOF
) || echo "mkcert-nssdb: CA trust setup failed (non-fatal)" >&2
