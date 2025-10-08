#!/bin/bash

SENTINEL_HOSTS="sentinel-one:26379 sentinel-two:26379 sentinel-three:26379"
HAPROXY_SOCKET="/var/run/haproxy.sock"
CHECK_INTERVAL=30
MASTER_NAME="mymaster"
HAPROXY_BACKEND="redis-proxy"
CURRENT_MASTER=""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

get_master_from_sentinel() {
    for sentinel in $SENTINEL_HOSTS; do
        host=${sentinel%:*}
        port=${sentinel#*:}

        log "Querying sentinel $sentinel for master info"

        master_info=$(redis-cli -h $host -p $port SENTINEL get-master-addr-by-name $MASTER_NAME 2>/dev/null)
        if [ $? -eq 0 ] && [ ! -z "$master_info" ]; then
            # Return in format "IP:PORT" for easy comparison
            master_ip=$(echo "$master_info" | sed -n '1p' | tr -d '"')
            master_port=$(echo "$master_info" | sed -n '2p' | tr -d '"')
            echo "${master_ip}:${master_port}"
            return 0
        fi
    done
    return 1
}

update_master_in_haproxy() {
    local master_info="$1"

    if [ -z "$master_info" ]; then
        log "No master info provided"
        return 1
    fi

    # Parse master info in format "IP:PORT"
    master_ip="${master_info%:*}"
    master_port="${master_info#*:}"

    if [ -z "$master_ip" ] || [ -z "$master_port" ]; then
        log "Failed to parse master info: $master_info"
        return 1
    fi

    # Check if master server already exists
    server_exists=$(echo "show servers state $HAPROXY_BACKEND" | socat stdio $HAPROXY_SOCKET 2>/dev/null | grep -w "master" | wc -l)

    if [ "$server_exists" -gt 0 ]; then
        log "Updating existing master server to: $master_ip:$master_port"
        echo "set server $HAPROXY_BACKEND/master addr $master_ip port $master_port" | socat stdio $HAPROXY_SOCKET
        if [ $? -eq 0 ]; then
            log "Successfully updated master server"
        else
            log "Failed to update master server"
        fi
    else
        log "Adding new master server: $master_ip:$master_port"
        echo "add server $HAPROXY_BACKEND/master $master_ip:$master_port check" | socat stdio $HAPROXY_SOCKET
        if [ $? -eq 0 ]; then
            log "Successfully added master server"
        else
            log "Failed to add master server"
        fi
    fi
}

update_haproxy_topology() {
    log "Updating HAProxy topology from Sentinels"

    # Get current master from sentinels
    master_info=$(get_master_from_sentinel)
    if [ $? -ne 0 ] || [ -z "$master_info" ]; then
        log "Failed to get master info from any sentinel"
        return 1
    fi

    log "Master info: $master_info"

    # Update master server (add or update existing)
    update_master_in_haproxy "$master_info"

    # Show current server status
    log "Current HAProxy server status:"
    echo "show stat" | socat stdio $HAPROXY_SOCKET | grep "$HAPROXY_BACKEND" | head -10
}

main() {
    log "Starting Redis Sentinel monitor for HAProxy"
    log "Monitoring sentinels: $SENTINEL_HOSTS"
    log "Check interval: ${CHECK_INTERVAL}s"

    # Initial setup
    sleep 5  # Wait for HAProxy to be ready
    update_haproxy_topology

    # Store initial master state
    CURRENT_MASTER=$(get_master_from_sentinel)

    # Monitor for changes
    while true; do
        # Check if we need to update topology
        new_master=$(get_master_from_sentinel)

        if [ $? -eq 0 ] && [ ! -z "$new_master" ]; then
            # Compare with previous state
            if [ "$new_master" != "$CURRENT_MASTER" ]; then
                log "Master change detected!"
                log "Previous: $CURRENT_MASTER"
                log "New: $new_master"
                update_haproxy_topology
                CURRENT_MASTER="$new_master"
            else
                log "No master change detected - skipping HAProxy update"
            fi
        else
            log "Failed to get current master info - keeping existing configuration"
        fi

        sleep $CHECK_INTERVAL
    done
}

# Handle signals gracefully
trap 'log "Shutting down sentinel monitor"; exit 0' SIGTERM SIGINT

main