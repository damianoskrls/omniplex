import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Link2, CheckCircle, Clock, Send, FileText, ChevronDown, ChevronUp, Copy } from 'lucide-react';

export default function Gdpr() {
  const [consents, setConsents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [clients, setClients] = useState([]);
  const [gdprText, setGdprText] = useState('');
  const [editingText, setEditingText] = useState(false);
  const [savingText, setSavingText] = useState(false);
  const [showSend, setShowSend] = useState(false);
  const [sending, setSending] = useState(false);
  const [form, setForm] = useState({ user_id: '', full_name: '', phone: '', email: '' });
  const [newLink, setNewLink] = useState('');
  const [clientSearch, setClientSearch] = useState('');

  useEffect(() => {
    load();
    api.get('/client-admin/clients').then(r => setClients(r.data || [])).catch(() => {});
    api.get('/gdpr/template').then(r => setGdprText(r.data.gdpr_text || '')).catch(() => {});
  }, []);

  async function load() {
    setLoading(true);
    try {
      const r = await api.get('/gdpr/consents');
      setConsents(r.data || []);
    } catch { toast.error('Σφάλμα φόρτωσης'); }
    finally { setLoading(false); }
  }

  async function saveText() {
    setSavingText(true);
    try {
      await api.put('/gdpr/template', { gdpr_text: gdprText });
      toast.success('Κείμενο αποθηκεύτηκε');
      setEditingText(false);
    } catch { toast.error('Σφάλμα'); }
    finally { setSavingText(false); }
  }

  function pickClient(c) {
    setForm({ user_id: c.id, full_name: c.full_name, phone: c.phone || '', email: c.email || '' });
    setClientSearch('');
  }

  async function sendConsent() {
    if (!form.full_name && !form.user_id) return toast.error('Εισάγετε όνομα πελάτη');
    setSending(true);
    try {
      const r = await api.post('/gdpr/consents', form);
      setNewLink(r.data.link);
      toast.success('Σύνδεσμος δημιουργήθηκε!');
      setForm({ user_id: '', full_name: '', phone: '', email: '' });
      load();
    } catch { toast.error('Σφάλμα'); }
    finally { setSending(false); }
  }

  const filteredClients = clients.filter(c =>
    clientSearch && c.full_name?.toLowerCase().includes(clientSearch.toLowerCase())
  ).slice(0, 6);

  const signed = consents.filter(c => c.signed_at).length;
  const pending = consents.filter(c => !c.signed_at).length;

  return (
    <Layout title="GDPR — Συναίνεση">
      {/* Stats */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
        {[
          { label: 'Υπογεγραμμένα', value: signed, color: '#16a34a', bg: '#f0fdf4' },
          { label: 'Εκκρεμή', value: pending, color: '#d97706', bg: '#fffbeb' },
          { label: 'Σύνολο', value: consents.length, color: 'var(--accent)', bg: 'var(--accent-dim)' },
        ].map(s => (
          <div key={s.label} className="card" style={{ background: s.bg, borderColor: 'transparent', minWidth: 120, textAlign: 'center', padding: '14px 20px' }}>
            <div style={{ fontSize: '1.6rem', fontWeight: 800, color: s.color }}>{s.value}</div>
            <div style={{ fontSize: '0.78rem', color: 'var(--text-3)', fontWeight: 600 }}>{s.label}</div>
          </div>
        ))}
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20, marginBottom: 24 }}>
        {/* Send new consent */}
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <div style={{ fontWeight: 700 }}>Αποστολή σε Πελάτη</div>
            <Send size={16} style={{ color: 'var(--accent)' }} />
          </div>

          <div style={{ position: 'relative', marginBottom: 10 }}>
            <input className="form-input" placeholder="Αναζήτηση πελάτη..." value={clientSearch}
              onChange={e => { setClientSearch(e.target.value); setForm(f => ({ ...f, user_id: '', full_name: e.target.value })); }} />
            {filteredClients.length > 0 && (
              <div style={{ position: 'absolute', top: '100%', left: 0, right: 0, background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 8, zIndex: 10 }}>
                {filteredClients.map(c => (
                  <button key={c.id} onClick={() => pickClient(c)} style={{ display: 'block', width: '100%', padding: '8px 12px', border: 'none', background: 'none', cursor: 'pointer', textAlign: 'left', fontSize: '0.84rem' }}>
                    {c.full_name} <span style={{ color: 'var(--text-3)', fontSize: '0.75rem' }}>{c.phone}</span>
                  </button>
                ))}
              </div>
            )}
          </div>

          <div style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
            <input className="form-input" placeholder="Email" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} style={{ flex: 1 }} />
            <input className="form-input" placeholder="Τηλέφωνο" value={form.phone} onChange={e => setForm(f => ({ ...f, phone: e.target.value }))} style={{ flex: 1 }} />
          </div>

          <button className="btn btn-primary btn-sm" style={{ width: '100%' }} onClick={sendConsent} disabled={sending}>
            {sending ? 'Δημιουργία…' : 'Δημιουργία Συνδέσμου'}
          </button>

          {newLink && (
            <div style={{ marginTop: 12, background: 'var(--surface-2)', borderRadius: 8, padding: '10px 12px', fontSize: '0.78rem', wordBreak: 'break-all' }}>
              <div style={{ fontWeight: 600, marginBottom: 4 }}>Σύνδεσμος GDPR:</div>
              <div style={{ color: 'var(--accent)', marginBottom: 8 }}>{newLink}</div>
              <button className="btn btn-secondary btn-sm" onClick={() => { navigator.clipboard.writeText(newLink); toast.success('Αντιγράφηκε!'); }}>
                <Copy size={12} /> Αντιγραφή
              </button>
            </div>
          )}
        </div>

        {/* Edit GDPR text */}
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 14 }}>
            <div style={{ fontWeight: 700 }}>Κείμενο GDPR</div>
            <FileText size={16} style={{ color: 'var(--accent)' }} />
          </div>
          {editingText ? (
            <>
              <textarea className="form-input" rows={8} value={gdprText} onChange={e => setGdprText(e.target.value)} style={{ fontFamily: 'inherit', fontSize: '0.8rem', resize: 'vertical' }} />
              <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                <button className="btn btn-primary btn-sm" onClick={saveText} disabled={savingText}>{savingText ? 'Αποθήκευση…' : 'Αποθήκευση'}</button>
                <button className="btn btn-secondary btn-sm" onClick={() => setEditingText(false)}>Ακύρωση</button>
              </div>
            </>
          ) : (
            <>
              <div style={{ fontSize: '0.8rem', color: 'var(--text-2)', maxHeight: 140, overflow: 'hidden', whiteSpace: 'pre-wrap', lineHeight: 1.5 }}>
                {gdprText.slice(0, 300)}{gdprText.length > 300 ? '…' : ''}
              </div>
              <button className="btn btn-secondary btn-sm" style={{ marginTop: 12 }} onClick={() => setEditingText(true)}>Επεξεργασία κειμένου</button>
            </>
          )}
        </div>
      </div>

      {/* Consents list */}
      <div className="card">
        <div style={{ fontWeight: 700, marginBottom: 14 }}>Ιστορικό Συναινέσεων</div>
        {loading ? <div className="text-muted">Φόρτωση…</div> : consents.length === 0 ? (
          <div className="text-muted" style={{ textAlign: 'center', padding: '24px 0' }}>Δεν υπάρχουν ακόμα GDPR φόρμες</div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.84rem' }}>
              <thead>
                <tr style={{ borderBottom: '1px solid var(--border)' }}>
                  {['Πελάτης', 'Τηλέφωνο', 'Email', 'Αποστολή', 'Υπογραφή', 'Κατάσταση'].map(h => (
                    <th key={h} style={{ padding: '8px 10px', textAlign: 'left', color: 'var(--text-3)', fontWeight: 600, fontSize: '0.75rem' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {consents.map(c => (
                  <tr key={c.id} style={{ borderBottom: '1px solid var(--border)' }}>
                    <td style={{ padding: '10px' }}>{c.full_name || c.linked_client || '—'}</td>
                    <td style={{ padding: '10px', color: 'var(--text-2)' }}>{c.phone || '—'}</td>
                    <td style={{ padding: '10px', color: 'var(--text-2)' }}>{c.email || '—'}</td>
                    <td style={{ padding: '10px', color: 'var(--text-3)', fontSize: '0.78rem' }}>{new Date(c.created_at).toLocaleDateString('el-GR')}</td>
                    <td style={{ padding: '10px', color: 'var(--text-3)', fontSize: '0.78rem' }}>
                      {c.signed_at ? new Date(c.signed_at).toLocaleDateString('el-GR') : '—'}
                    </td>
                    <td style={{ padding: '10px' }}>
                      {c.signed_at ? (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: '#16a34a', fontSize: '0.78rem', fontWeight: 600 }}>
                          <CheckCircle size={13} /> Υπογεγραμμένο
                        </span>
                      ) : (
                        <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, color: '#d97706', fontSize: '0.78rem', fontWeight: 600 }}>
                          <Clock size={13} /> Εκκρεμεί
                        </span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </Layout>
  );
}
