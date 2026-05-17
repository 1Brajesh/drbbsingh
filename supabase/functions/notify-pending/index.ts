// notify-pending — Supabase Edge Function
// Fires from a Database Webhook when a row is inserted into `remembrances`.
// Sends an email to the admin via Resend.

const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')!;
const ADMIN_EMAIL    = 'engineerbk@gmail.com';
const ADMIN_URL      = 'https://drbbsingh.com/admin/';
const SITE_NAME      = 'drbbsingh.com';
const FROM_ADDRESS   = 'drbbsingh.com <onboarding@resend.dev>';

const escapeHtml = (s: unknown): string =>
  String(s ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]!));

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch {
    return new Response('Invalid JSON', { status: 400 });
  }

  // Only act on INSERTs to remembrances with status='pending'.
  // Admin actions (approve/edit/delete) won't trigger this path.
  if (payload?.type !== 'INSERT'
      || payload?.table !== 'remembrances'
      || payload?.record?.status !== 'pending') {
    return new Response('Ignored', { status: 200 });
  }

  const r = payload.record;
  const html = `
    <div style="font-family:system-ui,-apple-system,sans-serif;max-width:560px;margin:0 auto;color:#222">
      <h2 style="margin:0 0 12px;font-weight:500">New remembrance pending review</h2>
      <p style="color:#666;margin:0 0 20px">A visitor just submitted a remembrance on ${SITE_NAME}.</p>
      <table style="border-collapse:collapse;width:100%;font-size:14px">
        <tr>
          <td style="padding:8px 0;color:#999;width:110px;vertical-align:top">Name</td>
          <td style="padding:8px 0"><strong>${escapeHtml(r.name)}</strong></td>
        </tr>
        <tr>
          <td style="padding:8px 0;color:#999;vertical-align:top">Connection</td>
          <td style="padding:8px 0">${escapeHtml(r.connection) || '<em style="color:#bbb">(none given)</em>'}</td>
        </tr>
        <tr>
          <td style="padding:8px 0;color:#999;vertical-align:top">Message</td>
          <td style="padding:8px 0;white-space:pre-wrap;line-height:1.5">${escapeHtml(r.message)}</td>
        </tr>
      </table>
      <p style="margin:28px 0 0">
        <a href="${ADMIN_URL}"
           style="display:inline-block;padding:10px 20px;background:#8b6914;color:#fff;
                  text-decoration:none;border-radius:4px;font-size:14px">
          Review in admin panel
        </a>
      </p>
    </div>
  `;

  const resendRes = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: FROM_ADDRESS,
      to: ADMIN_EMAIL,
      subject: `Pending remembrance from ${r.name}`,
      html,
    }),
  });

  if (!resendRes.ok) {
    const errText = await resendRes.text();
    console.error('Resend error', resendRes.status, errText);
    return new Response(`Resend failed: ${errText}`, { status: 500 });
  }

  return new Response('Email sent', { status: 200 });
});
