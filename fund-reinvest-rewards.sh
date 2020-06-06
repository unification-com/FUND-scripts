#!/bin/bash -e
# Credit to https://validator.network for the original cosmoshub-reinvesting script. This script was modified to fit the nomenclature used with the Unification undcli tool. 

# This script comes without warranties of any kind. Use at your own risk.

# The purpose of this script is to withdraw rewards (if any) and delegate them to an appointed validator. This way you can reinvest (compound) rewards.

# Requirements: undcli, curl and jq must be in the path.


##############################################################################################################################################################

#Amended code for the Unification $FUND by FUNDAustralia & FUNDThailand

##############################################################################################################################################################
# User settings.
##############################################################################################################################################################

KEY=""                                         # This is the key you wish to use for signing transactions, listed in first column of "undcli keys list".
PASSPHRASE=""                                  # Only populate if you want to run the script periodically. This is UNSAFE and should only be done if you know what you are doing.
DENOM="nund"                                   # Coin denominator is uatom ("microoatom"). 1 FUND = 1000000 nund.
MINIMUM_DELEGATION_AMOUNT="5000000000"         # Only perform delegations above this amount of nund. Default: 5 FUND
RESERVATION_AMOUNT="5000000000"                # Keep this amount of nund in account. Default: 5 FUND
VALIDATOR="undvaloper1csy76g5uhq0h68g9e34uyf88eac24jy93r7de3"        # Default is FUNDAustralia.

##############################################################################################################################################################


##############################################################################################################################################################
# Sensible defaults.
##############################################################################################################################################################

CHAIN_ID="FUND-Mainchain-MainNet-v1"       # Current chain id. Empty means auto-detect.
NODE="https://rpc1.unification.io:26657"  # Either run a local full node or choose one you trust.
GAS_PRICES="0.25nund"                         # Gas prices to pay for transaction.
GAS_ADJUSTMENT="1.5"                           # Adjustment for estimated gas
GAS_AUTO="auto"
GAS_FLAGS="--gas ${GAS_AUTO} --gas-prices ${GAS_PRICES} --gas-adjustment ${GAS_ADJUSTMENT}"

##############################################################################################################################################################
# Ask for passphrase to sign transactions.
if [ -z "${PASSPHRASE}" ]
then
   read -s -p "Enter passphrase required to sign for \"${KEY}\": " PASSPHRASE
    echo ""
fi

# Auto-detect chain-id if not specified.
if [ -z "${CHAIN_ID}" ]
then
  NODE_STATUS=$(curl -s --max-time 5 ${NODE}/status)
  CHAIN_ID=$(echo ${NODE_STATUS} | jq -r ".result.node_info.network")
fi

# Use first command line argument in case KEY is not defined.
if [ -z "${KEY}" ] && [ ! -z "${1}" ]
then
  KEY=${1}
fi

# Get information about key
KEY_STATUS=$(echo ${PASSPHRASE} | undcli keys show ${KEY} --output json)
KEY_TYPE=$(echo ${KEY_STATUS} | jq -r "type")
if [ "${KEY_TYPE}" == "ledger" ]
then
    SIGNING_FLAGS="--ledger"
fi

# Get current account balance.
ACCOUNT_ADDRESS=$(echo ${KEY_STATUS} | jq -r ".address")
ACCOUNT_STATUS=$(undcli query auth account ${ACCOUNT_ADDRESS} --output json)
ACCOUNT_SEQUENCE=$(echo ${ACCOUNT_STATUS} | jq -r ".value.sequence")
ACCOUNT_BALANCE=$(echo ${ACCOUNT_STATUS} | jq -r ".value.coins[] | select(.denom == \"${DENOM}\") | .amount" || true)
if [ -z "${ACCOUNT_BALANCE}" ]
then
    # Empty response means zero balance.
    ACCOUNT_BALANCE=0
fi

# Get available rewards.
REWARDS_STATUS=$(undcli query distribution rewards ${ACCOUNT_ADDRESS} --output json)
if [ "${REWARDS_STATUS}" == "null" ]
then
    # Empty response means zero balance.
    REWARDS_BALANCE="0"
else
    REWARDS_BALANCE=$(echo ${REWARDS_STATUS} | jq -r ".total[] | select(.denom == \"${DENOM}\") | .amount" || true)
    if [ -z "${REWARDS_BALANCE}" ] || [ "${REWARDS_BALANCE}" == "null" ]
    then
        # Empty response means zero balance.
        REWARDS_BALANCE="0"
    else
        # Remove decimals.
        REWARDS_BALANCE=${REWARDS_BALANCE%.*}
    fi
fi

