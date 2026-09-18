import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Bell, Clock, Users, RefreshCw } from 'lucide-react';

const REMINDER_TYPES = [
  {
    key: 'booking_reminder',
    icon: <Clock size={18} />,
    title: 'Υπενθύμιση Κράτησης',
    desc: 'Στέλνει αυτόματα μήνυμα λίγο πριν από κάθε κράτηση.',
    field: { label: 'Ώρες πριν', key: 'hours_before', type: 'number', min: 1, max: 72 },
    variable: '{time}',
  },
  {
    key: 'membership_expiry',
    icon: <Bell size={18} />,
    title: 'Λήξη Πακέτου',
    desc: 'Ενημερώνει τον πελάτη όταν πλησιάζει η λήξη του πακέτου του.',
    field: { label: 'Ημέρες πριν', key: 'days_before', type: 'number', min: 1, max: 30 },
    variable: '{days}',
  },
  {
    key: 'inactive_client',
    icon: <Users size={18} />,
    title: 'Ανενεργοί Πελάτες',
    desc: 'Στέλνει μήνυμα σε πελάτες που δεν έχουν κάνει κράτηση για αρκετές ημέρες.',
    field: { label: 'Ημέρες αδράνειας', key: 'days_inactive', type: 'number', min: 7, max: 180 },
    variable: '{days}',
  },
];

const CHANNELS = [
  { value: 'sms', label: 'SMS' },
  { value: 'email', label: 'Email' },
];

