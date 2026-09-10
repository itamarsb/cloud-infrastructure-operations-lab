#!/usr/bin/env bash
set -uo pipefail

SERVICE="cloudops-lab06.service"
ACCOUNT="cloudops-lab06"
BASE="/srv/cloudops-lab06"
SITE="$BASE/site"
UNIT="/etc/systemd/system/$SERVICE"
OVERRIDE_DIR="/etc/systemd/system/$SERVICE.d"
OVERRIDE="$OVERRIDE_DIR/failure.conf"
PORT="8060"
MARKER="CloudOps Lab 06 controlled web service"

section() { printf '\n=== %s ===\n' "$1"; }
ok() { printf '[OK] %s\n' "$1"; }
fail() { printf '[FALHA] %s\n' "$1" >&2; return 1; }

check_environment() {
    [ "$EUID" -eq 0 ] || fail "Execute com sudo." || return 1
    [ -d /run/systemd/system ] || fail "systemd não está disponível." || return 1

    local name

    for name in systemctl journalctl python3 curl ss getent useradd userdel groupdel; do
        command -v "$name" >/dev/null 2>&1 || {
            fail "Comando não encontrado: $name."
            return 1
        }
    done
}

expected_unit() {
    [ -f "$UNIT" ] && grep -Fqx "Description=$MARKER" "$UNIT"
}

expected_account() {
    local entry

    entry="$(getent passwd "$ACCOUNT" 2>/dev/null)" || return 1

    [ "$(printf '%s\n' "$entry" | cut -d: -f6)" = "$BASE" ] &&
        [ "$(printf '%s\n' "$entry" | cut -d: -f7)" = "/usr/sbin/nologin" ]
}

validate() {
    local response
    local attempt
    local http_ready="false"

    section "Validação"

    systemctl is-active --quiet "$SERVICE" || {
        systemctl status "$SERVICE" --no-pager --lines=8 || true
        fail "O serviço não está ativo."
        return 1
    }

    for attempt in 1 2 3 4 5; do
        if response="$(
            curl --fail --silent --max-time 2 \
                "http://127.0.0.1:$PORT/" 2>/dev/null
        )"; then
            http_ready="true"
            break
        fi

        sleep 1
    done

    if [ "$http_ready" != "true" ]; then
        systemctl status "$SERVICE" --no-pager --lines=8 || true
        fail "O endpoint HTTP não respondeu no tempo esperado."
        return 1
    fi

    [[ "$response" == *"CloudOps Lab 06"* ]] || {
        fail "A resposta HTTP não corresponde ao laboratório."
        return 1
    }

    systemctl show "$SERVICE" \
        --property=ActiveState,SubState,MainPID,User,Group \
        --no-pager

    ok "Serviço ativo e endpoint HTTP validado."
}

setup() {
    check_environment || return 1

    section "Verificação dos alvos"

    if [ -e "$UNIT" ] && ! expected_unit; then
        fail "Já existe uma unidade inesperada em $UNIT."
        return 1
    fi

    if getent passwd "$ACCOUNT" >/dev/null 2>&1 && ! expected_account; then
        fail "Já existe uma conta inesperada chamada $ACCOUNT."
        return 1
    fi

    ok "Alvos exclusivos do Lab 06 confirmados."

    section "Instalação"

    if ! getent passwd "$ACCOUNT" >/dev/null 2>&1; then
        useradd \
            --system \
            --home-dir "$BASE" \
            --shell /usr/sbin/nologin \
            --user-group \
            "$ACCOUNT" ||
            return 1
    fi

    install -d -o root -g root -m 0755 "$SITE" || return 1

    printf '%s\n' \
        '<!doctype html>' \
        '<html lang="pt-BR">' \
        '<head><meta charset="utf-8"><title>CloudOps Lab 06</title></head>' \
        '<body><h1>CloudOps Lab 06</h1><p>Serviço operacional.</p></body>' \
        '</html>' \
        >"$SITE/index.html" ||
        return 1

    chmod 0644 "$SITE/index.html" || return 1

    printf '%s\n' \
        '[Unit]' \
        "Description=$MARKER" \
        'After=network.target' \
        '' \
        '[Service]' \
        'Type=simple' \
        "User=$ACCOUNT" \
        "Group=$ACCOUNT" \
        "WorkingDirectory=$SITE" \
        "ExecStart=/usr/bin/python3 -u -m http.server $PORT --bind 127.0.0.1" \
        'Restart=on-failure' \
        'RestartSec=3' \
        'NoNewPrivileges=true' \
        'PrivateTmp=true' \
        'ProtectSystem=strict' \
        'ProtectHome=true' \
        '' \
        '[Install]' \
        'WantedBy=multi-user.target' \
        >"$UNIT" ||
        return 1

    chmod 0644 "$UNIT" || return 1

    systemctl daemon-reload || return 1
    systemctl enable --now "$SERVICE" || return 1

    ok "Serviço instalado e iniciado."
    validate
}

