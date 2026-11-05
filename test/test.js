
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
        // backend only listens once it is connected to Temporal
        for (let i = 0; i < 60; i++) {
            const res = await fetch(`https://${app.fqdn}/api/auth/can-register`).catch(() => null);
            if (res?.ok) return;
            await sleep(5000);
        }
        throw new Error('backend did not come up');
    }

    async function registrationIsClosed() {
        const res = await fetch(`https://${app.fqdn}/api/auth/register`, {
            method: 'POST',
            headers: { 'content-type': 'application/json' },
            body: JSON.stringify({ email: 'intruder@cloudron.local', password: ADMIN_PASSWORD, company: 'Intruder', provider: 'LOCAL' })
        });
        if (res.status !== 400) throw new Error(`expected registration to be refused, got ${res.status}`);
    }

    async function register(emailAddr, pass) {
        await goto(`https://${app.fqdn}/auth`, 'placeholder=Email Address');
        await sendKeys('placeholder=Email Address', emailAddr);
        await sendKeys('placeholder=Password', pass);
        await sendKeys('placeholder=Company', COMPANY_NAME);
        await click('Create Account');
        await waitFor('Calendar', { role: 'link' });
    }

    async function login(emailAddr, pass) {
        await goto(`https://${app.fqdn}/auth/login`, 'placeholder=Email Address');
        await sendKeys('placeholder=Email Address', emailAddr);
        await sendKeys('placeholder=Password', pass);
        await click('Sign in');
        await waitFor('Calendar', { role: 'link' });
    }

    async function loginViaOIDC() {
        await goto(`https://${app.fqdn}/auth/login`, /Sign in with/);
        await click(/Sign in with/);
        // first SSO login asks for a company name, later ones land on the calendar
        await loginOIDC(/^(Calendar|Create Account)$/);

        try {
            await waitFor('placeholder=Company', { timeout: 3000 });
            await sendKeys('placeholder=Company', COMPANY_NAME);
            await click('Create Account');
            await waitFor('Calendar', { role: 'link' });
        } catch { /* already had account */ }
    }

    async function openSignatures() {
        await goto(`https://${app.fqdn}/settings`, 'Signatures');
        await click('Signatures');
    }

    async function createSignature(signature) {
        await openSignatures();
        await click('Add a signature');
        await sendKeys('role=textbox', signature);
        await click('Save', { role: 'button' });
    }

    async function checkSignature(signature) {
        await openSignatures();
        // the list truncates to "AM30..."
        await waitFor(new RegExp(signature));
    }

    async function disableEmailNotifications() {
        await cloudronCli.exec(`sed '/.*EMAIL_PROVIDER="nodemailer"/d' -i /app/data/env`);
        await cloudronCli.restart();
    }

    it('install app', cloudronCli.install);

    it('disable email notifications (activation emails)', disableEmailNotifications);
    it('wait for all services', waitForApp);

    it('can register admin', register.bind(null, ADMIN_EMAIL, ADMIN_PASSWORD));
    it('registration is closed after the first account', registrationIsClosed);
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
});
