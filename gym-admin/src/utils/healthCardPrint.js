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

export function printHealthCard({ client, file }) {
  const health = file?.health || {};
  const intake = file?.intake || {};
  const goal = file?.goals?.find(g => g.id === intake.fitness_goal)?.label || intake.fitness_goal;
  const experience = { beginner: 'Αρχάριος', some: 'Κάποια εμπειρία', regular: 'Τακτικά' }[intake.experience] || intake.experience;
  const photo = mediaUrl(health.photo_url);
  const signed = health.signed_at ? new Date(health.signed_at).toLocaleString('el-GR') : '';
  const win = window.open('', '_blank', 'noopener,noreferrer,width=860,height=1100');
  if (!win) return false;
  win.document.write(`<!doctype html>
<html lang="el"><head><meta charset="utf-8"><title>Κάρτα υγείας — ${esc(client?.full_name)}</title>
<style>
  body { font-family: Manrope, Arial, sans-serif; color: #111; margin: 32px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  .muted { color: #555; font-size: 13px; margin-bottom: 18px; }
  .layout { display: flex; gap: 24px; align-items: flex-start; }
  img.photo { width: 140px; height: 170px; object-fit: cover; border: 1px solid #ddd; border-radius: 8px; background: #f4f4f4; }
  table { width: 100%; border-collapse: collapse; font-size: 14px; }
  th, td { text-align: left; padding: 7px 8px; border-bottom: 1px solid #eee; vertical-align: top; }
  th { width: 180px; color: #444; font-weight: 700; }
  img.sign { height: 70px; background: #fff; border: 1px solid #ddd; }
  @media print { body { margin: 12mm; } }
</style></head><body>
  <h1>Κάρτα υγείας ασκούμενου</h1>
  <div class="muted">${esc(client?.full_name || '')}${signed ? ` · Υπογράφηκε ${esc(signed)}` : ' · Χωρίς ηλεκτρονική υπογραφή'}</div>
  <div class="layout">
    ${photo ? `<img class="photo" src="${esc(photo)}" alt="">` : '<div class="photo"></div>'}
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
  </div>
  ${health.signature_data ? `<p style="margin-top:22px">Ηλεκτρονική υπογραφή</p><img class="sign" src="${health.signature_data}" alt="">` : ''}
</body></html>`);
  win.document.close();
  setTimeout(() => {
    win.focus();
    win.print();
  }, 400);
  return true;
}
