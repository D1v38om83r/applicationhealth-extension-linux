#!/usr/bin/env bats

load test_helper

setup(){
    build_docker_image
}

teardown(){
    rm -rf "$certs_dir"
}


@test "handler command: enable - custom metrics - not sending custom metrics is not seen in status file" {
    mk_container sh -c "webserver -args=2h,2h & fake-waagent install && fake-waagent enable && wait-for-enable webserverexit"
    push_settings '
    {
        "protocol": "http",
        "requestPath": "health",
        "port": 8080,
        "numberOfProbes": 2,
        "intervalInSeconds": 5,
        "gracePeriod": 600
    }' ''
    run start_container

    echo "$output"
    enableLog="$(echo "$output" | grep 'operation=enable' | grep state)"
    
    expectedTimeDifferences=(0 5)
    verify_state_change_timestamps "$enableLog" "${expectedTimeDifferences[@]}"

    expectedStateLogs=(
        "Health state changed to healthy"
        "Committed health state is initializing"
        "Committed health state is healthy"
    )
    verify_states "$enableLog" "${expectedStateLogs[@]}"

    status_file="$(container_read_file /var/lib/waagent/Extension/status/0.status)"
    echo "status_file=$status_file"; [[ "$status_file" = *'Application health found to be healthy'* ]]
    echo "status_file=$status_file"; [[ "$status_file" != *'CustomMetrics'* ]]
}

@test "handler command: enable - custom metrics - sending null custom metrics is omitted and not seen in status file " {
    mk_container sh -c "webserver -args=2h-null,2h-null,2u-null,2u-null & fake-waagent install && fake-waagent enable && wait-for-enable webserverexit"
    push_settings '
    {
        "protocol": "http",
        "requestPath": "health",
        "port": 8080,
        "numberOfProbes": 2,
        "intervalInSeconds": 5,
        "gracePeriod": 600
    }' ''
    run start_container

    echo "$output"
    enableLog="$(echo "$output" | grep 'operation=enable' | grep state)"
    
    expectedTimeDifferences=(0 5 5 5)
    verify_state_change_timestamps "$enableLog" "${expectedTimeDifferences[@]}"

    expectedStateLogs=(
        "Health state changed to healthy"
        "Committed health state is initializing"
        "Committed health state is healthy"
        "Health state changed to unhealthy"
        "Committed health state is unhealthy"
    )
    verify_states "$enableLog" "${expectedStateLogs[@]}"

    status_file="$(container_read_file /var/lib/waagent/Extension/status/0.status)"
    echo "status_file=$status_file"; [[ "$status_file" = *'Application health found to be unhealthy'* ]]
    [[ "$status_file" != *'CustomMetrics'* ]]
}

@test "handler command: enable - custom metrics - sending empty string custom metrics is omitted and not seen in status file " {
    mk_container sh -c "webserver -args=2h-empty,2h-empty & fake-waagent install && fake-waagent enable && wait-for-enable webserverexit"
    push_settings '
    {
        "protocol": "http",
        "requestPath": "health",
        "port": 8080,
        "numberOfProbes": 2,
        "intervalInSeconds": 5,
        "gracePeriod": 600
    }' ''
    run start_container

    echo "$output"
    enableLog="$(echo "$output" | grep 'operation=enable' | grep state)"
    
    expectedTimeDifferences=(0 5)
    verify_state_change_timestamps "$enableLog" "${expectedTimeDifferences[@]}"

    expectedStateLogs=(
        "Health state changed to healthy"
        "Committed health state is initializing"
        "Committed health state is healthy"
    )
    verify_states "$enableLog" "${expectedStateLogs[@]}"

    status_file="$(container_read_file /var/lib/waagent/Extension/status/0.status)"
    echo "status_file=$status_file"; [[ "$status_file" = *'Application health found to be healthy'* ]]
    [[ "$status_file" != *'CustomMetrics'* ]]
}

@test "handler command: enable - custom metrics - sending empty json object in custom metrics appears in status file with error status" {
    mk_container sh -c "webserver -args=2h-emptyobj,2h-emptyobj & fake-waagent install && fake-waagent enable && wait-for-enable webserverexit"
    push_settings '
    {
        "protocol": "http",
        "requestPath": "health",
        "port": 8080,
        "numberOfProbes": 2,
        "intervalInSeconds": 5,
        "gracePeriod": 600
    }' ''
    run start_container

    echo "$output"
    enableLog="$(echo "$output" | grep 'operation=enable' | grep state)"
    
    expectedTimeDifferences=(0 5)
    verify_state_change_timestamps "$enableLog" "${expectedTimeDifferences[@]}"

    expectedStateLogs=(
        "Health state changed to healthy"
        "Committed health state is initializing"
        "Committed health state is healthy"
    )
    verify_states "$enableLog" "${expectedStateLogs[@]}"

    status_file="$(container_read_file /var/lib/waagent/Extension/status/0.status)"
    echo "status_file=$status_file"; [[ "$status_file" = *'Application health found to be healthy'* ]]
    
    echo "$status_file" | egrep -z '"name": "ApplicationHealthState",\s+"status": "success",\s+"formattedMessage": {\s+"lang": "en",\s+"message": "Healthy"'
    echo "$status_file" | egrep -z '"name": "CustomMetrics",\s+"status": "error",\s+"formattedMessage": {\s+"lang": "en",\s+"message": "\{\}"'
}