# Get available commission.
VALIDATOR_ADDRESS=$(echo ${PASSPHRASE} | undcli keys show ${KEY} --bech val --address)
COMMISSION_STATUS=$(undcli query distribution commission ${VALIDATOR_ADDRESS} --output json)
if [ "${COMMISSION_STATUS}" == "null" ]
then
    # Empty response means zero balance.
    COMMISSION_BALANCE="0"
else
    COMMISSION_BALANCE=$(echo ${COMMISSION_STATUS} | jq -r ".[] | select(.denom == \"${DENOM}\") | .amount" || true)
    if [ -z "${COMMISSION_BALANCE}" ]
    then
        # Empty response means zero balance.
        COMMISSION_BALANCE="0"
    else
        # Remove decimals.
        COMMISSION_BALANCE=${COMMISSION_BALANCE%.*}
    fi
fi

# Calculate net balance and amount to delegate.
NET_BALANCE=$((${ACCOUNT_BALANCE} + ${REWARDS_BALANCE} + ${COMMISSION_BALANCE}))
if [ "${NET_BALANCE}" -gt $((${MINIMUM_DELEGATION_AMOUNT} + ${RESERVATION_AMOUNT})) ]
then
    DELEGATION_AMOUNT=$((${NET_BALANCE} - ${RESERVATION_AMOUNT}))
else
    DELEGATION_AMOUNT="0"
fi



# Convert nund to FUND
ACCOUNT_BALANCE_FUND=$(undcli convert ${ACCOUNT_BALANCE} nund fund)
REWARDS_BALANCE_FUND=$(undcli convert ${REWARDS_BALANCE} nund fund)
COMMISSION_BALANCE_FUND=$(undcli convert ${COMMISSION_BALANCE} nund fund)
NET_BALANCE_FUND=$(undcli convert ${NET_BALANCE} nund fund)
RESERVATION_AMOUNT_FUND=$(undcli convert ${RESERVATION_AMOUNT} nund fund)

# Display what we know so far.
echo "======================================================"
echo "Account: ${KEY} (${KEY_TYPE})"
echo "Address: ${ACCOUNT_ADDRESS}"
echo "======================================================"
echo "Account balance:      ${ACCOUNT_BALANCE_FUND}"
echo "Available rewards:    ${REWARDS_BALANCE_FUND}"
echo "Available commission: ${COMMISSION_BALANCE_FUND}"
echo "Net balance:          ${NET_BALANCE_FUND}"
echo "Reservation:          ${RESERVATION_AMOUNT_FUND}"
echo

if [ "${DELEGATION_AMOUNT}" -eq 0 ]
then
    echo "Nothing to delegate."
    exit 0
fi

# Convert nund to FUND
DELEGATION_AMOUNT_FUND=$(undcli convert ${DELEGATION_AMOUNT} nund fund)

# Display delegation information.
VALIDATOR_STATUS=$(undcli query staking validator ${VALIDATOR} --output json)
VALIDATOR_MONIKER=$(echo ${VALIDATOR_STATUS} | jq -r ".description.moniker")
VALIDATOR_DETAILS=$(echo ${VALIDATOR_STATUS} | jq -r ".description.details")
echo "You are about to delegate ${DELEGATION_AMOUNT_FUND} to ${VALIDATOR}:"
echo "  Moniker: ${VALIDATOR_MONIKER}"
echo "  Details: ${VALIDATOR_DETAILS}"
echo

# Run transactions
MEMO=$'rewards @ FUNDAustralia'
if [ "${REWARDS_BALANCE}" -gt 0 ]
then
    printf "Withdrawing rewards..."
    Yes ${PASSPHRASE} | undcli tx distribution withdraw-all-rewards --yes --from ${KEY} --chain-id ${CHAIN_ID} --node ${NODE} ${GAS_FLAGS} ${SIGNING_FLAGS} --broadcast-mode=block --memo "${MEMO}"
fi

if [ "${COMMISSION_BALANCE}" -gt 0 ]
then
    printf "Withdrawing commission... "
    Yes ${PASSPHRASE} | undcli tx distribution withdraw-rewards ${VALIDATOR_ADDRESS} --commission --yes --from ${KEY} --chain-id ${CHAIN_ID} --node ${NODE} ${GAS_FLAGS} ${SIGNING_FLAGS} --broadcast-mode=block --memo "${MEMO}"
fi

printf "Delegating... "
  Yes ${PASSPHRASE} | undcli tx staking delegate ${VALIDATOR} ${DELEGATION_AMOUNT}${DENOM} --yes --from ${KEY} --chain-id ${CHAIN_ID} --node ${NODE} ${GAS_FLAGS} --broadcast-mode=block --memo "${MEMO}"

echo
echo "Have a FUND day!"
