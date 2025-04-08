#!/usr/bin/env node

/* global it, xit, describe, before, after, afterEach */

'use strict';

require('chromedriver');

const execSync = require('child_process').execSync,
    expect = require('expect.js'),
    fs = require('fs'),
    path = require('path'),
    url = require('url'),
    util = require('util'),
    { Builder, By, Key, until } = require('selenium-webdriver'),
    { Options } = require('selenium-webdriver/chrome');

describe('Application life cycle test', function () {
    this.timeout(0);

    const LOCATION = process.env.LOCATION || 'test';
    const TIMEOUT = parseInt(process.env.TIMEOUT, 10) || 40000;
    const EXEC_ARGS = { cwd: path.resolve(__dirname, '..'), stdio: 'inherit' };

    let browser, app;

    const ADMIN_EMAIL = 'admin@cloudron.local';
    const ADMIN_PASSWORD = 'changeme123';

    const COMPANY_NAME = 'Cloudron';
    const SIGNATURE_TEXT = 'Cloudron';

    before(async function () {
        await startBrowser();
        if (!fs.existsSync('./screenshots')) fs.mkdirSync('./screenshots');
    });

    after(function () {
        browser.quit();
    });

    afterEach(async function () {
        if (!process.env.CI || !app) return;

        const currentUrl = await browser.getCurrentUrl();
        if (!currentUrl.includes(app.domain)) return;
        expect(this.currentTest.title).to.be.a('string');

        const screenshotData = await browser.takeScreenshot();
        fs.writeFileSync(`./screenshots/${new Date().getTime()}-${this.currentTest.title.replaceAll(' ', '_')}.png`, screenshotData, 'base64');
    });

    function getAppInfo() {
        const inspect = JSON.parse(execSync('cloudron inspect'));
        app = inspect.apps.filter(function (a) { return a.location.startsWith(LOCATION); })[0];
        expect(app).to.be.an('object');
    }

    async function clearCache() {
        await browser.manage().deleteAllCookies();
        await browser.quit();
        await startBrowser();
    }

    async function startBrowser() {
        browser = null;
        const chromeOptions = new Options().windowSize({ width: 1280, height: 1024 });
        if (process.env.CI) chromeOptions.addArguments('no-sandbox', 'disable-dev-shm-usage', 'headless');
        chromeOptions.addArguments(`--user-data-dir=${await fs.promises.mkdtemp('/tmp/test-')}`); // --profile-directory=Default
        browser = new Builder().forBrowser('chrome').setChromeOptions(chromeOptions).build();
    }

    async function waitForElement(elem) {
        await browser.wait(until.elementLocated(elem), TIMEOUT);
        await browser.wait(until.elementIsVisible(browser.findElement(elem)), TIMEOUT);
    }

    async function register(email, password) {
        await browser.get(`https://${app.fqdn}/auth`);

        await waitForElement(By.xpath('//*[@name="email"]'));
        await browser.findElement(By.xpath('//input[@name="email"]')).sendKeys(email);
        await browser.findElement(By.xpath('//input[@name="password"]')).sendKeys(password);
        await browser.findElement(By.xpath('//input[@name="company"]')).sendKeys(COMPANY_NAME);
        await browser.sleep(2000);
        await browser.findElement(By.xpath('//button[@type="submit"]')).click();
        await browser.sleep(2000);
        await waitForElement(By.xpath('//a[contains(@href, "launches")]'));
    }

    async function login(email, password) {
        await browser.get(`https://${app.fqdn}/auth/login`);

        await waitForElement(By.xpath('//*[@name="email"]'));
        await browser.findElement(By.xpath('//input[@name="email"]')).sendKeys(email);
        await browser.findElement(By.xpath('//input[@name="password"]')).sendKeys(password);
        await browser.sleep(2000);
        await browser.findElement(By.xpath('//button[@type="submit"]')).click();
        await browser.sleep(2000);
        await waitForElement(By.xpath('//a[contains(@href, "launches")]')); // the Calendar
    }

    async function logout() {
        await clearCache();
    }

    async function createSignature(signature) {
        await browser.get(`https://${app.fqdn}/settings`);

        await waitForElement(By.id('mantine-r1-tab-signatures'));
        await browser.findElement(By.id('mantine-r1-tab-signatures')).click();

        await waitForElement(By.xpath('//button[contains(., "Add a signature")]'));
        await browser.findElement(By.xpath('//button[contains(., "Add a signature")]')).click();

        await waitForElement(By.xpath('//div[@role="textbox"]'));
        await browser.findElement(By.xpath('//div[@role="textbox"]')).sendKeys(signature);
        await browser.findElement(By.xpath('//button[@type="submit" and contains(., "Save")]')).click();

        await waitForElement(By.xpath(`//div[contains(., "${signature}")]`));
    }

    async function checkSignature(signature) {
        await browser.get(`https://${app.fqdn}/settings`);

        await waitForElement(By.id('mantine-r1-tab-signatures'));
        await browser.findElement(By.id('mantine-r1-tab-signatures')).click();

        await waitForElement(By.xpath(`//div[contains(., "${signature}")]`));
    }

    async function removeEmailProvider() {
        execSync(`cloudron exec --app ${app.id} -- sed \'/.*EMAIL_PROVIDER="nodemailer"/d\' -i /app/data/env.sh`);
    }

    xit('build app', function () {
        execSync('cloudron build', EXEC_ARGS);
    });

    it('install app', function () { execSync('cloudron install --location ' + LOCATION, EXEC_ARGS); });

    it('can get app information', getAppInfo);

    it('disable email notifications (activation emails)', async function () {
        await removeEmailProvider();
        execSync(`cloudron restart --app ${app.id}`);
        console.log('waiting for 20 seconds after app restart');
        await browser.sleep(40000);
    });

    it('can register admin', register.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD, false));
    it('can create signature', createSignature.bind(null, SIGNATURE_TEXT));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', logout);

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', logout);

    it('can restart app', async function () {
        execSync(`cloudron restart --app ${app.id}`);
        console.log('waiting for 20 seconds after app restart');
        await browser.sleep(40000);
    });

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', logout);

    it('backup app', function () {
        execSync('cloudron backup create --app ' + app.id, EXEC_ARGS);
    });

    it('restore app', async function () {
        const backups = JSON.parse(execSync('cloudron backup list --raw'));
        execSync('cloudron uninstall --app ' + app.id, EXEC_ARGS);
        execSync('cloudron install --no-sso --location ' + LOCATION, EXEC_ARGS);
        getAppInfo();
        execSync(`cloudron restore --backup ${backups[0].id} --app ${app.id}`, EXEC_ARGS);
        console.log('waiting for 20 seconds after app restart');
        await browser.sleep(40000);
    });
    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', logout);

    it('move to different location', async function () {
        // ensure we don't hit NXDOMAIN in the mean time
        await browser.get('about:blank');
        execSync(`cloudron configure --app ${app.id} --location ${LOCATION}2`, EXEC_ARGS);

        getAppInfo();
        console.log('waiting for 20 seconds after app restart');
        await browser.sleep(40000);
    });

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', logout);

    it('uninstall app', function () {
        execSync('cloudron uninstall --app ' + app.id, EXEC_ARGS);
    });

    // test update
    it('can install app', async function () {
        execSync('cloudron install --no-sso --appstore-id com.postiz.cloudronapp --location ' + LOCATION, EXEC_ARGS);
        console.log('waiting for 20 seconds after app restart');
        await browser.sleep(40000);
        getAppInfo();
    });

    it('disable email notifications (activation emails)', async function () {
        await removeEmailProvider();
        execSync(`cloudron restart --app ${app.id}`);
        console.log('waiting for 20 seconds after app restart');
        await browser.sleep(40000);
    });

    it('can register admin', register.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD, false));
    it('can create signature', createSignature.bind(null, SIGNATURE_TEXT));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', logout);

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', logout);

    it('can update', async function () {
        execSync('cloudron update --app ' + LOCATION, EXEC_ARGS);
        console.log('waiting for 20 seconds after app restart');
        await browser.sleep(40000);
    });

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', logout);

    it('uninstall app', function () {
        execSync('cloudron uninstall --app ' + app.id, EXEC_ARGS);
    });
});