@test "handler command: enable - custom metrics - sending invalid formatted custom metrics appears in status file with error status" {
    mk_container sh -c "webserver -args=2h-invalid,2h-invalid & fake-waagent install && fake-waagent enable && wait-for-enable webserverexit"
    push_settings '
    {
        "protocol": "http",
        "requestPath": "health",
        "port": 8080,
        "numberOfProbes": 2,
        "intervalInSeconds": 5,
        "gracePeriod": 600
    }' ''
    run start_container

    echo "$output"
    enableLog="$(echo "$output" | grep 'operation=enable' | grep state)"
    
    expectedTimeDifferences=(0 5)
    verify_state_change_timestamps "$enableLog" "${expectedTimeDifferences[@]}"

    expectedStateLogs=(
        "Health state changed to healthy"
        "Committed health state is initializing"
        "Committed health state is healthy"
    )
    verify_states "$enableLog" "${expectedStateLogs[@]}"

    status_file="$(container_read_file /var/lib/waagent/Extension/status/0.status)"
    echo "status_file=$status_file"; [[ "$status_file" = *'Application health found to be healthy'* ]]

    echo "$status_file" | egrep -z '"name": "ApplicationHealthState",\s+"status": "success",\s+"formattedMessage": {\s+"lang": "en",\s+"message": "Healthy"'
    echo "$status_file" | egrep -z '"name": "CustomMetrics",\s+"status": "error",\s+"formattedMessage": {\s+"lang": "en",\s+"message": "\[ \\"hello\\", \\"world\\" ]"'
}

@test "handler command: enable - custom metrics - sending valid custom metrics is seen in status file" {
    mk_container sh -c "webserver -args=2h-valid,2h-valid & fake-waagent install && fake-waagent enable && wait-for-enable webserverexit"
    push_settings '
    {
        "protocol": "http",
        "requestPath": "health",
        "port": 8080,
        "numberOfProbes": 2,
        "intervalInSeconds": 5,
        "gracePeriod": 600
    }' ''
    run start_container

    echo "$output"
    enableLog="$(echo "$output" | grep 'operation=enable' | grep state)"
    
    expectedTimeDifferences=(0 5)
    verify_state_change_timestamps "$enableLog" "${expectedTimeDifferences[@]}"

    expectedStateLogs=(
        "Health state changed to healthy"
        "Committed health state is initializing"
        "Committed health state is healthy"
    )
    verify_states "$enableLog" "${expectedStateLogs[@]}"

    status_file="$(container_read_file /var/lib/waagent/Extension/status/0.status)"
    echo "status_file=$status_file"; [[ "$status_file" = *'Application health found to be healthy'* ]]

    echo "$status_file" | egrep -z '"name": "CustomMetrics",\s+"status": "success",\s+"formattedMessage": {\s+"lang": "en",\s+"message": "{\\"rollingUpgradePolicy\\": { \\"phase\\": 2, \\"doNotUpgrade\\": true, \\"dummy\\": \\"yes\\" } }"'
}

@test "handler command: enable - custom metrics - sending valid custom metrics is seen in status file even if health is unknown" {
    mk_container sh -c "webserver -args=2m-valid,2m-valid & fake-waagent install && fake-waagent enable && wait-for-enable webserverexit"
    push_settings '
    {
        "protocol": "http",
        "requestPath": "health",
        "port": 8080,
        "numberOfProbes": 2,
        "intervalInSeconds": 5,
        "gracePeriod": 600
    }' ''
    run start_container

    echo "$output"
    enableLog="$(echo "$output" | grep 'operation=enable' | grep state)"
    
    expectedTimeDifferences=(0)
    verify_state_change_timestamps "$enableLog" "${expectedTimeDifferences[@]}"

    expectedStateLogs=(
        "Health state changed to unknown"
        "Committed health state is initializing"
    )
    verify_states "$enableLog" "${expectedStateLogs[@]}"

    status_file="$(container_read_file /var/lib/waagent/Extension/status/0.status)"
    echo "status_file=$status_file"; [[ "$status_file" = *'Application health found to be initializing'* ]]

    echo "$status_file" | egrep -z '"name": "CustomMetrics",\s+"status": "success",\s+"formattedMessage": {\s+"lang": "en",\s+"message": "{\\"rollingUpgradePolicy\\": { \\"phase\\": 2, \\"doNotUpgrade\\": true, \\"dummy\\": \\"yes\\" } }"'
}