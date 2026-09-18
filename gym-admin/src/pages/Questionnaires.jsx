import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Plus, Send, Eye, Trash2, ChevronDown, ChevronUp, CheckCircle, Clock, X } from 'lucide-react';

const QUESTION_TYPES = [
  { value: 'text', label: 'Ελεύθερο κείμενο' },
  { value: 'scale', label: 'Κλίμακα 1–10' },
  { value: 'choice', label: 'Επιλογή' },
  { value: 'yesno', label: 'Ναι / Όχι' },
];

const BASE_URL = window.location.origin;

export default function Questionnaires() {
  const [templates, setTemplates] = useState([]);
  const [responses, setResponses] = useState([]);
  const [tab, setTab] = useState('templates'); // templates | responses
  const [editing, setEditing] = useState(null); // null | {} | template obj
  const [sending, setSending] = useState(null); // template being sent
  const [clientSearch, setClientSearch] = useState('');
  const [clientResults, setClientResults] = useState([]);
  const [selectedClient, setSelectedClient] = useState(null);
  const [sendLink, setSendLink] = useState(null);
  const [detailResponse, setDetailResponse] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => { load(); }, [tab]);

  async function load() {
    setLoading(true);
    try {
      if (tab === 'templates') {
        const r = await api.get('/questionnaires/templates');
        setTemplates(r.data);
      } else {
        const r = await api.get('/questionnaires/responses');
        setResponses(r.data);
      }
    } catch { toast.error('Σφάλμα φόρτωσης'); }
    finally { setLoading(false); }
  }

  // Client search debounce
  useEffect(() => {
    if (!clientSearch.trim()) { setClientResults([]); return; }
    const t = setTimeout(async () => {
      try {
        const r = await api.get(`/client-admin/search?q=${encodeURIComponent(clientSearch)}`);
        setClientResults(r.data || []);
      } catch {}
    }, 280);
    return () => clearTimeout(t);
  }, [clientSearch]);

  async function sendTo() {
    if (!selectedClient || !sending) return;
    try {
      const r = await api.post(`/questionnaires/templates/${sending.id}/send`, { user_id: selectedClient.id });
      const link = `${BASE_URL}/q/${r.data.token}`;
      setSendLink(link);
      toast.success('Εστάλη!');
    } catch { toast.error('Σφάλμα αποστολής'); }
  }

  function newTemplate() {
    setEditing({
      title: '',
      description: '',
      questions: [
        { id: 'q1', type: 'text', label: '' },
      ],
    });
  }

  function addQuestion(ed) {
    setEditing({ ...ed, questions: [...ed.questions, { id: `q${Date.now()}`, type: 'text', label: '', options: [] }] });
  }

  function removeQuestion(ed, idx) {
    const qs = ed.questions.filter((_, i) => i !== idx);
    setEditing({ ...ed, questions: qs });
  }

  function updateQuestion(ed, idx, patch) {
    const qs = ed.questions.map((q, i) => i === idx ? { ...q, ...patch } : q);
    setEditing({ ...ed, questions: qs });
  }

  async function saveTemplate() {
    if (!editing.title.trim()) return toast.error('Γράψε τίτλο');
    if (!editing.questions.some(q => q.label.trim())) return toast.error('Πρόσθεσε τουλάχιστον μία ερώτηση');
    try {
      if (editing.id) {
        await api.put(`/questionnaires/templates/${editing.id}`, editing);
        toast.success('Αποθηκεύτηκε');
      } else {
        await api.post('/questionnaires/templates', editing);
        toast.success('Δημιουργήθηκε!');
      }
      setEditing(null);
      load();
    } catch { toast.error('Σφάλμα αποθήκευσης'); }
  }

  async function deleteTemplate(id) {
    if (!confirm('Διαγραφή ερωτηματολογίου;')) return;
    try {
      await api.delete(`/questionnaires/templates/${id}`);
      toast.success('Διαγράφηκε');
      load();
    } catch { toast.error('Σφάλμα'); }
  }

  async function loadDetail(r) {
    try {
      const res = await api.get(`/questionnaires/responses/${r.id}`);
      setDetailResponse(res.data);
    } catch { toast.error('Σφάλμα'); }
  }

  return (
    <Layout title="Ψηφιακά Ερωτηματολόγια">
      {/* Tab bar */}
      <div style={{ display: 'flex', gap: 8, marginBottom: 20 }}>
        {[['templates', 'Φόρμες'], ['responses', 'Απαντήσεις']].map(([k, l]) => (
          <button key={k} onClick={() => setTab(k)} style={{
            padding: '8px 18px', borderRadius: 10, border: `2px solid ${tab === k ? 'var(--accent)' : 'var(--border)'}`,
            background: tab === k ? 'var(--accent-dim)' : 'var(--surface)',
            color: tab === k ? 'var(--accent)' : 'var(--text-2)', fontWeight: 700, fontSize: '0.85rem', cursor: 'pointer',
          }}>{l}</button>
        ))}
        {tab === 'templates' && (
          <button className="btn btn-primary" style={{ marginLeft: 'auto' }} onClick={newTemplate}>
            <Plus size={15} /> Νέο Ερωτηματολόγιο
          </button>
        )}
      </div>

      {/* Templates list */}
      {tab === 'templates' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {loading ? <div className="text-muted">Φόρτωση…</div> : templates.length === 0 ? (
            <div className="card" style={{ textAlign: 'center', padding: 40, color: 'var(--text-3)' }}>
              Δεν υπάρχουν ερωτηματολόγια ακόμα. Δημιούργησε το πρώτο!
            </div>
          ) : templates.map(t => (
            <div key={t.id} className="card" style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{t.title}</div>
                {t.description && <div style={{ fontSize: '0.82rem', color: 'var(--text-2)', marginTop: 2 }}>{t.description}</div>}
                <div style={{ fontSize: '0.75rem', color: 'var(--text-3)', marginTop: 4 }}>{t.questions.length} ερωτήσεις</div>
              </div>
              <div style={{ display: 'flex', gap: 8 }}>
                <button className="btn btn-secondary btn-sm" onClick={() => { setSending(t); setSelectedClient(null); setClientSearch(''); setSendLink(null); }}>
                  <Send size={13} /> Αποστολή
                </button>
                <button className="btn btn-secondary btn-sm" onClick={() => setEditing({ ...t })}>Επεξεργασία</button>
                <button className="btn btn-sm" style={{ background: '#fee2e2', color: '#dc2626', border: 'none' }} onClick={() => deleteTemplate(t.id)}>
                  <Trash2 size={13} />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Responses list */}
      {tab === 'responses' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {loading ? <div className="text-muted">Φόρτωση…</div> : responses.length === 0 ? (
            <div className="card" style={{ textAlign: 'center', padding: 40, color: 'var(--text-3)' }}>Δεν υπάρχουν απαντήσεις ακόμα</div>
          ) : responses.map(r => (
            <div key={r.id} className="card" style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>{r.full_name || '—'}</div>
                <div style={{ fontSize: '0.78rem', color: 'var(--text-2)', marginTop: 2 }}>{r.template_title}</div>
                <div style={{ fontSize: '0.73rem', color: 'var(--text-3)', marginTop: 2 }}>
                  {new Date(r.created_at).toLocaleDateString('el-GR')}
                </div>
              </div>
              <span style={{
                fontSize: '0.75rem', fontWeight: 700, padding: '3px 10px', borderRadius: 999,
                background: r.status === 'completed' ? '#dcfce7' : '#fef9c3',
                color: r.status === 'completed' ? '#16a34a' : '#ca8a04',
                display: 'flex', alignItems: 'center', gap: 4,
              }}>
                {r.status === 'completed' ? <><CheckCircle size={11} /> Συμπληρώθηκε</> : <><Clock size={11} /> Εκκρεμεί</>}
              </span>
              {r.status === 'completed' && (
                <button className="btn btn-secondary btn-sm" onClick={() => loadDetail(r)}><Eye size={13} /> Προβολή</button>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Edit / Create modal */}
      {editing && (
        <div className="modal-backdrop" onClick={() => setEditing(null)}>
          <div className="modal" style={{ maxWidth: 640, width: '100%' }} onClick={e => e.stopPropagation()}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
              <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700 }}>{editing.id ? 'Επεξεργασία' : 'Νέο Ερωτηματολόγιο'}</h3>
              <button className="btn btn-sm btn-secondary" onClick={() => setEditing(null)}><X size={14} /></button>
            </div>
            <div className="form-group">
              <label className="form-label">Τίτλος *</label>
              <input className="form-input" placeholder="π.χ. Αρχική Αξιολόγηση PAR-Q" value={editing.title} onChange={e => setEditing({ ...editing, title: e.target.value })} />
            </div>
            <div className="form-group">
              <label className="form-label">Περιγραφή</label>
              <input className="form-input" placeholder="Προαιρετική οδηγία για τον πελάτη" value={editing.description} onChange={e => setEditing({ ...editing, description: e.target.value })} />
            </div>
            <div style={{ fontWeight: 700, fontSize: '0.85rem', marginBottom: 10, marginTop: 4 }}>Ερωτήσεις</div>
            {editing.questions.map((q, i) => (
              <div key={q.id} style={{ background: 'var(--surface-2)', borderRadius: 10, padding: 12, marginBottom: 8 }}>
                <div style={{ display: 'flex', gap: 8, alignItems: 'flex-start' }}>
                  <div style={{ flex: 1 }}>
                    <input className="form-input" placeholder={`Ερώτηση ${i + 1}`} value={q.label} onChange={e => updateQuestion(editing, i, { label: e.target.value })} style={{ marginBottom: 6 }} />
                    <select className="form-input" value={q.type} onChange={e => updateQuestion(editing, i, { type: e.target.value })}>
                      {QUESTION_TYPES.map(t => <option key={t.value} value={t.value}>{t.label}</option>)}
                    </select>
                    {q.type === 'choice' && (
                      <input className="form-input" style={{ marginTop: 6, fontSize: '0.82rem' }}
                        placeholder="Επιλογές χωρισμένες με κόμμα (π.χ. 1-2,3-4,5+)"
                        value={(q.options || []).join(',')}
                        onChange={e => updateQuestion(editing, i, { options: e.target.value.split(',').map(s => s.trim()) })}
                      />
                    )}
                  </div>
                  <button type="button" onClick={() => removeQuestion(editing, i)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: 'var(--text-3)', padding: 4 }}>
                    <X size={14} />
                  </button>
                </div>
              </div>
            ))}
            <button className="btn btn-secondary btn-sm" style={{ marginBottom: 20 }} onClick={() => addQuestion(editing)}>
              <Plus size={13} /> Προσθήκη ερώτησης
            </button>
            <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
              <button className="btn btn-secondary" onClick={() => setEditing(null)}>Ακύρωση</button>
              <button className="btn btn-primary" onClick={saveTemplate}>Αποθήκευση</button>
            </div>
          </div>
        </div>
      )}

      {/* Send modal */}
      {sending && (
        <div className="modal-backdrop" onClick={() => { setSending(null); setSendLink(null); }}>
          <div className="modal" style={{ maxWidth: 420 }} onClick={e => e.stopPropagation()}>
            <div style={{ fontWeight: 700, fontSize: '1rem', marginBottom: 16 }}>
              Αποστολή: {sending.title}
            </div>
            {!sendLink ? (<>
              <div className="form-group">
                <label className="form-label">Αναζήτηση πελάτη</label>
                <input className="form-input" placeholder="Όνομα ή τηλέφωνο…" value={clientSearch} onChange={e => { setClientSearch(e.target.value); setSelectedClient(null); }} autoFocus />
              </div>
              {clientResults.length > 0 && (
                <div style={{ border: '1px solid var(--border)', borderRadius: 10, overflow: 'hidden', marginBottom: 12 }}>
                  {clientResults.map(c => (
                    <button key={c.id} type="button" onClick={() => { setSelectedClient(c); setClientSearch(c.full_name); setClientResults([]); }}
                      style={{ display: 'flex', alignItems: 'center', gap: 10, width: '100%', padding: '9px 12px', border: 'none', background: selectedClient?.id === c.id ? 'var(--accent-dim)' : 'var(--surface)', cursor: 'pointer', textAlign: 'left', fontFamily: 'inherit' }}>
                      <div style={{ flex: 1 }}>
                        <div style={{ fontSize: '0.85rem', fontWeight: 600, color: 'var(--text)' }}>{c.full_name}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--text-3)' }}>{c.phone || c.email}</div>
                      </div>
                    </button>
                  ))}
                </div>
              )}
              <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                <button className="btn btn-secondary" onClick={() => { setSending(null); setSendLink(null); }}>Ακύρωση</button>
                <button className="btn btn-primary" disabled={!selectedClient} onClick={sendTo}>
                  <Send size={14} /> Αποστολή link
                </button>
              </div>
            </>) : (
              <div>
                <div style={{ marginBottom: 12, fontSize: '0.85rem', color: 'var(--text-2)' }}>
                  Αντέγραψε τον σύνδεσμο και στείλε τον στον πελάτη:
                </div>
                <div style={{ background: 'var(--surface-2)', border: '1px solid var(--border)', borderRadius: 10, padding: '10px 14px', fontSize: '0.82rem', wordBreak: 'break-all', marginBottom: 16 }}>
                  {sendLink}
                </div>
                <div style={{ display: 'flex', gap: 8 }}>
                  <button className="btn btn-primary" style={{ flex: 1 }} onClick={() => { navigator.clipboard.writeText(sendLink); toast.success('Αντιγράφηκε!'); }}>
                    Αντιγραφή
                  </button>
                  <button className="btn btn-secondary" onClick={() => { setSending(null); setSendLink(null); }}>Κλείσιμο</button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Response detail modal */}
      {detailResponse && (
        <div className="modal-backdrop" onClick={() => setDetailResponse(null)}>
          <div className="modal" style={{ maxWidth: 560 }} onClick={e => e.stopPropagation()}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{detailResponse.full_name}</div>
                <div style={{ fontSize: '0.8rem', color: 'var(--text-3)' }}>{detailResponse.template_title}</div>
              </div>
              <button className="btn btn-sm btn-secondary" onClick={() => setDetailResponse(null)}><X size={14} /></button>
            </div>
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {detailResponse.questions.map((q, i) => {
                const ans = detailResponse.answers?.[q.id];
                return (
                  <div key={q.id} style={{ background: 'var(--surface-2)', borderRadius: 10, padding: '10px 14px' }}>
                    <div style={{ fontSize: '0.78rem', color: 'var(--text-3)', marginBottom: 4 }}>Ερώτηση {i + 1}</div>
                    <div style={{ fontWeight: 600, fontSize: '0.88rem', marginBottom: 6 }}>{q.label}</div>
                    <div style={{ fontSize: '0.88rem', color: 'var(--accent)' }}>{ans ?? <span style={{ color: 'var(--text-3)' }}>—</span>}</div>
                  </div>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </Layout>
  );
}
