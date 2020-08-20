#!/bin/bash
#### this script monitors openethereum height and restarts it if too many errors (no height or height not growing)


######### vars
prometheus_port=85455 #### default installation is 9615
prometheus_host="127.0.0.1"
service_name="openethereum"
###metric_height='substrate_block_height' ### openethereum cant export promethers metrics
log_time_zone="UTC"
allowed_fails=9
sleep_after_restart="5m"


############### functions
function log() {
        echo $(TZ=$log_time_zone date "+%Y-%m-%d %H:%M:%S") "${1}"
}

####https://stackoverflow.com/a/3951175
#### check string IS a number
function check_number() {
        _string_to_check=$1
        case $_string_to_check in
                ''|*[!0-9]*) echo "error" ;;
                *) echo "OK" ;;
        esac
}

function restart_daemon() {
        log "systemctl restart $service_name"
        systemctl restart $service_name
}

####function get_peers() {
####    local _peers=$(get_metrics | awk '/^'${metric_peers}'/{print $2}')
####    case $(check_number "$_peers") in
####            "error") echo "error" ;;
####            *) echo $_peers
####    esac
####}

function get_best_block() {
        local _eth_blockNumber_curlout=$(curl --fail --silent --show-error -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://127.0.0.1:8545 2>&1)
        local _lastexit_curl=$?
        if [ $_lastexit_curl -gt 0 ];
        then
                log "error getting eth_blockNumber - curl error: $_eth_blockNumber_curlout"
                echo "error"    ### returns this value to next function
                return          ### exit function
        fi

        local _eth_blockNumber_jqout=$(jq -r .result <<< "$_eth_blockNumber_curlout" 2>&1)
        local _lastexit_jq=$?
        if [ $_lastexit_jq -gt 0 ];
        then
                log "error getting eth_blockNumber - jq error: $_eth_blockNumber_jqout"
                echo "error"    ### returns this value to next function
                return          ### exit function
        fi

        local _eth_blockNumber_dec=""
        printf -v _eth_blockNumber_dec "%d" "$_eth_blockNumber_jqout"


        case $(check_number "$_eth_blockNumber_dec") in
                "error") echo "error" ;;
                *) echo $_eth_blockNumber_dec
        esac
}

function alert_telegram() {
        log "TODO: alert telegram"
        #TODO: alert telegram!
}




############ main
old_block=$(get_best_block)
case $old_block in
        "error")
                log "error after getting block height! exit..."
                exit
        ;;
esac

consecutive_fails=0

log "block=$old_block"

while :; do
        sleep 1m

        if (( consecutive_fails >= allowed_fails )); then
                log "$consecutive_fails consecutive fails! will restart daemon!"
                restart_daemon
                consecutive_fails=0     ### reset fail counter after restart
                log "sleep $sleep_after_restart to let it connect to network..."
                sleep $sleep_after_restart
        fi

        new_block=$(get_best_block)
        case $new_block in
                "error")
                        log "number_error after getting block!"
                        consecutive_fails=$(( consecutive_fails + 1 ))
                        continue        ### do not check if error getting block
                ;;
        esac

        log "block old=$old_block, new=$new_block OK"

        if (( new_block > old_block )); then
                old_block=$new_block
                consecutive_fails=0
        else
                log "oops block not increasing!"
                consecutive_fails=$(( consecutive_fails + 1 ))
                log "consecutive_fails=$consecutive_fails"
        fi
done
