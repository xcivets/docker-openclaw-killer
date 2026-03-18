#!/usr/bin/env bash

set -euo pipefail

readonly DEFAULT_NAME_REGEX='^openclaw([._-].+)?$'
readonly DEFAULT_IMAGE_REGEX='(^|.*/)openclaw([._-].+)?(:[^/]+)?$'

DRY_RUN=0
ASSUME_YES=0
REMOVE_IMAGES=0
REMOVE_DIR=1
NAME_REGEX="${OPENCLAW_NAME_REGEX:-$DEFAULT_NAME_REGEX}"
IMAGE_REGEX="${OPENCLAW_IMAGE_REGEX:-$DEFAULT_IMAGE_REGEX}"
TARGET_DIR_INPUT="${OPENCLAW_DIR:-$HOME/openclaw}"

CONTAINERS_FILE=""
IMAGES_FILE=""
VOLUMES_FILE=""
NETWORKS_FILE=""

usage() {
    cat <<'EOF'
Usage: docker-openclaw-killer.safe.sh [options]

Safely remove Docker resources that belong to OpenClaw.

Options:
  -n, --dry-run        Show what would be removed without changing anything
  -y, --yes            Skip confirmation
      --remove-images  Remove matching OpenClaw images
      --keep-dir       Do not remove the local OpenClaw directory
  -h, --help           Show this help message

Environment:
  OPENCLAW_DIR         Local directory to remove (default: ~/openclaw)
  OPENCLAW_NAME_REGEX  Safe regex for container/volume/network names
  OPENCLAW_IMAGE_REGEX Safe regex for image references

Default matching is intentionally narrow:
  names:  ^openclaw([._-].+)?$
  images: (^|.*/)openclaw([._-].+)?(:[^/]+)?$
EOF
}

log() {
    printf '%s\n' "$*"
}

warn() {
    printf 'Warning: %s\n' "$*" >&2
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    rm -f "${CONTAINERS_FILE:-}" "${IMAGES_FILE:-}" "${VOLUMES_FILE:-}" "${NETWORKS_FILE:-}"
}

trap cleanup EXIT

print_cmd() {
    local arg
    printf '  +'
    for arg in "$@"; do
        printf ' %q' "$arg"
    done
    printf '\n'
}

run_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        print_cmd "$@"
    else
        "$@"
    fi
}

append_unique() {
    local file="$1"
    local value="$2"

    [ -n "$value" ] || return 0

    if [ ! -f "$file" ] || ! grep -Fqx -- "$value" "$file"; then
        printf '%s\n' "$value" >> "$file"
    fi
}

