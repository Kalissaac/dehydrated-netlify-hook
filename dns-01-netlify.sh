#!/usr/bin/env bash

# dns-01 challenge for Netlify
# https://open-api.netlify.com

set -euo pipefail

# Netlify personal access token
# create one at https://app.netlify.com/user/applications#personal-access-tokens
NETLIFY_TOKEN="<replace with token>"

deploy_challenge() {
  local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

  # This hook is called once for every domain that needs to be
  # validated, including any alternative names you may have listed.
  #
  # Parameters:
  # - DOMAIN
  #   The domain name (CN or subject alternative name) being
  #   validated.
  # - TOKEN_FILENAME
  #   The name of the file containing the token to be served for HTTP
  #   validation. Should be served by your web server as
  #   /.well-known/acme-challenge/${TOKEN_FILENAME}.
  # - TOKEN_VALUE
  #   The token value that needs to be served for validation. For DNS
  #   validation, this is what you want to put in the _acme-challenge
  #   TXT record. For HTTP validation it is the value that is expected
  #   be found in the $TOKEN_FILENAME file.

  local NETLIFY_ZONE_ID="$(find_netlify_zone_for_domain "${DOMAIN}")"

  if [ -z "${NETLIFY_ZONE_ID}" ]; then
    echo "zone for ${DOMAIN} not found"
    exit 1
  fi

  netlify_api_request "POST" "/dns_zones/${NETLIFY_ZONE_ID}/dns_records" "{\"type\":\"TXT\",\"hostname\":\"_acme-challenge.${DOMAIN}\",\"value\":\"${TOKEN_VALUE}\"}" > /dev/null
}

clean_challenge() {
  local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

  # This hook is called after attempting to validate each domain,
  # whether or not validation was successful. Here you can delete
  # files or DNS records that are no longer needed.
  #
  # The parameters are the same as for deploy_challenge.

  local NETLIFY_ZONE_ID="$(find_netlify_zone_for_domain "${DOMAIN}")"

  if [ -z "${NETLIFY_ZONE_ID}" ]; then
    echo "zone for ${DOMAIN} not found"
    exit 1
  fi

  local NETLIFY_RECORD_ID="$( \
    netlify_api_request "GET" "/dns_zones/${NETLIFY_ZONE_ID}/dns_records" | \
    python3 -c "import sys, json; records = json.load(sys.stdin); matching_records = [record['id'] for record in records if record['type'] == 'TXT' and record['hostname'] == '_acme-challenge.${DOMAIN}' and record['value'] == '${TOKEN_VALUE}']; print(next(iter(matching_records), ''))" \
  )"

  if [ -z "${NETLIFY_RECORD_ID}" ]; then
    echo "record for _acme-challenge.${DOMAIN} not found"
    exit 1
  fi

  netlify_api_request "DELETE" "/dns_zones/${NETLIFY_ZONE_ID}/dns_records/${NETLIFY_RECORD_ID}" > /dev/null
}

netlify_api_request() {
  local METHOD="${1}" REQUEST_PATH="${2}" BODY="${3:-}"
  if [ -z "${BODY}" ]; then
      curl -sS \
        -H "User-Agent: dehydrated-netlify-hook" \
        -H "Authorization: Bearer ${NETLIFY_TOKEN}" \
        -X "${METHOD}" \
        "https://api.netlify.com/api/v1/${REQUEST_PATH}"
  else
      curl -sS \
        -H "User-Agent: dehydrated-netlify-hook" \
        -H "Authorization: Bearer ${NETLIFY_TOKEN}" \
        -H "Content-Type: application/json" \
        -X "${METHOD}" \
        -d "${BODY}" \
        "https://api.netlify.com/api/v1/${REQUEST_PATH}"
  fi
}

find_netlify_zone_for_domain() {
  local DOMAIN="${1}"
  netlify_api_request "GET" "/dns_zones" | \
  python3 -c "import sys, operator, json; zones = json.load(sys.stdin); closest_zone = max(((zone['id'], len(zone['name'])) for zone in zones if '${DOMAIN}'.endswith(zone['name'])), default=('', 0), key=operator.itemgetter(1)); print(closest_zone[0])"
}


HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge)$ ]]; then
  "$HANDLER" "$@"
fi
