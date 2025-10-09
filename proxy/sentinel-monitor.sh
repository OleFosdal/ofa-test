#!/bin/bash

SENTINEL_HOSTS="sentinel-one:26379 sentinel-two:26379 sentinel-three:26379"
HAPROXY_SOCKET="/var/run/haproxy.sock"
CHECK_INTERVAL=30
MASTER_NAME="mymaster"
HAPROXY_BACKEND="redis-proxy"
HAPROXY_SERVER_NAME="redis-master"
CURRENT_MASTER=""

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
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

update_haproxy_topology() {
    log "Updating HAProxy topology from Sentinels"
    log "Master info: $CURRENT_MASTER"

    if [ -z "$CURRENT_MASTER" ]; then
        log "No master info available"
        return 1
    fi

    # Parse master info in format "IP:PORT"
    master_ip="${CURRENT_MASTER%:*}"
    master_port="${CURRENT_MASTER#*:}"

    if [ -z "$master_ip" ] || [ -z "$master_port" ]; then
        log "Failed to parse master info: $CURRENT_MASTER"
        return 1
    fi

    # Check if master server already exists
    server_exists=$(echo "show servers state $HAPROXY_BACKEND" | socat stdio $HAPROXY_SOCKET 2>/dev/null | grep -w "$HAPROXY_SERVER_NAME" | wc -l)

    if [ "$server_exists" -gt 0 ]; then
        log "Removing existing master server before updating"
        echo "del server $HAPROXY_BACKEND/$HAPROXY_SERVER_NAME" | socat stdio $HAPROXY_SOCKET 2>/dev/null
        sleep 1
    fi

    log "Adding master server: $master_ip:$master_port"
    echo "add server $HAPROXY_BACKEND/$HAPROXY_SERVER_NAME $master_ip:$master_port check" | socat stdio $HAPROXY_SOCKET
    if [ $? -eq 0 ]; then
        log "Successfully added master server"
    else
        log "Failed to add master server"
    fi

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

    # Get initial master and configure HAProxy
    CURRENT_MASTER=$(get_master_from_sentinel)
    if [ $? -eq 0 ] && [ ! -z "$CURRENT_MASTER" ]; then
        update_haproxy_topology
    else
        log "Failed to get initial master info - will retry in next cycle"
    fi

    # Monitor for changes
    while true; do
        sleep $CHECK_INTERVAL

        # Check if we need to update topology
        new_master=$(get_master_from_sentinel)

        if [ $? -eq 0 ] && [ ! -z "$new_master" ]; then
            # Compare with previous state
            if [ "$new_master" != "$CURRENT_MASTER" ]; then
                log "Master change detected!"
                log "Previous: $CURRENT_MASTER"
                log "New: $new_master"
                CURRENT_MASTER="$new_master"
                update_haproxy_topology
            else
                log "No master change detected - skipping HAProxy update"
            fi
        else
            log "Failed to get current master info - keeping existing configuration"
        fi
    done
}

# Handle signals gracefully
trap 'log "Shutting down sentinel monitor"; exit 0' SIGTERM SIGINT

main