inspect() {
    check_environment || return 1
    expected_unit ||
        fail "A unidade do Lab 06 não foi localizada." ||
        return 1

    section "Estado"
    systemctl status "$SERVICE" --no-pager --lines=10 || true

    section "Porta local"
    ss -ltnp "sport = :$PORT" || true

    section "Logs recentes"
    journalctl -u "$SERVICE" --no-pager --lines=15

    section "Resposta HTTP"
    curl --fail --silent --show-error --max-time 5 \
        "http://127.0.0.1:$PORT/"

    printf '\n'
}

simulate_failure() {
    local attempt
    local exec_status=""
    local failure_confirmed="false"

    check_environment || return 1
    expected_unit ||
        fail "A unidade do Lab 06 não foi localizada." ||
        return 1
    [ ! -e "$OVERRIDE" ] ||
        fail "A falha já está configurada." ||
        return 1

    section "Falha controlada"

    install -d -o root -g root -m 0755 "$OVERRIDE_DIR" || return 1

    printf '[Service]\nWorkingDirectory=%s/missing\n' "$BASE" \
        >"$OVERRIDE" ||
        return 1

    chmod 0644 "$OVERRIDE" || return 1
    systemctl daemon-reload || return 1
    systemctl restart "$SERVICE" >/dev/null 2>&1 || true

    for attempt in 1 2 3 4 5; do
        exec_status="$(
            systemctl show "$SERVICE" \
                --property=ExecMainStatus \
                --value
        )"

        if [ "$exec_status" = "200" ]; then
            failure_confirmed="true"
            break
        fi

        sleep 1
    done

    if [ "$failure_confirmed" != "true" ]; then
        systemctl status "$SERVICE" --no-pager --lines=10 || true
        fail "A falha esperada no diretório de trabalho não foi confirmada."
        return 1
    fi

    if curl --fail --silent --max-time 2 \
        "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
        fail "O endpoint HTTP continuou disponível."
        return 1
    fi

    systemctl status "$SERVICE" --no-pager --lines=10 || true
    ok "Falha controlada reproduzida: status 200/CHDIR."
}

recover() {
    check_environment || return 1
    expected_unit ||
        fail "A unidade do Lab 06 não foi localizada." ||
        return 1
    [ -f "$OVERRIDE" ] ||
        fail "A falha controlada não foi localizada." ||
        return 1

    grep -Fqx "WorkingDirectory=$BASE/missing" "$OVERRIDE" || {
        fail "O override possui conteúdo inesperado e foi preservado."
        return 1
    }

    section "Recuperação"

    rm -- "$OVERRIDE" || return 1
    rmdir -- "$OVERRIDE_DIR" 2>/dev/null || true

    systemctl daemon-reload || return 1
    systemctl reset-failed "$SERVICE" || true
    systemctl restart "$SERVICE" || return 1

    validate
}

cleanup() {
    check_environment || return 1

    section "Cleanup"

    if [ -e "$UNIT" ] && ! expected_unit; then
        fail "Unidade inesperada encontrada. Cleanup cancelado."
        return 1
    fi

    if getent passwd "$ACCOUNT" >/dev/null 2>&1 && ! expected_account; then
        fail "Conta inesperada encontrada. Cleanup cancelado."
        return 1
    fi

    systemctl disable --now "$SERVICE" >/dev/null 2>&1 || true

    if [ -f "$OVERRIDE" ]; then
        grep -Fqx "WorkingDirectory=$BASE/missing" "$OVERRIDE" || {
            fail "Override inesperado encontrado. Cleanup cancelado."
            return 1
        }

        rm -- "$OVERRIDE" || return 1
    fi

    rmdir -- "$OVERRIDE_DIR" 2>/dev/null || true
    rm -f -- "$UNIT" "$SITE/index.html"
    rmdir -- "$SITE" 2>/dev/null || true
    rmdir -- "$BASE" 2>/dev/null || true

    if getent passwd "$ACCOUNT" >/dev/null 2>&1; then
        userdel "$ACCOUNT" || return 1
    fi

    if getent group "$ACCOUNT" >/dev/null 2>&1; then
        groupdel "$ACCOUNT" || return 1
    fi

    systemctl daemon-reload || return 1
    systemctl reset-failed "$SERVICE" >/dev/null 2>&1 || true

    ok "Recursos do Lab 06 removidos."
}

case "${1:-}" in
    setup)
        setup
        ;;
    inspect)
        inspect
        ;;
    simulate-failure)
        simulate_failure
        ;;
    recover)
        recover
        ;;
    validate)
        check_environment &&
            expected_unit &&
            validate
        ;;
    cleanup)
        cleanup
        ;;
    *)
        printf 'Uso: sudo bash %s {setup|inspect|simulate-failure|recover|validate|cleanup}\n' "$0"
        false
        ;;
esac
