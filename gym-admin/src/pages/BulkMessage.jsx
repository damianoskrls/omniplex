import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Send, Mail, MessageSquare, Users, CheckCircle, Clock } from 'lucide-react';

const FILTERS = [
  { value: 'all', label: 'Όλοι οι ενεργοί πελάτες' },
  { value: 'active_members', label: 'Πελάτες με ενεργό πακέτο' },
  { value: 'at_risk', label: 'Πελάτες σε κίνδυνο (>30 μέρες χωρίς κράτηση)' },
  { value: 'no_active_package', label: 'Πελάτες χωρίς ενεργό πακέτο' },
];

export default function BulkMessage() {
  const [campaigns, setCampaigns] = useState([]);
  const [loading, setLoading] = useState(true);
  const [channel, setChannel] = useState('sms');
  const [filterType, setFilterType] = useState('all');
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [preview, setPreview] = useState(null);
  const [sending, setSending] = useState(false);
  const [confirm, setConfirm] = useState(false);

  useEffect(() => { loadCampaigns(); }, []);

  useEffect(() => {
    const t = setTimeout(() => loadPreview(), 400);
    return () => clearTimeout(t);
  }, [channel, filterType]);

  async function loadCampaigns() {
    setLoading(true);
    try {
      const r = await api.get('/campaigns');
      setCampaigns(r.data || []);
    } catch { toast.error('Σφάλμα'); }
    finally { setLoading(false); }
  }

  async function loadPreview() {
    try {
      const r = await api.get(`/campaigns/preview?channel=${channel}&filter_type=${filterType}`);
      setPreview(r.data);
    } catch { setPreview(null); }
  }

  async function send() {
    if (!body.trim()) return toast.error('Γράψτε το μήνυμα');
    if (channel === 'email' && !subject.trim()) return toast.error('Γράψτε τίτλο email');
    setSending(true);
    try {
      const r = await api.post('/campaigns', { channel, subject, body, filter_type: filterType });
      toast.success(`Στέλνεται σε ${r.data.recipient_count} παραλήπτες!`);
      setBody(''); setSubject(''); setConfirm(false);
      setTimeout(loadCampaigns, 3000);
    } catch { toast.error('Σφάλμα αποστολής'); }
    finally { setSending(false); }
  }

  const smsChars = body.length;
  const smsParts = Math.ceil(smsChars / 160) || 1;

  return (
    <Layout title="Μαζική Αποστολή">
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 380px', gap: 24, alignItems: 'start' }}>

        {/* Compose */}
        <div className="card">
          <div style={{ fontWeight: 700, fontSize: '1rem', marginBottom: 20 }}>Νέο Μήνυμα</div>

          {/* Channel */}
          <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
            {[
              { v: 'sms', icon: <MessageSquare size={15} />, label: 'SMS' },
              { v: 'email', icon: <Mail size={15} />, label: 'Email' },
            ].map(ch => (
              <button key={ch.v} onClick={() => setChannel(ch.v)} style={{
                display: 'flex', alignItems: 'center', gap: 6, padding: '8px 18px',
                border: `2px solid ${channel === ch.v ? 'var(--accent)' : 'var(--border)'}`,
                borderRadius: 10, background: channel === ch.v ? 'var(--accent-dim)' : 'var(--surface)',
                color: channel === ch.v ? 'var(--accent)' : 'var(--text-2)',
                fontWeight: 700, fontSize: '0.85rem', cursor: 'pointer',
              }}>
                {ch.icon} {ch.label}
              </button>
            ))}
          </div>

          {/* Filter */}
          <div className="form-group">
            <label className="form-label">Παραλήπτες</label>
            <select className="form-input" value={filterType} onChange={e => setFilterType(e.target.value)}>
              {FILTERS.map(f => <option key={f.value} value={f.value}>{f.label}</option>)}
            </select>
          </div>

          {preview && (
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16, padding: '10px 14px', background: 'var(--accent-dim)', borderRadius: 10 }}>
              <Users size={15} style={{ color: 'var(--accent)' }} />
              <span style={{ fontSize: '0.84rem', color: 'var(--accent)', fontWeight: 600 }}>
                {preview.eligible} παραλήπτες {channel === 'email' ? 'με email' : 'με τηλέφωνο'}
                {preview.total !== preview.eligible && <span style={{ fontWeight: 400, color: 'var(--text-3)' }}> ({preview.total} σύνολο)</span>}
              </span>
            </div>
          )}

          {channel === 'email' && (
            <div className="form-group">
              <label className="form-label">Θέμα email</label>
              <input className="form-input" placeholder="π.χ. Νέες ώρες, Προσφορά Σεπτεμβρίου…" value={subject} onChange={e => setSubject(e.target.value)} />
            </div>
          )}

          <div className="form-group">
            <label className="form-label" style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span>Μήνυμα</span>
              {channel === 'sms' && (
                <span style={{ fontSize: '0.75rem', color: smsChars > 160 ? '#d97706' : 'var(--text-3)' }}>
                  {smsChars} χαρ. · {smsParts} SMS
                </span>
              )}
            </label>
            <textarea
              className="form-input"
              rows={channel === 'email' ? 8 : 5}
              placeholder={channel === 'sms'
                ? 'Γράψτε το SMS σας (160 χαρακτήρες = 1 SMS)…'
                : 'Γράψτε το κείμενο του email σας…'}
              value={body}
              onChange={e => setBody(e.target.value)}
              style={{ resize: 'vertical', fontFamily: 'inherit' }}
            />
            {channel === 'email' && (
              <div className="text-muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>Μπορείτε να χρησιμοποιήσετε αλλαγές γραμμής. Το κείμενο θα σταλεί ως HTML email.</div>
            )}
          </div>

          {!confirm ? (
            <button
              className="btn btn-primary"
              style={{ width: '100%', padding: '12px' }}
              disabled={!body.trim() || (channel === 'email' && !subject.trim()) || !preview?.eligible}
              onClick={() => setConfirm(true)}
            >
              <Send size={15} /> Επόμενο →
            </button>
          ) : (
            <div style={{ background: '#fef2f2', border: '1px solid #fecaca', borderRadius: 12, padding: 16 }}>
              <div style={{ fontWeight: 700, color: '#dc2626', marginBottom: 8 }}>
                ⚠ Θα σταλεί σε {preview?.eligible} παραλήπτες. Επιβεβαίωση;
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button className="btn btn-sm" style={{ background: '#dc2626', color: '#fff', border: 'none', flex: 1, padding: '10px' }} onClick={send} disabled={sending}>
                  {sending ? 'Αποστολή…' : `✓ Αποστολή σε ${preview?.eligible} παραλήπτες`}
                </button>
                <button className="btn btn-secondary btn-sm" onClick={() => setConfirm(false)}>Ακύρωση</button>
              </div>
            </div>
          )}
        </div>

        {/* History */}
        <div className="card">
          <div style={{ fontWeight: 700, marginBottom: 16 }}>Ιστορικό</div>
          {loading ? <div className="text-muted">Φόρτωση…</div> : campaigns.length === 0 ? (
            <div className="text-muted" style={{ textAlign: 'center', padding: '20px 0', fontSize: '0.85rem' }}>Δεν υπάρχουν καμπάνιες ακόμα</div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
              {campaigns.map(c => (
                <div key={c.id} style={{ padding: '12px', border: '1px solid var(--border)', borderRadius: 10 }}>
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 }}>
                    <span style={{ display: 'inline-flex', alignItems: 'center', gap: 5, fontSize: '0.78rem', fontWeight: 700, color: c.channel === 'email' ? '#2563eb' : '#7c3aed' }}>
                      {c.channel === 'email' ? <Mail size={12} /> : <MessageSquare size={12} />}
                      {c.channel === 'email' ? 'Email' : 'SMS'}
                    </span>
                    {c.status === 'done'
                      ? <span style={{ fontSize: '0.72rem', color: '#16a34a', display: 'flex', alignItems: 'center', gap: 3 }}><CheckCircle size={11} /> {c.sent_count}/{c.recipient_count}</span>
                      : <span style={{ fontSize: '0.72rem', color: '#d97706', display: 'flex', alignItems: 'center', gap: 3 }}><Clock size={11} /> {c.status}</span>
                    }
                  </div>
                  {c.subject && <div style={{ fontSize: '0.82rem', fontWeight: 600, marginBottom: 2 }}>{c.subject}</div>}
                  <div style={{ fontSize: '0.78rem', color: 'var(--text-2)', overflow: 'hidden', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>{c.body}</div>
                  <div style={{ fontSize: '0.72rem', color: 'var(--text-3)', marginTop: 4 }}>
                    {FILTERS.find(f => f.value === c.filter_type)?.label || c.filter_type} · {new Date(c.created_at).toLocaleDateString('el-GR')}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </div>
    </Layout>
  );
}
