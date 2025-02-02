#!/bin/bash

# This script waits  for the validator to be created before starting the orchestrator

# check if environment variables are set
if [[ -z "${MONIKER}" || -z "${PRIVATE_KEY}" ]] || \
   [[ -z "${TENDERMINT_RPC}" || -z "${CELESTIA_GRPC}" ]] || \
   [[ -z "${P2P_LISTEN}" ]]
then
  echo "Environment not setup correctly. Please set:"
  echo "MONIKER, PRIVATE_KEY, TENDERMINT_RPC, CELESTIA_GRPC, P2P_LISTEN variables"
  exit 1
fi

# install needed dependencies
apk add curl

# wait for the validator to be created before starting the orchestrator
VAL_ADDRESS=$(celestia-appd keys show ${MONIKER} --keyring-backend test --bech=val --home /opt -a)
while true
do
  # verify that the node is listening on gRPC
  nc -z -w5 $(echo $CELESTIA_GRPC | cut -d : -f 1) $(echo $CELESTIA_GRPC | cut -d : -f 2)
  result=$?
  if [ "${result}" != "0" ]; then
    echo "Waiting for node gRPC to be available ..."
    sleep 1s
    continue
  fi

  # verify if RPC is running and the validator was created
  output=$(celestia-appd query staking validator ${VAL_ADDRESS} --node $TENDERMINT_RPC 2>/dev/null)
  if [[ -n "${output}" ]] ; then
    break
  fi
  echo "Waiting for validator to be created..."
  sleep 3s
done

# initialize orchestrator
/bin/qgb orch init

# add keys to keystore
/bin/qgb orch keys evm import ecdsa "${PRIVATE_KEY}" --evm-passphrase 123

# start orchestrator
if [[ -z "${P2P_BOOTSTRAPPERS}" ]]
then
  # import the p2p key to use
  /bin/qgb orchestrator keys p2p import key "${P2P_IDENTITY}"

  /bin/qgb orchestrator start \
    -d="${EVM_ADDRESS}" \
    -t="${TENDERMINT_RPC}" \
    -c="${CELESTIA_GRPC}" \
    -p=key \
    -q="${P2P_LISTEN}" \
    --evm-passphrase=123
else
  # to give time for the bootstrappers to be up
  sleep 5s

  /bin/qgb orchestrator start \
    -d="${EVM_ADDRESS}" \
    -t="${TENDERMINT_RPC}" \
    -c="${CELESTIA_GRPC}" \
    -b="${P2P_BOOTSTRAPPERS}" \
    -q="${P2P_LISTEN}"\
    --evm-passphrase=123
fi
