import { useState } from 'react';
import Layout from '../components/Layout';
import { Download, Users, Calendar, CreditCard, Receipt } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const API = import.meta.env.VITE_API_URL || 'https://passionate-grace-production-98ad.up.railway.app/api';

export default function Export() {
  const { token } = useAuth();
  const [loading, setLoading] = useState({});
  const [bookFrom, setBookFrom] = useState('');
  const [bookTo, setBookTo] = useState('');
  const [expYear, setExpYear] = useState(new Date().getFullYear());
  const [expMonth, setExpMonth] = useState('');

  async function download(path, filename) {
    setLoading(l => ({ ...l, [filename]: true }));
    try {
      const res = await fetch(`${API}/export/${path}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error('Σφάλμα λήψης');
      const blob = await res.blob();
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = filename; a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      alert(e.message);
    } finally {
      setLoading(l => ({ ...l, [filename]: false }));
    }
  }

  const inp = { className: 'form-input', style: { maxWidth: 160 } };

  return (
    <Layout title="Εξαγωγή Δεδομένων">
      <div style={{ maxWidth: 680 }}>
        <p className="text-muted" style={{ marginBottom: 28, fontSize: '0.88rem' }}>
          Κατεβάστε τα δεδομένα σε μορφή CSV που ανοίγει απευθείας στο Excel (UTF-8).
        </p>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>

          {/* Clients */}
          <ExportCard
            icon={<Users size={20} />}
            title="Πελάτες"
            desc="Ονοματεπώνυμο, email, τηλέφωνο, κατάσταση, κρατήσεις, πακέτα, πόντοι"
            action={
              <DownloadBtn
                loading={loading['pelates.csv']}
                onClick={() => download('clients', 'pelates.csv')}
              />
            }
          />

          {/* Bookings */}
          <ExportCard
            icon={<Calendar size={20} />}
            title="Κρατήσεις"
            desc="Ημερομηνία, πελάτης, υπηρεσία, συνεργάτης, κατάσταση, σημειώσεις"
            action={
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                <input {...inp} type="date" value={bookFrom} onChange={e => setBookFrom(e.target.value)} placeholder="Από" />
                <input {...inp} type="date" value={bookTo}   onChange={e => setBookTo(e.target.value)}   placeholder="Έως" />
                <DownloadBtn
                  loading={loading['kratiseis.csv']}
                  onClick={() => {
                    const qs = [bookFrom && `from=${bookFrom}`, bookTo && `to=${bookTo}`].filter(Boolean).join('&');
                    download(`bookings${qs ? '?' + qs : ''}`, 'kratiseis.csv');
                  }}
                />
              </div>
            }
          />

          {/* Memberships */}
          <ExportCard
            icon={<CreditCard size={20} />}
            title="Συνδρομές / Πακέτα"
            desc="Πελάτης, υπηρεσία, πακέτο, κατάσταση, συνεδρίες, ισχύς, τιμή"
            action={
              <DownloadBtn
                loading={loading['syndromites.csv']}
                onClick={() => download('memberships', 'syndromites.csv')}
              />
            }
          />

          {/* Expenses */}
          <ExportCard
            icon={<Receipt size={20} />}
            title="Γενικά Έξοδα"
            desc="Χρόνος, μήνας, κατηγορία, περιγραφή, ποσό"
            action={
              <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                <input {...inp} type="number" value={expYear} onChange={e => setExpYear(e.target.value)} placeholder="Χρόνος" min="2020" max="2099" />
                <select {...inp} value={expMonth} onChange={e => setExpMonth(e.target.value)}>
                  <option value="">Όλοι οι μήνες</option>
                  {['Ιαν','Φεβ','Μαρ','Απρ','Μαϊ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'].map((m,i) => (
                    <option key={i+1} value={i+1}>{m}</option>
                  ))}
                </select>
                <DownloadBtn
                  loading={loading['eksoda.csv']}
                  onClick={() => {
                    const qs = [`year=${expYear}`, expMonth && `month=${expMonth}`].filter(Boolean).join('&');
                    download(`expenses?${qs}`, 'eksoda.csv');
                  }}
                />
              </div>
            }
          />

        </div>
      </div>
    </Layout>
  );
}

function ExportCard({ icon, title, desc, action }) {
  return (
    <div className="card" style={{ display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
      <div style={{ color: 'var(--accent)', flexShrink: 0 }}>{icon}</div>
      <div style={{ flex: 1, minWidth: 180 }}>
        <div style={{ fontWeight: 700, fontSize: '0.9rem', marginBottom: 2 }}>{title}</div>
        <div className="text-muted" style={{ fontSize: '0.78rem' }}>{desc}</div>
      </div>
      <div style={{ flexShrink: 0 }}>{action}</div>
    </div>
  );
}

function DownloadBtn({ loading, onClick }) {
  return (
    <button
      onClick={onClick}
      disabled={loading}
      className="btn btn-secondary btn-sm"
      style={{ display: 'flex', alignItems: 'center', gap: 6, minWidth: 120 }}
    >
      <Download size={14} />
      {loading ? 'Φόρτωση…' : 'Λήψη CSV'}
    </button>
  );
}
