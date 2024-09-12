const argv = require('minimist')(process.argv.slice(2));

let selectedChain = argv.chain || 'local';

const settings = {
    "local": {
        "phrase": "coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin",
    },
    "mainnet": {
        "phrase": "", // set it as cli parameter
    }, 
    "testnet": {
        "phrase": "coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin coin",
    },
};



if (selectedChain == 'mainnet' && settings[selectedChain].phrase) {
    throw new Error('Please do not set phrase for mainnet in the config file! Run it as cli option --phrase="word word ... word"');
}

settings[selectedChain].chain = selectedChain;
if (argv.phrase) {
    settings[selectedChain].phrase = argv.phrase;
}

module.exports = settings[selectedChain];
