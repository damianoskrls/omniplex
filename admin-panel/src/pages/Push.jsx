import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';

export default function Push() {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [everyone, setEveryone] = useState(true);
  const [q, setQ] = useState('');
  const [users, setUsers] = useState([]);
  const [picked, setPicked] = useState({});
  const [sending, setSending] = useState(false);

  useEffect(() => {
    if (everyone) return undefined;
    const t = setTimeout(() => {
      api.get('/tenants/global-users', { params: { q, limit: 30, page: 1 } })
        .then((r) => setUsers(r.data.rows || []))
        .catch(() => setUsers([]));
    }, 300);
    return () => clearTimeout(t);
  }, [q, everyone]);

  const send = async (e) => {
    e.preventDefault();
    const ids = Object.keys(picked).filter((id) => picked[id]);
    if (!everyone && !ids.length) {
      toast.error('Διάλεξε χρήστες ή στείλε σε όλους');
      return;
    }
    setSending(true);
    try {
      const { data } = await api.post('/tenants/push', {
        title: title.trim(),
        body: body.trim(),
        global_user_ids: everyone ? [] : ids,
      });
      toast.success(`Στάλθηκε σε ${data.users} χρήστες (${data.sent} συσκευές)`);
      setTitle('');
      setBody('');
    } catch (err) {
      toast.error(err.response?.data?.error || 'Αποτυχία αποστολής');
    } finally {
      setSending(false);
    }
  };

  return (
    <Layout title="Push">
      <h1 className="page-title">Push στους χρήστες OmniPlex</h1>
      <p className="text-muted" style={{ marginBottom: 16 }}>
        Φτάνει στην εφαρμογή και πριν μπει κάποιος σε γυμναστήριο, αρκεί να έχει συνδεθεί.
      </p>
      <form className="card" onSubmit={send} style={{ maxWidth: 640, display: 'grid', gap: 12 }}>
        <label>
          <div className="form-label">Τίτλος</div>
          <input className="form-input" value={title} onChange={(e) => setTitle(e.target.value)} required maxLength={120} />
        </label>
        <label>
          <div className="form-label">Κείμενο</div>
          <textarea className="form-input" rows={4} value={body} onChange={(e) => setBody(e.target.value)} required maxLength={500} />
        </label>
        <label style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <input type="checkbox" checked={everyone} onChange={(e) => setEveryone(e.target.checked)} />
          Σε όλους τους χρήστες
        </label>
        {!everyone && (
          <div>
            <input className="form-input" placeholder="Αναζήτηση ονόματος, email ή κινητού" value={q} onChange={(e) => setQ(e.target.value)} />
            <div style={{ marginTop: 8, maxHeight: 240, overflow: 'auto' }}>
              {users.map((u) => (
                <label key={u.id} style={{ display: 'flex', gap: 8, padding: '6px 0' }}>
                  <input
                    type="checkbox"
                    checked={!!picked[u.id]}
                    onChange={(e) => setPicked((p) => ({ ...p, [u.id]: e.target.checked }))}
                  />
                  <span>{u.full_name || 'Χωρίς όνομα'} · {u.phone || u.email || ''}</span>
                </label>
              ))}
            </div>
          </div>
        )}
        <button className="btn btn-primary" type="submit" disabled={sending}>
          {sending ? 'Αποστολή…' : 'Στείλε push'}
        </button>
      </form>
    </Layout>
  );
}