confirm() {
    local prompt="$1"
    local answer

    if [ "$ASSUME_YES" -eq 1 ] || [ "$DRY_RUN" -eq 1 ]; then
        return 0
    fi

    printf '%s [y/N] ' "$prompt"
    read -r answer
    case "$answer" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

require_docker() {
    command -v docker >/dev/null 2>&1 || die "docker is not installed."
    docker info >/dev/null 2>&1 || die "Docker daemon is not running."
}

resolve_existing_dir() {
    local dir="$1"
    [ -d "$dir" ] || return 1
    (
        cd "$dir" >/dev/null 2>&1 &&
        pwd -P
    )
}

validated_target_dir() {
    local resolved base

    [ -n "$TARGET_DIR_INPUT" ] || return 1
    [ -d "$TARGET_DIR_INPUT" ] || return 1

    resolved="$(resolve_existing_dir "$TARGET_DIR_INPUT")" || return 1
    base="$(basename "$resolved")"

    case "$resolved" in
        /|"$HOME")
            return 1
            ;;
        "$HOME"/*)
            ;;
        *)
            return 1
            ;;
    esac

    if ! printf '%s\n' "$base" | grep -Eqi 'openclaw'; then
        return 1
    fi

    printf '%s\n' "$resolved"
}

find_matching_containers() {
    local container_id=""
    local container_name=""
    local container_image=""

    docker ps -a --format '{{.ID}}\t{{.Names}}\t{{.Image}}' | while IFS=$'\t' read -r container_id container_name container_image; do
        [ -n "$container_id" ] || continue
        if printf '%s\n' "$container_name" | grep -Eq "$NAME_REGEX" || printf '%s\n' "$container_image" | grep -Eq "$IMAGE_REGEX"; then
            printf '%s\t%s\n' "$container_id" "$container_name"
        fi
    done
}

find_matching_images() {
    local image_ref=""

    docker images --format '{{.Repository}}:{{.Tag}}' | while IFS= read -r image_ref; do
        [ -n "$image_ref" ] || continue
        case "$image_ref" in
            "<none>:<none>")
                continue
                ;;
        esac
        if printf '%s\n' "$image_ref" | grep -Eq "$IMAGE_REGEX"; then
            printf '%s\n' "$image_ref"
        fi
    done
}

find_matching_volumes() {
    local volume_name=""

    docker volume ls --format '{{.Name}}' | while IFS= read -r volume_name; do
        [ -n "$volume_name" ] || continue
        if printf '%s\n' "$volume_name" | grep -Eq "$NAME_REGEX"; then
            printf '%s\n' "$volume_name"
        fi
    done
}

find_matching_networks() {
    local network_name=""

    docker network ls --format '{{.Name}}' | while IFS= read -r network_name; do
        [ -n "$network_name" ] || continue
        case "$network_name" in
            bridge|host|none)
                continue
                ;;
        esac
        if printf '%s\n' "$network_name" | grep -Eq "$NAME_REGEX"; then
            printf '%s\n' "$network_name"
        fi
    done
}

collect_resources_for_container() {
    local container_id="$1"
    local image_ref=""
    local name=""

    image_ref="$(docker inspect --format '{{.Config.Image}}' "$container_id" 2>/dev/null || true)"
    if [ -n "$image_ref" ] && printf '%s\n' "$image_ref" | grep -Eq "$IMAGE_REGEX"; then
        append_unique "$IMAGES_FILE" "$image_ref"
    fi

    while IFS= read -r name; do
        [ -n "$name" ] || continue
        if printf '%s\n' "$name" | grep -Eq "$NAME_REGEX"; then
            append_unique "$VOLUMES_FILE" "$name"
        fi
    done <<EOF
$(docker inspect --format '{{range .Mounts}}{{if eq .Type "volume"}}{{println .Name}}{{end}}{{end}}' "$container_id" 2>/dev/null || true)
EOF

    while IFS= read -r name; do
        [ -n "$name" ] || continue
        case "$name" in
            bridge|host|none)
                continue
                ;;
        esac
        if printf '%s\n' "$name" | grep -Eq "$NAME_REGEX"; then
            append_unique "$NETWORKS_FILE" "$name"
        fi
    done <<EOF
$(docker inspect --format '{{range $network, $_ := .NetworkSettings.Networks}}{{println $network}}{{end}}' "$container_id" 2>/dev/null || true)
EOF
}

print_section() {
    local title="$1"
    local file="$2"

    log "$title"
    if [ -s "$file" ]; then
        sed 's/^/  - /' "$file"
    else
        log "  - none"
    fi
}

remove_containers() {
    local line container_id container_name

    [ -s "$CONTAINERS_FILE" ] || return 0

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        container_id="${line%%$'\t'*}"
        container_name="${line#*$'\t'}"
        log "Removing container: $container_name ($container_id)"
        run_cmd docker rm -f "$container_id"
    done < "$CONTAINERS_FILE"
}

remove_images() {
    local image_ref

    [ "$REMOVE_IMAGES" -eq 1 ] || return 0
    [ -s "$IMAGES_FILE" ] || return 0

    while IFS= read -r image_ref; do
        [ -n "$image_ref" ] || continue
        if docker ps -a --filter "ancestor=$image_ref" -q | grep -q .; then
            warn "Skipping image still used by a container: $image_ref"
            continue
        fi
        log "Removing image: $image_ref"
        run_cmd docker image rm "$image_ref"
    done < "$IMAGES_FILE"
}

remove_volumes() {
    local volume_name

    [ -s "$VOLUMES_FILE" ] || return 0

    while IFS= read -r volume_name; do
        [ -n "$volume_name" ] || continue
        if docker ps -a --filter "volume=$volume_name" -q | grep -q .; then
            warn "Skipping volume still used by a container: $volume_name"
            continue
        fi
        log "Removing volume: $volume_name"
        run_cmd docker volume rm "$volume_name"
    done < "$VOLUMES_FILE"
}

remove_networks() {
    local network_name attached

    [ -s "$NETWORKS_FILE" ] || return 0

    while IFS= read -r network_name; do
        [ -n "$network_name" ] || continue
        attached="$(docker network inspect --format '{{len .Containers}}' "$network_name" 2>/dev/null || printf 'missing')"
        case "$attached" in
            missing)
                continue
                ;;
            0)
                log "Removing network: $network_name"
                run_cmd docker network rm "$network_name"
                ;;
            *)
                warn "Skipping network still used by active attachments: $network_name"
                ;;
        esac
    done < "$NETWORKS_FILE"
}

remove_target_dir() {
    local safe_dir="$1"

    [ "$REMOVE_DIR" -eq 1 ] || return 0
    [ -n "$safe_dir" ] || return 0

    log "Removing local directory: $safe_dir"
    run_cmd rm -rf -- "$safe_dir"
}

verify_state() {
    local safe_dir="$1"
    local verify_failed=0
    local verify_containers=""
    local verify_images=""
    local verify_volumes=""
    local verify_networks=""

    log
    log "Verification"
    log "----------"

    verify_containers="$(mktemp)"
    verify_images="$(mktemp)"
    verify_volumes="$(mktemp)"
    verify_networks="$(mktemp)"

    find_matching_containers > "$verify_containers"
    find_matching_images > "$verify_images"
    find_matching_volumes > "$verify_volumes"
    find_matching_networks > "$verify_networks"

    log "Matching containers still present:"
    if [ -s "$verify_containers" ]; then
        sed 's/^/  - /' "$verify_containers"
        verify_failed=1
    else
        log "  - none"
    fi

    if [ "$REMOVE_IMAGES" -eq 1 ]; then
        log "Matching image references still present:"
        if [ -s "$verify_images" ]; then
            sed 's/^/  - /' "$verify_images"
            verify_failed=1
        else
            log "  - none"
        fi
    fi

    log "Matching volumes still present:"
    if [ -s "$verify_volumes" ]; then
        sed 's/^/  - /' "$verify_volumes"
        verify_failed=1
    else
        log "  - none"
    fi

    log "Matching networks still present:"
    if [ -s "$verify_networks" ]; then
        sed 's/^/  - /' "$verify_networks"
        verify_failed=1
    else
        log "  - none"
    fi

    if [ "$REMOVE_DIR" -eq 1 ]; then
        log "Local directory status:"
        if [ -n "$safe_dir" ] && [ -d "$safe_dir" ]; then
            log "  - still exists: $safe_dir"
            verify_failed=1
        else
            log "  - not present"
        fi
    fi

    log
    if [ "$verify_failed" -eq 0 ]; then
        log "Verification PASSED."
    else
        log "Verification FAILED."
    fi

    rm -f "$verify_containers" "$verify_images" "$verify_volumes" "$verify_networks"
    return "$verify_failed"
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -n|--dry-run)
                DRY_RUN=1
                ;;
            -y|--yes)
                ASSUME_YES=1
                ;;
            --remove-images)
                REMOVE_IMAGES=1
                ;;
            --keep-dir)
                REMOVE_DIR=0
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage >&2
                die "unknown option: $1"
                ;;
        esac
        shift
    done
}

main() {
    local safe_dir=""
    local line container_id
    local image_ref=""
    local volume_name=""
    local network_name=""
    local verify_status=0

    parse_args "$@"
    require_docker

    CONTAINERS_FILE="$(mktemp)"
    IMAGES_FILE="$(mktemp)"
    VOLUMES_FILE="$(mktemp)"
    NETWORKS_FILE="$(mktemp)"

    while IFS= read -r line; do
        [ -n "$line" ] || continue
        printf '%s\n' "$line" >> "$CONTAINERS_FILE"
        container_id="${line%%$'\t'*}"
        collect_resources_for_container "$container_id"
    done <<EOF
$(find_matching_containers)
EOF

    while IFS= read -r image_ref; do
        append_unique "$IMAGES_FILE" "$image_ref"
    done <<EOF
$(find_matching_images)
EOF

    while IFS= read -r volume_name; do
        append_unique "$VOLUMES_FILE" "$volume_name"
    done <<EOF
$(find_matching_volumes)
EOF

    while IFS= read -r network_name; do
        append_unique "$NETWORKS_FILE" "$network_name"
    done <<EOF
$(find_matching_networks)
EOF

    if [ "$REMOVE_DIR" -eq 1 ]; then
        safe_dir="$(validated_target_dir || true)"
        if [ -n "$TARGET_DIR_INPUT" ] && [ ! -d "$TARGET_DIR_INPUT" ]; then
            warn "Local directory not found, skipping: $TARGET_DIR_INPUT"
        elif [ -z "$safe_dir" ] && [ -d "$TARGET_DIR_INPUT" ]; then
            warn "Refusing to delete unsafe directory path: $TARGET_DIR_INPUT"
        fi
    fi

    log "OpenClaw cleanup plan"
    log "---------------------"
    log "Name regex:  $NAME_REGEX"
    if [ "$REMOVE_IMAGES" -eq 1 ]; then
        log "Image regex: $IMAGE_REGEX"
    fi
    print_section "Containers to remove:" "$CONTAINERS_FILE"
    if [ "$REMOVE_IMAGES" -eq 1 ]; then
        print_section "Images to remove:" "$IMAGES_FILE"
    fi
    print_section "Volumes to remove:" "$VOLUMES_FILE"
    print_section "Networks to remove:" "$NETWORKS_FILE"
    if [ "$REMOVE_DIR" -eq 1 ]; then
        if [ -n "$safe_dir" ]; then
            log "Local directory to remove:"
            log "  - $safe_dir"
        else
            log "Local directory to remove:"
            log "  - none"
        fi
    fi

    if [ ! -s "$CONTAINERS_FILE" ] && [ ! -s "$VOLUMES_FILE" ] && [ ! -s "$NETWORKS_FILE" ] && [ -z "$safe_dir" ] && { [ "$REMOVE_IMAGES" -eq 0 ] || [ ! -s "$IMAGES_FILE" ]; }; then
        log
        log "Nothing matched. Exiting."
        exit 0
    fi

    if ! confirm "Proceed with cleanup?"; then
        log "Cancelled."
        exit 1
    fi

    log
    log "Executing cleanup"
    log "------------------"
    remove_containers
    remove_images
    remove_volumes
    remove_networks
    remove_target_dir "$safe_dir"

    if [ "$DRY_RUN" -eq 1 ]; then
        log
        log "Dry run complete. No changes were made."
        exit 0
    fi

    if verify_state "$safe_dir"; then
        verify_status=0
    else
        verify_status=$?
    fi

    exit "$verify_status"
}

main "$@"
