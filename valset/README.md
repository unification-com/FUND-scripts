# `valset` Cross reference script

Very simple application to cross reference `valset` data from LCD (Cosmos SDK REST) 
and RPC (Tendermint)

## Prerequisites

Requires NodeJS >= v12.16.2

## Using

run `npm install` to install dependencies.

```bash 
node index.js --rpc=[RCP_URL] --lcd=[LCD_URL] --height=[BLOCK_HEIGHT]
```

Example:

```bash 
node index.js --rpc=https://rpc1.unification.io:26657 --lcd=https://rest.unification.io --height=1350573
```

Application expects 3 argument flags:

- `--rpc`: URL for RPC node, e.g. https://rpc1.unification.io:26657.
- `--lcd`: URL for REST interface, e.g. https://rest.unification.io.
- `--height`: height at which to run cross-reference.

Resultset output to console, e.g.

```json 
[
    {
        name: 'SomeValidator',
        operatorAddress: 'undvaloper24eg...',
        consensusPubkey: 'undvalconspubfb64...',
        jailed: false,
        status: 2,
        delegatorShares: '123456789.000000000000000000',
        tokens: '123456789',
        tendermintPubkey: '2FBptRh6hD6f/3PH.....=',
        inTendermintValset: true,
        tendermintAddress: '5A362DA2F522691BB.....',
        tendermintVotingPower: '123456789'
      }
]
```

if a match is found in both RCP and LCD results, the `inTendermintValset`, `tendermintAddress`
and `tendermintVotingPower` fields are populated.
