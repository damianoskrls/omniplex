import { mediaUrl } from './media';
import { ageFromDob, conditionKeys, conditionLabel, genderLabel, statusMeta } from './healthCardFields';

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

function heading(title) {
  return `<h2>${esc(title)}</h2>`;
}

function cardHtml({ client, file, photo }) {
  const health = file?.health || {};
  const intake = file?.intake || {};
  const goal = file?.goals?.find(g => g.id === intake.fitness_goal)?.label || intake.fitness_goal;
  const experience = { beginner: 'Αρχάριος', some: 'Κάποια εμπειρία', regular: 'Τακτικά' }[intake.experience] || intake.experience;
  const signed = health.signed_at ? new Date(health.signed_at).toLocaleString('el-GR') : '';
  const sign = signatureSrc(health.signature_data);
  const dob = String(health.date_of_birth || file?.profile?.date_of_birth || '').slice(0, 10);
  const age = ageFromDob(dob);
  const status = statusMeta(health.fitness_status);
  const keys = conditionKeys(health);
  const conditions = keys.length
    ? keys.map(conditionLabel).join(', ')
    : (health.has_conditions ? (health.conditions_text || 'Ναι') : '');
  const gender = genderLabel(health.gender);
  return `<!doctype html>
<html lang="el"><head><meta charset="utf-8"><title>Κάρτα υγείας — ${esc(client?.full_name)}</title>
<style>
  html, body { background: #fff; color: #111; }
  body { font-family: Arial, sans-serif; margin: 28px; }
  h1 { font-size: 22px; margin: 0 0 4px; }
  h2 { font-size: 15px; margin: 18px 0 6px; }
  .muted { color: #555; font-size: 13px; margin-bottom: 14px; }
  img.photo { width: 120px; height: 150px; object-fit: cover; border: 1px solid #ddd; border-radius: 8px; background: #f4f4f4; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  th, td { text-align: left; padding: 6px 8px; border-bottom: 1px solid #eee; vertical-align: top; }
  th { width: 210px; color: #444; font-weight: 700; }
  .pill { display: inline-block; padding: 3px 10px; border-radius: 99px; font-weight: 700; }
  img.sign { height: 70px; background: #fff; border: 1px solid #ddd; }
  @media print { body { margin: 10mm; } }
</style></head><body>
  <h1>Κάρτα υγείας ασκούμενου</h1>
  <div class="muted">${esc(client?.full_name || '')}${signed ? ` · Υπογράφηκε ${esc(signed)}` : ''}</div>
  <table>
    <tr>
      <td style="width:140px;border:none;padding:0 16px 0 0;vertical-align:top">
        ${photo ? `<img class="photo" src="${esc(photo)}" alt="">` : ''}
      </td>
      <td style="border:none;padding:0">
        ${heading('Προσωπικά στοιχεία')}
        <table>
          ${row('Όνομα', client?.full_name)}
          ${row('Email', client?.email)}
          ${row('Τηλέφωνο', client?.phone)}
          ${row('Ημερομηνία γέννησης', dob ? `${dob}${age != null ? ` (${age} ετών)` : ''}` : '')}
          ${row('Φύλο', gender)}
          ${row('Ύψος', health.height_cm || file?.profile?.height_cm ? `${health.height_cm || file?.profile?.height_cm} cm` : '')}
          ${row('Βάρος', health.weight_kg || file?.profile?.weight_kg ? `${health.weight_kg || file?.profile?.weight_kg} kg` : '')}
        </table>
      </td>
    </tr>
  </table>
  ${heading('Κατάσταση')}
  <div>${status ? `<span class="pill" style="background:${status[3]};color:${status[2]}">${esc(status[1])}</span>` : '—'}</div>
  ${heading('Παθήσεις')}
  <table>
    ${row('Επιλογές', conditions)}
    ${row('Άλλο', keys.includes('other') ? health.conditions_text : '')}
  </table>
  ${heading('Τραυματισμοί / περιορισμοί')}
  <table>
    ${row('Περιοχή σώματος', health.injury_area)}
    ${row('Πρόβλημα', health.injury_problem)}
    ${row('Περιορισμοί στην άσκηση', health.injury_limits)}
    ${row('Αποκατάσταση', health.injury_recovery)}
  </table>
  ${heading('Φαρμακευτική αγωγή')}
  <table>
    ${row('Λαμβάνει αγωγή', health.takes_medication ? 'Ναι' : 'Όχι')}
    ${row('Περιγραφή', health.takes_medication ? health.medication_text : '')}
  </table>
  ${heading('Επαφή έκτακτης ανάγκης')}
  <table>
    ${row('Όνομα', health.emergency_name)}
    ${row('Σχέση', health.emergency_relation)}
    ${row('Τηλέφωνο', health.emergency_phone)}
  </table>
  ${heading('Ιατρικά στοιχεία έκτακτης ανάγκης')}
  <table>
    ${row('Αλλεργίες', health.allergies)}
    ${row('Ομάδα αίματος', health.blood_type)}
    ${row('Οδηγίες', health.emergency_instructions)}
    ${row('Άλλες πληροφορίες', health.other_info)}
  </table>
  ${heading('Πρώτη εγγραφή')}
  <table>
    ${row('Στόχος', goal)}
    ${row('Γιατί έρχεται', intake.motivation)}
    ${row('Τι θέλει να πετύχει', intake.goal_text)}
    ${row('Εμπειρία', experience)}
    ${row('Φορές / εβδομάδα', intake.visits_per_week)}
  </table>
  ${sign ? `<p style="margin-top:18px">Ηλεκτρονική υπογραφή</p><img class="sign" src="${sign}" alt="">` : ''}
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
