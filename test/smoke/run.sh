#!/bin/bash
# Smoke test without a Cloudron server: read-only rootfs, Postgres, Redis, an SMTP server that requires auth.
# Usage: test/smoke/run.sh   (needs Docker)  IMAGE=<tag> skips the build, KEEP=1 keeps the containers

set -eu

cd "$(dirname "$0")"
readonly root=$(cd ../.. && pwd)
readonly img=${IMAGE:-postiz:smoke}
readonly net=pzsmoke
readonly app=pzsmoke-app
readonly db=pzsmoke-db
readonly redis=pzsmoke-redis
readonly smtp=pzsmoke-smtp
readonly origin=http://127.0.0.1:18001
readonly api=${origin}/api
readonly admin_email=admin@example.com
readonly admin_password=Smoke-Test-123456
failures=0

cleanup() {
    [[ -n "${ARTIFACTS:-}" ]] && { mkdir -p "${ARTIFACTS}"; docker logs "${app}" > "${ARTIFACTS}/app.log" 2>&1 || true; docker logs "${smtp}" > "${ARTIFACTS}/smtp.log" 2>&1 || true; }
    [[ -n "${KEEP:-}" ]] && return
    docker rm -f "${app}" "${db}" "${redis}" "${smtp}" >/dev/null 2>&1 || true
    docker volume rm pzsmoke-data >/dev/null 2>&1 || true
    docker network rm "${net}" >/dev/null 2>&1 || true
}
cleanup
trap cleanup EXIT

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1 :: $2"; failures=$((failures + 1)); }
expect() { if [[ "$3" =~ $2 ]]; then pass "$1"; else fail "$1" "${3:0:300}"; fi; }

wait_for() { # wait_for <seconds> <command...>
    local deadline=$((SECONDS + $1)); shift
    until "$@" >/dev/null 2>&1; do
        (( SECONDS > deadline )) && return 1
        sleep 2
    done
}

healthy() {
    curl -sf ${api}/auth/can-register && docker exec "${app}" curl -sf http://127.0.0.1:3002/health/status
}

workflows() {
    docker exec -e HOME=/run/postiz "${app}" temporal workflow list --address 127.0.0.1:7233
}

[[ -z "${IMAGE:-}" ]] && docker build -t "${img}" "${root}"

docker network create "${net}" >/dev/null
docker run -d --name "${db}" --network "${net}" -e POSTGRES_DB=db -e POSTGRES_USER=user -e POSTGRES_PASSWORD=pass postgres:17-alpine >/dev/null
docker run -d --name "${redis}" --network "${net}" redis:7.2 >/dev/null
docker run -d --name "${smtp}" --network "${net}" -v "${PWD}/smtp-sink.py:/smtp-sink.py:ro" python:3.13-slim \
    sh -c "pip install -q --root-user-action=ignore aiosmtpd==1.4.6 && python -u /smtp-sink.py" >/dev/null
wait_for 60 docker exec "${db}" pg_isready -U user -d db
wait_for 120 docker exec "${smtp}" python -c "import socket; socket.create_connection(('127.0.0.1', 2525))"

docker run -d --name "${app}" --network "${net}" --read-only --tmpfs /run:exec --tmpfs /tmp:exec -v pzsmoke-data:/app/data -m 3g -p 127.0.0.1:18001:5000 \
    -e CLOUDRON_APP_ORIGIN="${origin}" \
    -e CLOUDRON_POSTGRESQL_URL="postgresql://user:pass@${db}:5432/db" \
    -e CLOUDRON_REDIS_URL="redis://${redis}:6379" \
    -e CLOUDRON_MAIL_SMTP_SERVER="${smtp}" -e CLOUDRON_MAIL_SMTP_PORT=2525 -e CLOUDRON_MAIL_SMTP_USERNAME=u -e CLOUDRON_MAIL_SMTP_PASSWORD=p -e CLOUDRON_MAIL_FROM=postiz@example.com \
    "${img}" >/dev/null

if ! wait_for 300 healthy; then
    fail "health" "backend or orchestrator did not become healthy"
    exit 1
fi
pass "health"

expect "frontend" "^200$" "$(curl -s -o /dev/null -w '%{http_code}' ${origin}/auth/login)"
expect "missing post workflow" "Running +missing-post-workflow" "$(workflows)"
expect "search attributes" "organizationId +Text" "$(docker exec -e HOME=/run/postiz "${app}" temporal operator search-attribute list --address 127.0.0.1:7233)"

register() { # register <email>
    curl -s -w ' %{http_code}' -H 'content-type: application/json' ${api}/auth/register \
        -d "{\"email\": \"$1\", \"password\": \"${admin_password}\", \"company\": \"Smoke\", \"provider\": \"LOCAL\"}"
}
expect "first registration" " 200$" "$(register ${admin_email})"
expect "second registration refused" "Registration is disabled 400$" "$(register intruder@example.com)"

if wait_for 60 sh -c "docker logs ${smtp} 2>&1 | grep -q '^MAIL'"; then
    expect "activation email sent with auth" "MAIL from postiz@example.com to \['${admin_email}'\] authed True" "$(docker logs ${smtp} 2>&1)"
else
    fail "activation email sent with auth" "no mail received"
fi

docker exec -u cloudron "${app}" sh -c 'printf "<script>alert(1)</script>" > /app/data/uploads/smoke.html'
headers=$(curl -s -D - -o /dev/null ${origin}/uploads/smoke.html)
expect "uploads not executable" "Content-Type: application/octet-stream" "${headers}"
expect "uploads sandboxed" "Content-Security-Policy: default-src 'none'.*sandbox" "${headers}"

docker restart "${app}" >/dev/null
if wait_for 300 healthy; then pass "restart"; else fail "restart" "app did not become healthy"; fi
expect "schema in sync after restart" "already in sync" "$(docker logs --since 5m "${app}" 2>&1)"
expect "missing post workflow after restart" "Running +missing-post-workflow" "$(workflows)"
expect "temporal state persisted" "^[1-9]" "$(docker exec "${app}" stat -c %s /app/data/temporal/temporal.db)"

echo "==> ${failures} failures"
exit $(( failures > 0 ))
