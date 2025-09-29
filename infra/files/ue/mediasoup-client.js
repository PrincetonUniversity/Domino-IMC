#!/usr/bin/env node

import Puppeteer from 'puppeteer';
import FileSystem, { stat } from 'fs';
import { parse } from 'path';

process.on('SIGINT', async () => {
    console.log(' - received SIGINT, closing browsers, exiting...');
    await browser.close();
    process.exit();
});

if (process.argv.length != 5) {
    console.error('usage: mediasoup-client.js URL DURATION STATS/');
    console.error('       - URL:            MediaSoup URL'); // argv[2]
    console.error('       - VIDEO-FILE.y4m: video file to use for fake video capture'); // argv[3]
    console.error('       - DURATION:       duration of run in seconds'); // argv[4]
    console.error('       - STATS/:         directory to write reports to'); // argv[5]
    process.exit(1);
}

let report_count = 0;

async function collect_webrtc_internals() {
    report_count += 1;
    const stats_html = await stats_page.content();
    await FileSystem.promises.writeFile(`${process.argv[8]}/${report_count}.html`,  stats_html);
    await page.screenshot({ path: `${process.argv[8]}/screenshot-${report_count}.png` });
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

const duration = parseInt(process.argv[6]);

console.log(` - URL: ${process.argv[2]}`);
console.log(` - VIDEO-FILE: ${process.argv[3]}`);
console.log(` - DURATION: ${process.argv[4]}`);
console.log(` - STATS: ${process.argv[5]}`);

(async () => {

    const browser = await Puppeteer.launch({
        executablePath: '/usr/bin/google-chrome',
        headless: 'new', // or false
        args: [
            '--disable-accelerated-2d-canvas',
            '--disable-dev-shm-usage',
            '--disable-gpu',
            '--disable-setuid-sandbox',
            '--no-first-run',
            '--no-sandbox',
            '--no-zygote',
            '--use-fake-device-for-media-stream',
            '--use-fake-ui-for-media-stream',
            // `--use-file-for-fake-video-capture=${process.argv[3]}`
          ],
    });


    const stats_page = await browser.newPage();
    await stats_page.goto('chrome://webrtc-internals', {timeout: 0});

    const page = await browser.newPage();
    await page.goto(process.argv[2], {timeout: 0});

    for (let s = 0; s < duration; s++) {
        await sleep(1000);
        console.log(` - collecting report`)
        collect_webrtc_internals();
    }

})();
