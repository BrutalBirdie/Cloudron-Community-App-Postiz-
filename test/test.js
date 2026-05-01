#!/usr/bin/env node

import { setTimeout as sleep } from 'node:timers/promises';

import { app, clearCache, click, cloudronCli, goto, loginOIDC, sendKeys, setupBrowser, takeScreenshot, teardownBrowser, waitFor } from '@cloudron/charlie';

/* global it, describe, before, after, afterEach */

describe('Application life cycle test', function () {
    const ADMIN_EMAIL = 'admin@cloudron.local';
    const ADMIN_PASSWORD = 'changeme123';

    const COMPANY_NAME = 'Cloudron';
    const SIGNATURE_TEXT = 'AM30'; // keep this short! text gets elided and tests fail

    before(setupBrowser);
    after(teardownBrowser);

    afterEach(async function () {
        await takeScreenshot(this.currentTest);
    });

    async function waitForApp() {
        await goto(`https://${app.fqdn}/auth/login`, 'xpath=//*[@name="email"] | //a[contains(@href, "launches")]');
        // todo: check API is ready
        console.log('Waiting for 40 seconds to start app services (backend, worker, cron)');
        await sleep(40000);
    }

    async function register(emailAddr, pass) {
        await goto(`https://${app.fqdn}/auth`, 'xpath=//input[@name="email"]');
        await sendKeys('xpath=//input[@name="email"]', emailAddr);
        await sendKeys('xpath=//input[@name="password"]', pass);
        await sendKeys('xpath=//input[@name="company"]', COMPANY_NAME);
        await click('xpath=//button[@type="submit"]');
        await waitFor('xpath=//a[contains(@href, "launches")]');
    }

    async function login(emailAddr, pass) {
        await goto(`https://${app.fqdn}/auth/login`, 'xpath=//input[@name="email"]');
        await sendKeys('xpath=//input[@name="email"]', emailAddr);
        await sendKeys('xpath=//input[@name="password"]', pass);
        await click('xpath=//button[@type="submit"]');
        await waitFor('xpath=//a[contains(@href, "launches")]'); // the Calendar
    }

    async function loginViaOIDC() {
        await goto(`https://${app.fqdn}/auth/login`, 'xpath=//div[contains(@class, "cursor-pointer") and contains(., "Sign in with")]');
        await click('xpath=//div[contains(@class, "cursor-pointer") and contains(., "Sign in with")]');
        await loginOIDC('xpath=//a[contains(@href, "launches")] | //input[@name="company"]');

        // create app account if prompted
        try {
            await waitFor('xpath=//input[@name="company"]', { timeout: 3000 });
            await sendKeys('xpath=//input[@name="company"]', COMPANY_NAME);
            await click('xpath=//button[@type="submit"]');
            await waitFor('xpath=//a[contains(@href, "launches")]');
        } catch { /* already had account */ }
    }

    async function createSignature(signature) {
        await goto(`https://${app.fqdn}/settings`, 'xpath=//div[contains(@class, "group/profile") and contains(., "Signatures")]');
        await click('xpath=//div[contains(@class, "group/profile") and contains(., "Signatures")]');

        await click('Add a signature');

        await sendKeys('xpath=//div[@role="textbox"]', signature);
        await click('xpath=//button[@type="submit" and contains(., "Save")]');
    }

    async function checkSignature(signature) {
        await goto(`https://${app.fqdn}/settings`, 'xpath=//div[contains(@class, "group/profile") and contains(., "Signatures")]');
        await click('xpath=//div[contains(@class, "group/profile") and contains(., "Signatures")]');
        await waitFor(`xpath=//div[contains(., "${signature}")]`);
    }

    async function disableEmailNotifications() {
        await cloudronCli.exec(`sed '/.*EMAIL_PROVIDER="nodemailer"/d' -i /app/data/env`);
        await cloudronCli.restart();
    }

    it('install app', cloudronCli.install);

    it('disable email notifications (activation emails)', disableEmailNotifications);
    it('wait for all services', waitForApp);

    it('can register admin', register.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can create signature', createSignature.bind(null, SIGNATURE_TEXT));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', clearCache);

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', clearCache);

    it('can login OIDC', loginViaOIDC);
    it('can logout', clearCache);

    it('can restart app', cloudronCli.restart);
    it('wait for all services', waitForApp);

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', clearCache);

    it('can login OIDC', loginViaOIDC);
    it('can logout', clearCache);

    it('backup app', cloudronCli.createBackup);

    it('restore app', cloudronCli.restoreFromLatestBackup);
    it('wait for all services', waitForApp);

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', clearCache);

    it('can login OIDC', loginViaOIDC);
    it('can logout', clearCache);

    it('move to different location', cloudronCli.changeLocation);
    it('wait for all services', waitForApp);

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', clearCache);

    it('can login OIDC', loginViaOIDC);
    it('can logout', clearCache);

    it('uninstall app', cloudronCli.uninstall);

    // test update
    it('can install app for update', cloudronCli.appstoreInstall);

    it('disable email notifications (activation emails)', disableEmailNotifications);
    it('wait for all services', waitForApp);

    it('can register admin', register.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));

    it('can create signature', createSignature.bind(null, SIGNATURE_TEXT));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', clearCache);

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', clearCache);

    it('can login OIDC', loginViaOIDC);
    it('can logout', clearCache);

    it('can update', cloudronCli.update);
    it('wait for all services', waitForApp);

    it('can admin login', login.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));

    it('can check signature', checkSignature.bind(null, SIGNATURE_TEXT));
    it('can logout', clearCache);

    it('can login OIDC', loginViaOIDC);
    it('can logout', clearCache);

    it('uninstall app', cloudronCli.uninstall);
});
