var argv = require('minimist')(process.argv.slice(2))
const bech32 = require("bech32")
const Axios = require("axios")
const _ = require('lodash')

if(!argv['height'] || !argv['rpc'] || !argv['lcd']) {
    if(!argv['height']) {
        console.log("no height passed.")
    }
    if(!argv['rpc']) {
        console.log("no height passed.")
    }
    if(!argv['lcd']) {
        console.log("no height passed.")
    }
    console.log("Example:")
    console.log("    node index.js --rpc=https://rpc1.unification.io:26657 --lcd=https://rest.unification.io --height=1350573")
    return
}

const RPC = argv['rpc']
const LCD = argv['lcd']
const height = argv['height']

const bech32ToPubkey = (pubkey) => {
    // '1624DE6420' is ed25519 pubkey prefix
    let pubkeyAminoPrefix = Buffer.from('1624DE6420', 'hex')
    let buffer = Buffer.from(bech32.fromWords(bech32.decode(pubkey).words))

    return buffer.slice(pubkeyAminoPrefix.length).toString('base64')
}

const getDelegatorAddress = (operatorAddr) => {
    const address = bech32.decode(operatorAddr)
    return bech32.encode("und", address.words)
}

const fetchData = (url) => {
    return new Promise((resolve, reject) => {
        console.log("fetch", url)
        Axios.get(url)
        .then(response => {
            resolve(response.data)
        })
        .catch(error => {
        console.log("error fetching", url, error.toString())
        reject(error.toString())
    })
})
}

const processData = (rpcValset, lcdValset, blockData) => {
    const valset = []
    const blockSigs = blockData.result.block.last_commit.signatures
    try {
        for(let i = 0; i < lcdValset.result.length; i += 1) {
            let valData = {}
            let val = lcdValset.result[i]
            valData.blockHeight = blockData.result.block.header.height
            valData.name = val.description.moniker
            valData.operatorAddress = val.operator_address
            valData.selfDelegateAddress = getDelegatorAddress(val.operator_address)
            valData.consensusPubkey = val.consensus_pubkey
            valData.jailed = val.jailed
            valData.status = val.status
            valData.delegatorShares = val.delegator_shares
            valData.tokens = val.tokens
            let tendermintPubkey = bech32ToPubkey(val.consensus_pubkey)
            valData.tendermintPubkey = tendermintPubkey
            valData.inTendermintValset = false
            valData.tendermintAddress = ""
            valData.tendermintVotingPower = 0

            let idx = _.findIndex(rpcValset.result.validators, function(o) { return o.pub_key.value == tendermintPubkey; });

            if(idx > -1) {
                const tendermintAddress = rpcValset.result.validators[idx].address
                valData.inTendermintValset = true
                valData.tendermintAddress = tendermintAddress
                valData.tendermintVotingPower = rpcValset.result.validators[idx].voting_power

                let sigIdx = _.findIndex(blockSigs, function(o) { return o.validator_address == tendermintAddress; });
                if(sigIdx > -1) {
                    valData.block_sig = blockSigs[sigIdx]
                } else {
                    valData.block_sig = false
                }
            }

            valset.push(valData)
        }
    } catch(e) {
        console.log(e.toString())
    }
    return valset
}

const run = async() => {

    console.log("at height:", height)

    Promise.all([
        fetchData(RPC + '/validators?height=' + height + '&per_page=100'),
        fetchData(LCD + '/staking/validators?height=' + height),
        fetchData(RPC + '/block?height=' + height)
    ]).then((values) => {
        let valset = processData(values[0], values[1], values[2])
        console.log("valset cross reference:", valset)
    }).catch(console.error)
}

run()
