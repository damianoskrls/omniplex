import { useCallback, useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { AlertTriangle, Send, RefreshCw, UserCheck, Settings, X } from 'lucide-react';

export default function AtRisk() {
  const biz = JSON.parse(localStorage.getItem('gym_admin_business') || '{}');
  const bizId = biz.id;

  const [members, setMembers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [days, setDays] = useState(14);
  const [selected, setSelected] = useState(new Set());
  const [template, setTemplate] = useState('');
  const [sending, setSending] = useState(false);
  const [showConfig, setShowConfig] = useState(false);
  const [savingCfg, setSavingCfg] = useState(false);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const r = await api.get(`/business/${bizId}/at-risk`, { params: { days } });
      setMembers(r.data.members || []);
    } catch { toast.error('Σφάλμα φόρτωσης'); }
    finally { setLoading(false); }
  }, [bizId, days]);

  useEffect(() => { load(); }, [load]);

  useEffect(() => {
    api.get(`/business/${bizId}/at-risk/config`).then(r => {
      setTemplate(r.data.at_risk_template || '');
      setDays(r.data.at_risk_days || 14);
    }).catch(() => {});
  }, [bizId]);

  const toggleAll = () =>
    selected.size === members.length
      ? setSelected(new Set())
      : setSelected(new Set(members.map(m => m.user_id)));

  const toggle = id => {
    const s = new Set(selected);
    s.has(id) ? s.delete(id) : s.add(id);
    setSelected(s);
  };

  const send = async () => {
    if (!selected.size) return toast.error('Επίλεξε τουλάχιστον ένα μέλος');
    if (!template.trim()) return toast.error('Γράψε το template μηνύματος');
    setSending(true);
    try {
      const r = await api.post(`/business/${bizId}/at-risk/message`, {
        user_ids: [...selected], template,
      });
      toast.success(`Στάλθηκε σε ${r.data.sent} μέλη`);
      setSelected(new Set());
    } catch (e) { toast.error(e.response?.data?.error || 'Σφάλμα αποστολής'); }
    finally { setSending(false); }
  };

  const saveConfig = async () => {
    setSavingCfg(true);
    try {
      await api.patch(`/business/${bizId}/at-risk/config`, {
        at_risk_days: Number(days), at_risk_template: template,
      });
      toast.success('Αποθηκεύτηκε');
      setShowConfig(false);
    } catch { toast.error('Σφάλμα αποθήκευσης'); }
    finally { setSavingCfg(false); }
  };

  return (
    <Layout>
      {/* Header */}
      <div className="page-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{
            width: 44, height: 44, borderRadius: 14,
            background: 'linear-gradient(135deg,#fff7ed,#fed7aa)',
            border: '1px solid #fed7aa',
            display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#ea580c',
          }}>
            <AlertTriangle size={22} />
          </div>
          <div>
            <h1 className="page-title">Μέλη σε Κίνδυνο</h1>
            <div className="text-muted" style={{ marginTop: 2 }}>Ανενεργά μέλη τις τελευταίες {days} μέρες</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn btn-secondary" onClick={() => setShowConfig(!showConfig)}>
            <Settings size={15} /> Ρυθμίσεις
          </button>
          <button className="btn btn-secondary" onClick={load}>
            <RefreshCw size={15} className={loading ? 'spin' : ''} />
          </button>
        </div>
      </div>

      {/* Config panel */}
      {showConfig && (
        <div className="card" style={{ marginBottom: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
            <span style={{ fontWeight: 700 }}>Ρυθμίσεις</span>
            <button className="btn btn-secondary btn-sm" onClick={() => setShowConfig(false)}><X size={14} /></button>
          </div>
          <div className="form-grid-2">
            <div className="form-group">
              <label className="form-label">Ημέρες ανενεργίας</label>
              <input type="number" min={1} max={365} className="form-input"
                value={days} onChange={e => setDays(e.target.value)} />
            </div>
          </div>
          <div className="form-group">
            <label className="form-label">Template μηνύματος <span className="text-muted">(χρησιμοποίησε {'{name}'} για το όνομα)</span></label>
            <textarea className="form-input" rows={3}
              placeholder="Γεια {name}! Σε σκεφτόμαστε..."
              value={template} onChange={e => setTemplate(e.target.value)} />
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button className="btn btn-primary" onClick={saveConfig} disabled={savingCfg}>Αποθήκευση</button>
            <button className="btn btn-secondary" onClick={() => setShowConfig(false)}>Άκυρο</button>
          </div>
        </div>
      )}

      {/* Send panel */}
      {selected.size > 0 && (
        <div className="card" style={{ marginBottom: 20, borderColor: 'var(--hs-primary)', borderWidth: 2 }}>
          <div style={{ display: 'flex', gap: 12, alignItems: 'flex-end' }}>
            <div className="form-group" style={{ flex: 1, margin: 0 }}>
              <label className="form-label">Μήνυμα προς {selected.size} επιλεγμένα μέλη</label>
              <textarea className="form-input" rows={2}
                placeholder="Γεια {name}! Σε σκεφτόμαστε..."
                value={template} onChange={e => setTemplate(e.target.value)} />
            </div>
            <button className="btn btn-primary" onClick={send} disabled={sending} style={{ height: 42, flexShrink: 0 }}>
              <Send size={15} /> {sending ? 'Αποστολή…' : 'Αποστολή'}
            </button>
          </div>
        </div>
      )}

      {/* Table */}
      {loading ? (
        <div className="loading">Φόρτωση…</div>
      ) : members.length === 0 ? (
        <div className="bk-empty">
          <UserCheck size={48} style={{ margin: '0 auto 12px', display: 'block', color: '#94a3b8' }} />
          <div style={{ fontWeight: 700, fontSize: '1rem', color: '#1e293b' }}>Κανένα ανενεργό μέλος</div>
          <div className="text-muted" style={{ marginTop: 4 }}>Δεν υπάρχουν ανενεργά μέλη τις τελευταίες {days} μέρες 🎉</div>
        </div>
      ) : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <div style={{ overflowX: 'auto' }}>
            <table>
              <thead>
                <tr>
                  <th style={{ width: 40 }}>
                    <input type="checkbox"
                      onChange={toggleAll}
                      checked={selected.size === members.length && members.length > 0}
                      style={{ accentColor: 'var(--hs-primary)' }} />
                  </th>
                  <th>Μέλος</th>
                  <th>Τελ. δραστηριότητα</th>
                  <th>Ανενεργό</th>
                  <th>Συνήθης συχνότητα</th>
                  <th>Τηλέφωνο</th>
                </tr>
              </thead>
              <tbody>
                {members.map(m => (
                  <tr key={m.user_id} style={selected.has(m.user_id) ? { background: 'rgba(118,192,67,0.06)' } : {}}>
                    <td>
                      <input type="checkbox"
                        checked={selected.has(m.user_id)}
                        onChange={() => toggle(m.user_id)}
                        style={{ accentColor: 'var(--hs-primary)' }} />
                    </td>
                    <td><strong>{m.full_name}</strong></td>
                    <td className="text-muted">
                      {m.last_activity ? new Date(m.last_activity).toLocaleDateString('el-GR') : '—'}
                    </td>
                    <td>
                      {m.days_inactive == null
                        ? <span className="badge badge-gray">Ποτέ</span>
                        : m.days_inactive > 30
                          ? <span className="badge badge-red">{m.days_inactive}μ</span>
                          : <span className="badge badge-yellow">{m.days_inactive}μ</span>}
                    </td>
                    <td className="text-muted">{m.usual_per_week ? `${m.usual_per_week}× / εβδ.` : '—'}</td>
                    <td className="text-muted">{m.phone || '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </Layout>
  );
}
