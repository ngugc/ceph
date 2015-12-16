#!/bin/bash

. "`dirname $0`/test-rgw-common.sh"

set -e

function get_metadata_sync_status {
  id=$1

  meta_sync_status_json=`$(rgw_admin $id) metadata sync status`

  global_sync_status=$(json_extract sync_status.info.status $meta_sync_status_json)
  num_shards=$(json_extract sync_status.info.num_shards $meta_sync_status_json)

  echo "sync_status: $global_sync_status"

  sync_markers=$(json_extract sync_status.markers $meta_sync_status_json)

  # num_shards=$(python_array_len $sync_markers)

  # echo $num_shards

  sync_states=$(project_python_array_field val.state $sync_markers)
  eval secondary_status=$(project_python_array_field val.marker $sync_markers)
}

function get_metadata_log_status {
  master_id=$1

  master_mdlog_status_json=`$(rgw_admin $master_id) mdlog status`
  master_meta_status=$(json_extract "" $master_mdlog_status_json)

  eval master_status=$(project_python_array_field marker $master_meta_status)
}

function wait_for_meta_sync {
  master_id=$1
  id=$2

  get_metadata_log_status $master_id
  echo "master_status=${master_status[*]}"

  while true; do
    get_metadata_sync_status $id

    echo "secondary_status=${secondary_status[*]}"

    fail=0
    for i in `seq 0 $((num_shards-1))`; do
      if [ "${master_status[$i]}" \> "${secondary_status[$i]}" ]; then
        echo "shard $i not done syncing (${master_status[$i]} > ${secondary_status[$i]})"
        fail=1
        break
      fi
    done

    [ $fail -eq 0 ] && echo "Success" && return || echo "Sync not complete"

    sleep 5
  done
}
