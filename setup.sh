#! /usr/bin/env nix-shell
#! nix-shell -i bash --packages git sops cryptsetup headscale jq
set -e

hostname=""
remote="vps2-de-berlin"
remote_sock="/run/headscale/headscale.sock"
local_sock="/tmp/headscale-tunnel.sock"
sops_file="secrets/tailscale.yaml"


sshKeys() {
    mkdir -p secrets/$hostname

    ed25519key=/tmp/ed25519
    rsakey=/tmp/rsa

    ssh-keygen -t ed25519 -N "" -f $ed25519key
    ssh-keygen -t rsa -N "" -f $rsakey
    echo $ed25519key
    echo $rsakey
    printf "ssh_host_ed25519_key: |+\n$(awk '{print "    " $0}' ${ed25519key})\nssh_host_rsa_key: |+\n$(awk '{print "    " $0}' $rsakey)\n" > ./secrets/$hostname/sshd.yaml
    rm $ed25519key $rsakey
    sops -i -e secrets/$hostname/sshd.yaml
    git add secrets/$hostname/sshd.yaml
    git commit -o secrets/$hostname/sshd.yaml -m "$hostname: Added ssh hostkeys for $hostname"
}

updateTailscale() {
    # Remove leftover socket file if needed
    rm -f "${local_sock}"

    # Start SSH tunnel in background
    ssh -o ExitOnForwardFailure=yes \
        -o StreamLocalBindUnlink=yes \
        -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
        -N -L "${local_sock}:${remote_sock}" "${remote}" &
    local ssh_pid=$!

    # Define cleanup
    cleanup() {
        kill "${ssh_pid}" 2>/dev/null || true
        wait "${ssh_pid}" 2>/dev/null || true
        rm -f "${local_sock}" /tmp/headscale.config
        trap - RETURN SIGINT SIGTERM
    }

    # Trap on function return, Ctrl-C, and termination
    trap cleanup RETURN SIGINT SIGTERM

    # Wait for the local socket to appear (timeout 5s)
    local timeout=5
    for ((i=0; i<timeout*10; i++)); do
        [[ -S "${local_sock}" ]] && break
        sleep 0.1
    done

    if [[ ! -S "${local_sock}" ]]; then
        echo "Failed to create local socket ${local_sock}" >&2
        cleanup
        return 1
    fi

    echo "Tunnel ready at ${local_sock}"

    printf "disable_check_updates: true\nunix_socket: /tmp/headscale-tunnel.sock" > /tmp/headscale.config

    # Set configfile
    HEADSCALE_CONFIG=/tmp/headscale.config

    # Fetch user list

    mapfile -t headscaleusers < <(
        headscale users list -o json |
        jq -r '.[] | "\(.id) \(.name)"'
    )


    # Detect "-h" in additional args
    show_only=false
    for arg in "$@"; do
        if [ "$arg" = "-h" ]; then
            show_only=true
            break
        fi
    done

    printf "Fetched %d users from headscale\n" "${#headscaleusers[@]}"

    # Generate new auth keys and write them all to one SOPS file
    for entry in "${headscaleusers[@]}"; do
        read -r user_id long_user <<<"$entry"

        short_user="${long_user%@account.honermann.info}"
        echo "Creating auth key for user: ${short_user} (id=${user_id})"

        auth_output=$(headscale preauthkeys create --reusable -u "${user_id}" "$@")

        if [ "$show_only" = true ]; then
            echo "$auth_output"
            return 0  # or exit 0 if this is a script
        fi

        sops --set "[\"${short_user}-auth-key\"] \"${auth_output}\"" "${sops_file}"
        echo "Updated ${sops_file} with ${short_user}-auth-key"
    done
}

printHelp() {
    echo Usage:
    echo    ./setup.sh sshKeys \<hostname\>
    echo    ./setup.sh tailscale [-e 10m] \#all other params are passed to the headscale command see -h
}

cd $(dirname "$0")
pwd
case $1 in
    sshKeys)
        hostname=$2
        sshKeys
        exit 0
        ;;
    tailscale)
        updateTailscale "${@:2}"
        exit 0
        ;;
    *)
        echo Unknown Command
        printHelp
        exit 1
        ;;
esac
