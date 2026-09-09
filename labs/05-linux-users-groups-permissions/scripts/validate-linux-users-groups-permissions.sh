#!/usr/bin/env bash

# Cloud Infrastructure Operations Lab
# Lab 05 — Linux users, groups and permissions validation
# Validation mode: read-only

set -u

LAB_USER_1="lab05user1"
LAB_USER_2="lab05user2"
LAB_GROUP="cloudops-lab05"
LAB_BASE="/srv/cloudops-lab05"
SHARED_DIRECTORY="$LAB_BASE/shared"

SUCCESS_COUNT=0
WARNING_COUNT=0
FAILURE_COUNT=0

print_section() {
    printf "\n"
    printf '%s\n' "============================================================"
    printf '%s\n' "$1"
    printf '%s\n' "============================================================"
}

record_success() {
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    printf "[OK]    %s\n" "$1"
}

record_warning() {
    WARNING_COUNT=$((WARNING_COUNT + 1))
    printf "[AVISO] %s\n" "$1"
}

record_failure() {
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
    printf "[FALHA] %s\n" "$1"
}

check_command() {
    local command_name="$1"

    if command -v "$command_name" >/dev/null 2>&1; then
        record_success "Comando disponível: $command_name."
    else
        record_failure "Comando não localizado: $command_name."
    fi
}

check_account() {
    local account_name="$1"

    if getent passwd "$account_name" >/dev/null; then
        record_success "Conta localizada: $account_name."
        printf "        %s\n" "$(getent passwd "$account_name")"
    else
        record_failure "Conta não localizada: $account_name."
    fi
}

check_group_member() {
    local account_name="$1"
    local group_name="$2"

    if id --groups --name "$account_name" 2>/dev/null |
        tr ' ' '\n' |
        grep -Fxq "$group_name"; then
        record_success "$account_name pertence ao grupo $group_name."
    else
        record_failure "$account_name não pertence ao grupo $group_name."
    fi
}

check_password_locked() {
    local account_name="$1"
    local password_status

    password_status="$(passwd --status "$account_name" 2>/dev/null |
        awk '{print $2}')"

    if [ "$password_status" = "L" ]; then
        record_success "Senha da conta $account_name permanece bloqueada."
    else
        record_failure "Estado inesperado da senha de $account_name: $password_status."
    fi
}

check_directory() {
    local directory_path="$1"

    if [ -d "$directory_path" ]; then
        record_success "Diretório disponível: $directory_path."
    else
        record_failure "Diretório não localizado: $directory_path."
    fi
}

check_file() {
    local file_path="$1"

    if [ -f "$file_path" ]; then
        record_success "Arquivo disponível: $file_path."
    else
        record_failure "Arquivo não localizado: $file_path."
    fi
}

check_owner_group_mode() {
    local path="$1"
    local expected_owner="$2"
    local expected_group="$3"
    local expected_mode="$4"

    local actual_owner
    local actual_group
    local actual_mode

    if [ ! -e "$path" ]; then
        record_failure "Objeto não localizado para validação: $path."
        return
    fi

    actual_owner="$(stat --format='%U' "$path")"
    actual_group="$(stat --format='%G' "$path")"
    actual_mode="$(stat --format='%a' "$path")"

    if [ "$actual_owner" = "$expected_owner" ] &&
        [ "$actual_group" = "$expected_group" ] &&
        [ "$actual_mode" = "$expected_mode" ]; then

        record_success \
            "$path possui $actual_owner:$actual_group e modo $actual_mode."
    else
        record_failure \
            "$path possui $actual_owner:$actual_group e modo $actual_mode; esperado $expected_owner:$expected_group e modo $expected_mode."
    fi
}

check_content() {
    local file_path="$1"
    local expected_text="$2"
    local description="$3"

    if [ -f "$file_path" ] &&
        grep -Fq "$expected_text" "$file_path"; then
        record_success "$description"
    else
        record_failure "$description"
    fi
}

printf "\n"
printf '%s\n' "Cloud Infrastructure Operations Lab"
printf '%s\n' "Lab 05 — Validação de usuários, grupos e permissões no Linux"
printf '%s\n' "Modo: somente leitura"

if [ "$(id -u)" -ne 0 ]; then
    printf "\n"
    printf '%s\n' "[FALHA] Execute este validador com privilégios administrativos:"
    printf '%s\n' "sudo bash validate-linux-users-groups-permissions.sh"
    exit 1
fi

print_section "1. Ambiente e ferramentas"

if [ "$(uname -s)" = "Linux" ]; then
    record_success "Sistema operacional Linux identificado."
    printf "        Kernel: %s\n" "$(uname -r)"
    printf "        Arquitetura: %s\n" "$(uname -m)"
else
    record_failure "O ambiente atual não foi identificado como Linux."
fi

check_command getent
check_command id
check_command stat
check_command grep
check_command runuser

print_section "2. Contas temporárias"

check_account "$LAB_USER_1"
check_account "$LAB_USER_2"

if [ "$(getent passwd "$LAB_USER_1" | cut -d: -f7)" = "/bin/bash" ]; then
    record_success "$LAB_USER_1 utiliza o shell /bin/bash."
else
    record_failure "$LAB_USER_1 não utiliza o shell esperado."
fi

if [ "$(getent passwd "$LAB_USER_2" | cut -d: -f7)" = "/bin/bash" ]; then
    record_success "$LAB_USER_2 utiliza o shell /bin/bash."
else
    record_failure "$LAB_USER_2 não utiliza o shell esperado."
fi

