#!/bin/bash

SENTINEL_HOSTS="sentinel-one:26379 sentinel-two:26379 sentinel-three:26379"
MASTER_NAME="redis-main"
HAPROXY_SOCKET="/var/run/haproxy.sock"
CHECK_INTERVAL=30

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_master_from_sentinel() {
    for sentinel in $SENTINEL_HOSTS; do
        host=${sentinel%:*}
        port=${sentinel#*:}
        
        log "Querying sentinel $sentinel for master info"
        
        # Query sentinel for current master
        master_info=$(redis-cli -h $host -p $port --csv SENTINEL get-master-addr-by-name $MASTER_NAME 2>/dev/null)
        
        if [ $? -eq 0 ] && [ ! -z "$master_info" ]; then
            # Parse CSV output: "ip","port"
            master_ip=$(echo $master_info | cut -d',' -f1 | tr -d '"')
            master_port=$(echo $master_info | cut -d',' -f2 | tr -d '"')
            
            if [ ! -z "$master_ip" ] && [ ! -z "$master_port" ]; then
                echo "$master_ip:$master_port"
                return 0
            fi
        fi
    done
    return 1
}

update_haproxy_server() {
    local server_name=$1
    local new_addr=$2
    local new_port=$3
    local action=$4  # enable or disable
    
    log "Updating HAProxy: $action server $server_name to $new_addr:$new_port"
    
    # Use socat to send commands to HAProxy admin socket as shown in context
    if [ "$action" = "enable" ]; then
        echo "set server redis-proxy/$server_name addr $new_addr port $new_port" | socat stdio $HAPROXY_SOCKET
        echo "enable server redis-proxy/$server_name" | socat stdio $HAPROXY_SOCKET
    else
        echo "disable server redis-proxy/$server_name" | socat stdio $HAPROXY_SOCKET
    fi
}

get_current_haproxy_master() {
    # Get server stats to see which server is currently enabled
    echo "show stat" | socat stdio $HAPROXY_SOCKET | grep "redis-proxy" | grep -v "BACKEND\|FRONTEND"
}

main() {
    log "Starting Redis Sentinel monitor for HAProxy"
    
    while true; do
        current_master=$(get_master_from_sentinel)
        
        if [ $? -eq 0 ] && [ ! -z "$current_master" ]; then
            master_ip=${current_master%:*}
            master_port=${current_master#*:}
            
            log "Current master from Sentinel: $master_ip:$master_port"
            
            # Determine which server should be active
            if [ "$master_ip" = "redis-main" ] || [[ "$current_master" == *"redis-main"* ]]; then
                # redis-main is master
                update_haproxy_server "redis-main" "$master_ip" "$master_port" "enable"
                update_haproxy_server "redis-secondary" "redis-secondary" "6379" "disable"
            else
                # redis-secondary is master
                update_haproxy_server "redis-secondary" "$master_ip" "$master_port" "enable"
                update_haproxy_server "redis-main" "redis-main" "6379" "disable"
            fi
        else
            log "Failed to get master info from any sentinel"
        fi
        
        sleep $CHECK_INTERVAL
    done
}

# Handle signals gracefully
trap 'log "Shutting down sentinel monitor"; exit 0' SIGTERM SIGINT

main