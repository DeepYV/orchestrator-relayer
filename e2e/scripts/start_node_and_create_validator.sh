#!/bin/bash

# This script starts a Celestia-app, creates a validator with the provided parameters, then
# keeps running it validating blocks.

# check if environment variables are set
if [[ -z "${CELESTIA_HOME}" || -z "${MONIKER}" || -z "${EVM_ADDRESS}" || -z "${AMOUNT}" ]]
then
  echo "Environment not setup correctly. Please set: CELESTIA_HOME, MONIKER, EVM_ADDRESS, AMOUNT variables"
  exit 1
fi

# create necessary structure if doens't exist
if [[ ! -f ${CELESTIA_HOME}/data/priv_validator_state.json ]]
then
    mkdir /opt/data
    cat <<EOF > ${CELESTIA_HOME}/data/priv_validator_state.json
{
  "height": "0",
  "round": 0,
  "step": 0
}
EOF
fi

# install needed dependencies
apk add curl

{
  # wait for the node to get up and running
  while true
  do
    status_code=$(curl --write-out '%{http_code}' --silent --output /dev/null localhost:26657/status)
    if [[ "${status_code}" -eq 200 ]] ; then
      break
    fi
    echo "Waiting for node to be up..."
    sleep 2s
  done

  VAL_ADDRESS=$(celestia-appd keys show ${MONIKER} --keyring-backend test --bech=val --home /opt -a)
  # keep retrying to create a validator
  while true
  do
    # create validator
    celestia-appd tx staking create-validator \
      --amount=${AMOUNT} \
      --pubkey="$(celestia-appd tendermint show-validator --home ${CELESTIA_HOME})" \
      --moniker=${MONIKER} \
      --chain-id="qgb-e2e" \
      --commission-rate=0.1 \
      --commission-max-rate=0.2 \
      --commission-max-change-rate=0.01 \
      --min-self-delegation=1000000 \
      --from=${MONIKER} \
      --keyring-backend=test \
      --evm-address=${EVM_ADDRESS} \
      --home=${CELESTIA_HOME} \
      --broadcast-mode=block \
      --fees="300utia" \
      --yes
    output=$(celestia-appd query staking validator ${VAL_ADDRESS} 2>/dev/null)
    if [[ -n "${output}" ]] ; then
      break
    fi
    echo "trying to create validator..."
    sleep 1s
  done

} &

# start node
celestia-appd start \
--home=${CELESTIA_HOME} \
--moniker=${MONIKER} \
--p2p.persistent_peers=7cd70d8b4fc318f18e2766e0d46ccd1489b0bf65@core0:26656 \
--rpc.laddr=tcp://0.0.0.0:26657