if [ -d "/home/$LAB_USER_1" ]; then
    record_success "Diretório pessoal de $LAB_USER_1 disponível."
else
    record_failure "Diretório pessoal de $LAB_USER_1 não localizado."
fi

if [ -d "/home/$LAB_USER_2" ]; then
    record_success "Diretório pessoal de $LAB_USER_2 disponível."
else
    record_failure "Diretório pessoal de $LAB_USER_2 não localizado."
fi

check_password_locked "$LAB_USER_1"
check_password_locked "$LAB_USER_2"

print_section "3. Grupo e associações"

if getent group "$LAB_GROUP" >/dev/null; then
    record_success "Grupo localizado: $LAB_GROUP."
    printf "        %s\n" "$(getent group "$LAB_GROUP")"
else
    record_failure "Grupo não localizado: $LAB_GROUP."
fi

check_group_member "$LAB_USER_1" "$LAB_GROUP"
check_group_member "$LAB_USER_2" "$LAB_GROUP"

if [ "$(id --group --name "$LAB_USER_1")" = "$LAB_USER_1" ]; then
    record_success "Grupo primário de $LAB_USER_1 preservado."
else
    record_failure "Grupo primário inesperado para $LAB_USER_1."
fi

if [ "$(id --group --name "$LAB_USER_2")" = "$LAB_USER_2" ]; then
    record_success "Grupo primário de $LAB_USER_2 preservado."
else
    record_failure "Grupo primário inesperado para $LAB_USER_2."
fi

print_section "4. Diretório compartilhado"

check_directory "$LAB_BASE"
check_directory "$SHARED_DIRECTORY"

check_owner_group_mode \
    "$LAB_BASE" \
    "root" \
    "$LAB_GROUP" \
    "770"

check_owner_group_mode \
    "$SHARED_DIRECTORY" \
    "root" \
    "$LAB_GROUP" \
    "2770"

if [ -g "$SHARED_DIRECTORY" ]; then
    record_success "SGID ativo no diretório compartilhado."
else
    record_failure "SGID não está ativo no diretório compartilhado."
fi

print_section "5. Arquivos anteriores ao SGID"

check_file "$SHARED_DIRECTORY/user1-baseline.txt"
check_file "$SHARED_DIRECTORY/user2-baseline.txt"

check_owner_group_mode \
    "$SHARED_DIRECTORY/user1-baseline.txt" \
    "$LAB_USER_1" \
    "$LAB_USER_1" \
    "664"

check_owner_group_mode \
    "$SHARED_DIRECTORY/user2-baseline.txt" \
    "$LAB_USER_2" \
    "$LAB_USER_2" \
    "664"

print_section "6. Herança de grupo e colaboração"

check_file "$SHARED_DIRECTORY/user1-shared.txt"
check_file "$SHARED_DIRECTORY/user2-shared.txt"

check_owner_group_mode \
    "$SHARED_DIRECTORY/user1-shared.txt" \
    "$LAB_USER_1" \
    "$LAB_GROUP" \
    "664"

check_owner_group_mode \
    "$SHARED_DIRECTORY/user2-shared.txt" \
    "$LAB_USER_2" \
    "$LAB_GROUP" \
    "664"

check_content \
    "$SHARED_DIRECTORY/user1-shared.txt" \
    "Criado por $LAB_USER_1 após SGID" \
    "Criação do arquivo do primeiro usuário confirmada."

check_content \
    "$SHARED_DIRECTORY/user1-shared.txt" \
    "Atualizado por $LAB_USER_2" \
    "Escrita do segundo usuário no arquivo do primeiro confirmada."

check_content \
    "$SHARED_DIRECTORY/user2-shared.txt" \
    "Criado por $LAB_USER_2 após SGID" \
    "Criação do arquivo do segundo usuário confirmada."

check_content \
    "$SHARED_DIRECTORY/user2-shared.txt" \
    "Atualizado por $LAB_USER_1" \
    "Escrita do primeiro usuário no arquivo do segundo confirmada."

print_section "7. Restrição de acesso"

ORIGINAL_USER="${SUDO_USER:-}"

if [ -n "$ORIGINAL_USER" ] && [ "$ORIGINAL_USER" != "root" ]; then
    if id --groups --name "$ORIGINAL_USER" |
        tr ' ' '\n' |
        grep -Fxq "$LAB_GROUP"; then

        record_warning \
            "A conta original $ORIGINAL_USER pertence ao grupo $LAB_GROUP; o teste de negação não é aplicável."
    elif runuser --user="$ORIGINAL_USER" -- \
        ls "$SHARED_DIRECTORY" >/dev/null 2>&1; then

        record_failure \
            "A conta fora do grupo conseguiu acessar diretamente o diretório."
    else
        record_success \
            "Acesso direto corretamente negado para $ORIGINAL_USER."
    fi
else
    record_warning \
        "Execute com sudo a partir de uma conta comum para validar a restrição de acesso."
fi

print_section "8. Resumo"

printf "[OK]     %d\n" "$SUCCESS_COUNT"
printf "[AVISO]  %d\n" "$WARNING_COUNT"
printf "[FALHA]  %d\n" "$FAILURE_COUNT"

if [ "$FAILURE_COUNT" -gt 0 ]; then
    printf "\n"
    printf '%s\n' "Resultado: validação concluída com falhas."
    exit 1
fi

if [ "$WARNING_COUNT" -gt 0 ]; then
    printf "\n"
    printf '%s\n' "Resultado: validação concluída com avisos."
    exit 0
fi

printf "\n"
printf '%s\n' "Resultado: usuários, grupos e permissões validados com sucesso."
exit 0
