curl -X POST https://api.dropboxapi.com/2/files/search \
    --header "Authorization: Bearer q6LB6eJh-UIAAAAAAAEBdCOk5Q3IekgW3CorFjVLIxbg5iinvQ6hfhCJCxo20yxb" \
    --header "Content-Type: application/json" \
    --data "{\"path\": \"\",\"query\": \"device_change.txt\",\"start\": 0,\"max_results\": 100,\"mode\": \"filename\"}"
