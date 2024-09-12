const { SuiMaster } = require('suidouble');
const config = require('./config.js');
const path = require('path');

const run = async()=>{
    const phrase = config.phrase;
    const chain = config.chain;

    const suiMaster = new SuiMaster({client: chain, phrase: phrase, debug: true});

    try {
        await suiMaster.requestSuiFromFaucet();
    } catch (e) {
        console.error(e);
    }
    await suiMaster.getBalance();

    const package = suiMaster.addPackage({
        path: path.join(__dirname, '../contracts'),
    });

    await package.publish();

    console.log('deployed as', package.id);
};

run();