export default function Reminders() {
  const [settings, setSettings] = useState(null);
  const [log, setLog] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [tab, setTab] = useState('settings');

  useEffect(() => { loadAll(); }, []);

  async function loadAll() {
    setLoading(true);
    try {
      const [s, l] = await Promise.all([
        api.get('/reminders/settings'),
        api.get('/reminders/log'),
      ]);
      setSettings(s.data);
      setLog(l.data || []);
    } catch { toast.error('Σφάλμα φόρτωσης'); }
    finally { setLoading(false); }
  }

  function patch(key, field, value) {
    setSettings(prev => ({ ...prev, [key]: { ...prev[key], [field]: value } }));
  }

  async function save() {
    setSaving(true);
    try {
      await api.put('/reminders/settings', settings);
      toast.success('Αποθηκεύτηκε!');
    } catch { toast.error('Σφάλμα αποθήκευσης'); }
    finally { setSaving(false); }
  }

  if (loading) return <Layout title="Αυτόματες Υπενθυμίσεις"><div className="text-muted">Φόρτωση…</div></Layout>;

  return (
    <Layout title="Αυτόματες Υπενθυμίσεις"
      headerActions={<button className="btn btn-primary" onClick={save} disabled={saving}>{saving ? 'Αποθήκευση…' : 'Αποθήκευση'}</button>}>

      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {[['settings', 'Ρυθμίσεις'], ['log', 'Ιστορικό']].map(([k, l]) => (
          <button key={k} onClick={() => setTab(k)} style={{
            padding: '8px 18px', borderRadius: 10, border: `2px solid ${tab === k ? 'var(--accent)' : 'var(--border)'}`,
            background: tab === k ? 'var(--accent-dim)' : 'var(--surface)',
            color: tab === k ? 'var(--accent)' : 'var(--text-2)', fontWeight: 700, fontSize: '0.85rem', cursor: 'pointer',
          }}>{l}</button>
        ))}
        <button className="btn btn-secondary btn-sm" style={{ marginLeft: 'auto' }} onClick={loadAll}>
          <RefreshCw size={13} />
        </button>
      </div>

      {tab === 'settings' && settings && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {REMINDER_TYPES.map(rt => {
            const cfg = settings[rt.key] || {};
            return (
              <div key={rt.key} className="card">
                <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14 }}>
                  <div style={{ width: 36, height: 36, borderRadius: 10, background: 'var(--accent-dim)', color: 'var(--accent)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
                    {rt.icon}
                  </div>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 4 }}>
                      <span style={{ fontWeight: 700, fontSize: '0.95rem' }}>{rt.title}</span>
                      <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', marginLeft: 'auto' }}>
                        <input type="checkbox" checked={!!cfg.enabled} onChange={e => patch(rt.key, 'enabled', e.target.checked)} style={{ width: 16, height: 16, accentColor: 'var(--accent)', cursor: 'pointer' }} />
                        <span style={{ fontSize: '0.82rem', color: 'var(--text-2)' }}>{cfg.enabled ? 'Ενεργό' : 'Ανενεργό'}</span>
                      </label>
                    </div>
                    <div style={{ fontSize: '0.82rem', color: 'var(--text-3)', marginBottom: 14 }}>{rt.desc}</div>

                    {cfg.enabled && (<>
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 12 }}>
                        <div className="form-group" style={{ margin: 0 }}>
                          <label className="form-label">{rt.field.label}</label>
                          <input type="number" className="form-input" min={rt.field.min} max={rt.field.max}
                            value={cfg[rt.field.key] || rt.field.min}
                            onChange={e => patch(rt.key, rt.field.key, parseInt(e.target.value) || rt.field.min)} />
                        </div>
                        <div className="form-group" style={{ margin: 0 }}>
                          <label className="form-label">Κανάλι</label>
                          <select className="form-input" value={cfg.channel || 'sms'} onChange={e => patch(rt.key, 'channel', e.target.value)}>
                            {CHANNELS.map(c => <option key={c.value} value={c.value}>{c.label}</option>)}
                          </select>
                        </div>
                      </div>
                      <div className="form-group" style={{ margin: 0 }}>
                        <label className="form-label" style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span>Κείμενο μηνύματος</span>
                          <span style={{ fontSize: '0.73rem', color: 'var(--text-3)' }}>Χρήση: <code style={{ fontSize: '0.73rem' }}>{rt.variable}</code> για δυναμικές τιμές</span>
                        </label>
                        <textarea className="form-input" rows={3} style={{ resize: 'vertical', fontFamily: 'inherit', fontSize: '0.875rem' }}
                          value={cfg.message || ''}
                          onChange={e => patch(rt.key, 'message', e.target.value)} />
                        <div style={{ fontSize: '0.73rem', color: 'var(--text-3)', marginTop: 4 }}>
                          {(cfg.message || '').length} χαρ.{(cfg.message || '').length > 160 ? ` · ${Math.ceil((cfg.message || '').length / 160)} SMS` : ''}
                        </div>
                      </div>
                    </>)}
                  </div>
                </div>
              </div>
            );
          })}

          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <button className="btn btn-primary" onClick={save} disabled={saving} style={{ minWidth: 140 }}>
              {saving ? 'Αποθήκευση…' : 'Αποθήκευση αλλαγών'}
            </button>
          </div>
        </div>
      )}

      {tab === 'log' && (
        <div className="card card--flush">
          {log.length === 0 ? (
            <div style={{ padding: 40, textAlign: 'center', color: 'var(--text-3)', fontSize: '0.88rem' }}>
              Δεν έχουν σταλεί υπενθυμίσεις ακόμα
            </div>
          ) : (
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
              <thead>
                <tr style={{ borderBottom: '1px solid var(--border)', background: 'var(--surface-2)' }}>
                  {['Τύπος', 'Πελάτης', 'Κανάλι', 'Κατάσταση', 'Ημερομηνία'].map(h => (
                    <th key={h} style={{ padding: '10px 14px', textAlign: 'left', fontWeight: 600, color: 'var(--text-2)', fontSize: '0.78rem' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {log.map(r => (
                  <tr key={r.id} style={{ borderBottom: '1px solid var(--border)' }}>
                    <td style={{ padding: '10px 14px' }}>{TYPE_LABELS[r.type] || r.type}</td>
                    <td style={{ padding: '10px 14px' }}>{r.full_name || '—'}</td>
                    <td style={{ padding: '10px 14px' }}>{r.channel.toUpperCase()}</td>
                    <td style={{ padding: '10px 14px' }}>
                      <span style={{ fontSize: '0.75rem', fontWeight: 600, padding: '2px 8px', borderRadius: 999, background: r.status === 'sent' ? '#dcfce7' : '#fee2e2', color: r.status === 'sent' ? '#16a34a' : '#dc2626' }}>
                        {r.status === 'sent' ? 'Εστάλη' : 'Σφάλμα'}
                      </span>
                    </td>
                    <td style={{ padding: '10px 14px', color: 'var(--text-3)' }}>{new Date(r.sent_at).toLocaleString('el-GR')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </Layout>
  );
}

const TYPE_LABELS = {
  booking_reminder: 'Υπενθ. Κράτησης',
  membership_expiry: 'Λήξη Πακέτου',
  inactive_client: 'Ανενεργός',
};
