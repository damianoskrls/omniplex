import { mediaUrl } from './media';

function esc(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function row(label, value) {
  return `<tr><th>${esc(label)}</th><td>${esc(value || '—')}</td></tr>`;
}

function signatureSrc(value) {
  const src = String(value || '');
  return src.startsWith('data:image/') ? src : '';
}

function cardHtml({ client, file, photo }) {
  const health = file?.health || {};
  const intake = file?.intake || {};
  const goal = file?.goals?.find(g => g.id === intake.fitness_goal)?.label || intake.fitness_goal;
  const experience = { beginner: 'Αρχάριος', some: 'Κάποια εμπειρία', regular: 'Τακτικά' }[intake.experience] || intake.experience;
  const signed = health.signed_at ? new Date(health.signed_at).toLocaleString('el-GR') : '';
  const sign = signatureSrc(health.signature_data);
  return `<!doctype html>
<html lang="el"><head><meta charset="utf-8"><title>Κάρτα υγείας — ${esc(client?.full_name)}</title>
<style>
  html, body { background: #fff; color: #111; }
  body { font-family: Arial, sans-serif; margin: 32px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  .muted { color: #555; font-size: 13px; margin-bottom: 18px; }
  img.photo { width: 140px; height: 170px; object-fit: cover; border: 1px solid #ddd; border-radius: 8px; background: #f4f4f4; }
  table { width: 100%; border-collapse: collapse; font-size: 14px; }
  th, td { text-align: left; padding: 7px 8px; border-bottom: 1px solid #eee; vertical-align: top; }
  th { width: 180px; color: #444; font-weight: 700; }
  img.sign { height: 70px; background: #fff; border: 1px solid #ddd; }
  @media print { body { margin: 12mm; } }
</style></head><body>
  <h1>Κάρτα υγείας ασκούμενου</h1>
  <div class="muted">${esc(client?.full_name || '')}${signed ? ` · Υπογράφηκε ${esc(signed)}` : ' · Χωρίς ηλεκτρονική υπογραφή'}</div>
  <table>
    <tr>
      <td style="width:160px;border:none;padding:0 16px 0 0">
        ${photo ? `<img class="photo" src="${esc(photo)}" alt="">` : ''}
      </td>
      <td style="border:none;padding:0">
        <table>
          ${row('Email', client?.email)}
          ${row('Τηλέφωνο', client?.phone)}
          ${row('Στόχος', goal)}
          ${row('Γιατί έρχεται', intake.motivation)}
          ${row('Τι θέλει να πετύχει', intake.goal_text)}
          ${row('Εμπειρία', experience)}
          ${row('Φορές / εβδομάδα', intake.visits_per_week)}
          ${row('Πρόβλημα υγείας', health.has_conditions ? (health.conditions_text || 'Ναι') : 'Όχι')}
          ${row('Φάρμακα', health.takes_medication ? (health.medication_text || 'Ναι') : 'Όχι')}
        </table>
      </td>
    </tr>
  </table>
  ${sign ? `<p style="margin-top:22px">Ηλεκτρονική υπογραφή</p><img class="sign" src="${sign}" alt="">` : ''}
</body></html>`;
}

function printWhenReady(win) {
  const finish = () => {
    setTimeout(() => {
      win.focus();
      win.print();
    }, 80);
  };
  const imgs = [...win.document.images];
  if (!imgs.length) {
    finish();
    return;
  }
  let pending = imgs.length;
  const done = () => {
    pending -= 1;
    if (pending <= 0) finish();
  };
  imgs.forEach((img) => {
    if (img.complete) done();
    else {
      img.addEventListener('load', done, { once: true });
      img.addEventListener('error', done, { once: true });
    }
  });
}

export function printHealthCard({ client, file }) {
  const win = window.open('', '_blank', 'width=860,height=1100');
  if (!win) return false;
  const photo = mediaUrl(file?.health?.photo_url);
  win.document.open();
  win.document.write(cardHtml({ client, file, photo }));
  win.document.close();
  if (win.document.readyState === 'complete') printWhenReady(win);
  else win.addEventListener('load', () => printWhenReady(win), { once: true });
  return true;
}
