import asyncio
from aiosmtpd.controller import Controller
from aiosmtpd.smtp import AuthResult

def auth(server, session, envelope, mechanism, data):
    ok = data.login == b"u" and data.password == b"p"
    print("AUTH", mechanism, data.login, ok, flush=True)
    return AuthResult(success=ok)

class H:
    async def handle_DATA(self, server, session, envelope):
        print("MAIL from", envelope.mail_from, "to", envelope.rcpt_tos, "authed", session.authenticated, flush=True)
        print(envelope.content.decode()[:400], flush=True)
        return "250 OK"

async def main():
    Controller(H(), hostname="0.0.0.0", port=2525, authenticator=auth, auth_require_tls=False, auth_required=True).start()
    await asyncio.Event().wait()
asyncio.run(main())
