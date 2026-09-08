#!/usr/bin/env bash

# Cloud Infrastructure Operations Lab
# Lab 04 — Validação do gerenciamento de arquivos no Linux
# Modo: somente leitura

WORKSPACE="${HOME}/cloud-operations-lab/lab04-file-management"

SUCCESS_COUNT=0
WARNING_COUNT=0
FAILURE_COUNT=0

print_section() {
    printf "\n============================================================\n"
    printf "%s\n" "$1"
    printf "============================================================\n"
}

record_success() {
    printf "[OK]    %s\n" "$1"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
}

record_warning() {
    printf "[AVISO] %s\n" "$1"
    WARNING_COUNT=$((WARNING_COUNT + 1))
}

record_failure() {
    printf "[FALHA] %s\n" "$1"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
}

check_directory() {
    local path="$1"
    local description="$2"

    if [ -d "$path" ]; then
        record_success "$description"
    else
        record_failure "$description"
    fi
}

check_file() {
    local path="$1"
    local description="$2"

    if [ -f "$path" ]; then
        record_success "$description"
    else
        record_failure "$description"
    fi
}

check_content() {
    local path="$1"
    local pattern="$2"
    local description="$3"

    if [ -f "$path" ] && grep -qE "$pattern" "$path"; then
        record_success "$description"
    else
        record_failure "$description"
    fi
}

printf "\nCloud Infrastructure Operations Lab\n"
printf "Lab 04 — Validação do gerenciamento de arquivos no Linux\n"
printf "Modo: somente leitura\n"

print_section "1. Ambiente Linux"

if [ "$(uname -s)" = "Linux" ]; then
    record_success "Sistema operacional Linux identificado."
    printf "        Kernel: %s\n" "$(uname -r)"
    printf "        Arquitetura: %s\n" "$(uname -m)"
else
    record_failure "O sistema operacional não foi identificado como Linux."
fi

if [ -n "${BASH_VERSION:-}" ]; then
    record_success "Shell Bash disponível."
    printf "        Versão: %s\n" "$BASH_VERSION"
else
    record_failure "O script não está sendo executado pelo Bash."
fi

if [ -d "$WORKSPACE" ]; then
    record_success "Workspace do Lab 04 localizado."
    printf "        %s\n" "$WORKSPACE"
else
    record_failure "Workspace do Lab 04 não localizado."
fi

print_section "2. Estrutura de diretórios"

check_directory "$WORKSPACE/documents" \
    "Diretório documents disponível."

check_directory "$WORKSPACE/backups" \
    "Diretório backups disponível."

check_directory "$WORKSPACE/logs" \
    "Diretório logs disponível."

check_directory "$WORKSPACE/logs/archive" \
    "Diretório de logs arquivados disponível."

print_section "3. Arquivos do laboratório"

check_file "$WORKSPACE/documents/overview.txt" \
    "Documento overview.txt disponível."

check_file "$WORKSPACE/documents/environment.conf" \
    "Configuração environment.conf disponível."

check_file "$WORKSPACE/backups/overview.txt.bak" \
    "Backup de overview.txt disponível."

check_file "$WORKSPACE/backups/environment.conf.bak" \
    "Backup de environment.conf disponível."

check_file "$WORKSPACE/logs/application.log" \
    "Log da aplicação disponível."

check_file "$WORKSPACE/logs/archive/system-2026-09-08.log" \
    "Log do sistema arquivado disponível."

print_section "4. Conteúdo e integridade"

check_content "$WORKSPACE/documents/overview.txt" \
    "^Cloud Infrastructure Operations Lab$" \
    "Identificação do laboratório confirmada."

check_content "$WORKSPACE/documents/environment.conf" \
    "^environment=development$" \
    "Ambiente development confirmado."

check_content "$WORKSPACE/documents/environment.conf" \
    "^region=us-east-1$" \
    "Região us-east-1 confirmada."

if cmp -s \
    "$WORKSPACE/documents/overview.txt" \
    "$WORKSPACE/backups/overview.txt.bak"; then
    record_success "Backup de overview.txt íntegro."
else
    record_failure "Backup de overview.txt diferente do original."
fi

if cmp -s \
    "$WORKSPACE/documents/environment.conf" \
    "$WORKSPACE/backups/environment.conf.bak"; then
    record_success "Backup de environment.conf íntegro."
else
    record_failure "Backup de environment.conf diferente do original."
fi

check_content "$WORKSPACE/logs/application.log" \
    "ERROR Connection timeout" \
    "Evento ERROR localizado no log da aplicação."

check_content "$WORKSPACE/logs/archive/system-2026-09-08.log" \
    "WARNING Disk usage above baseline" \
    "Evento WARNING localizado no log arquivado."

print_section "5. Cleanup"

if [ ! -e "$WORKSPACE/temporary" ]; then
    record_success "Estrutura temporária removida."
else
    record_warning "A estrutura temporária ainda existe."
fi

print_section "6. Resumo"

printf "[OK]     %d\n" "$SUCCESS_COUNT"
printf "[AVISO]  %d\n" "$WARNING_COUNT"
printf "[FALHA]  %d\n" "$FAILURE_COUNT"

if [ "$FAILURE_COUNT" -gt 0 ]; then
    printf "\nResultado: validação concluída com falhas.\n"
    exit 1
fi

if [ "$WARNING_COUNT" -gt 0 ]; then
    printf "\nResultado: validação concluída com avisos.\n"
    exit 0
fi

printf "\nResultado: gerenciamento de arquivos validado com sucesso.\n"
exit 0
