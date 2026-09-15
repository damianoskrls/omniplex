import { useEffect, useState } from 'react';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { Plus, Trash2 } from 'lucide-react';

const WEEKDAYS = [
  { v: 0, label: 'Δευ' }, { v: 1, label: 'Τρί' }, { v: 2, label: 'Τετ' },
  { v: 3, label: 'Πέμ' }, { v: 4, label: 'Παρ' }, { v: 5, label: 'Σαβ' }, { v: 6, label: 'Κυρ' },
];
const TIMES = ['09:00', '10:00', '11:00', '12:00', '13:00', '17:00', '18:00', '19:00', '20:00'];

function Chip({ label, checked, onClick }) {
  return (
    <button type="button" onClick={onClick} style={{
      padding: '5px 13px', borderRadius: 20,
      border: `1.5px solid ${checked ? '#0d9488' : '#e2e8f0'}`,
      background: checked ? '#ecfdf5' : '#fff',
      color: checked ? '#0f766e' : '#64748b',
      fontWeight: checked ? 600 : 400, fontSize: '0.85rem', cursor: 'pointer',
    }}>{label}</button>
  );
}

import { useAuth } from '../context/AuthContext';

export default function NutritionSchedule() {
  const { isOwner } = useAuth();
  const [setup, setSetup] = useState(null);
  const [schedules, setSchedules] = useState([]);
  const [weekdays, setWeekdays] = useState([]);
  const [times, setTimes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedNutritionistId, setSelectedNutritionistId] = useState('');

  const load = async (nutritionistId = selectedNutritionistId) => {
    const params = nutritionistId ? { nutritionist_id: nutritionistId } : {};
    const [setupRes, schRes] = await Promise.all([
      api.get('/client-admin/nutrition/consultation/setup', { params }),
      api.get('/client-admin/nutrition/consultation/slot-schedules', { params }),
    ]);
    setSetup(setupRes.data);
    setSchedules(schRes.data);
    if (!selectedNutritionistId && setupRes.data?.selected_nutritionist_id) {
      setSelectedNutritionistId(setupRes.data.selected_nutritionist_id);
    }
  };

  useEffect(() => {
    setLoading(true);
    load().catch(() => toast.error('Σφάλμα φόρτωσης')).finally(() => setLoading(false));
  }, []);

  useEffect(() => {
    if (!selectedNutritionistId) return;
    load(selectedNutritionistId).catch(() => toast.error('Σφάλμα φόρτωσης'));
  }, [selectedNutritionistId]);

  const toggle = (list, setList, value) => {
    setList(list.includes(value) ? list.filter(v => v !== value) : [...list, value]);
  };

  const save = async () => {
    if (!weekdays.length || !times.length) {
      toast.error('Επίλεξε τουλάχιστον μία ημέρα και μία ώρα');
      return;
    }
    try {
      await api.post('/client-admin/nutrition/consultation/slot-schedules', {
        weekdays,
        start_times: times,
        nutritionist_id: selectedNutritionistId || setup?.selected_nutritionist_id,
      });
      toast.success('Το ωράριο αποθηκεύτηκε');
      setWeekdays([]);
      setTimes([]);
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const remove = async (id) => {
    await api.delete(`/client-admin/nutrition/consultation/slot-schedules/${id}`);
    toast.success('Διαγράφηκε');
    load();
  };

  if (loading) return <Layout title="Ωράριο διατροφολόγου" variant="nutrition"><div className="loading">Φόρτωση...</div></Layout>;

  return (
    <Layout title="Ωράριο διατροφολόγου" variant="nutrition">
      <div className="page-header">
        <div>
          <h1 className="page-title">Ωράριο επισκέψεων</h1>
          <p className="text-muted" style={{ margin: '6px 0 0' }}>
            {setup?.ready
              ? `Διαθέσιμες ώρες για ${setup.nutritionist?.full_name || 'διατροφολόγο'}`
              : 'Ορίστε πρώτα διατροφολόγο'}
          </p>
        </div>
      </div>

      {setup?.nutritionists?.length > 1 && isOwner && (
        <div className="card" style={{ marginBottom: 16 }}>
          <label className="form-label">Διατροφολόγος</label>
          <select
            className="form-input"
            value={selectedNutritionistId}
            onChange={e => setSelectedNutritionistId(e.target.value)}
          >
            {setup.nutritionists.map(n => (
              <option key={n.id} value={n.id}>
                {n.location_name ? `${n.full_name} — ${n.location_name}` : n.full_name}
              </option>
            ))}
          </select>
        </div>
      )}

      {!setup?.ready ? (
        <div className="card loading">Δεν έχει οριστεί διατροφολόγος.</div>
      ) : (
        <>
          <div className="card" style={{ marginBottom: 16 }}>
            <div className="form-group">
              <label className="form-label">Ημέρες</label>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {WEEKDAYS.map(d => (
                  <Chip key={d.v} label={d.label} checked={weekdays.includes(d.v)} onClick={() => toggle(weekdays, setWeekdays, d.v)} />
                ))}
              </div>
            </div>
            <div className="form-group">
              <label className="form-label">Ώρες έναρξης</label>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
                {TIMES.map(t => (
                  <Chip key={t} label={t} checked={times.includes(t)} onClick={() => toggle(times, setTimes, t)} />
                ))}
              </div>
            </div>
            <button className="btn btn-primary" type="button" onClick={save}><Plus size={14} /> Προσθήκη ωραρίου</button>
          </div>

          <div className="card">
            <table>
              <thead><tr><th>Ημέρα</th><th>Ώρα</th><th></th></tr></thead>
              <tbody>
                {schedules.map(s => (
                  <tr key={s.id}>
                    <td>{WEEKDAYS.find(d => d.v === s.weekday)?.label || s.weekday}</td>
                    <td>{String(s.start_time).slice(0, 5)}</td>
                    <td><button className="btn btn-danger btn-sm" onClick={() => remove(s.id)}><Trash2 size={14} /></button></td>
                  </tr>
                ))}
                {!schedules.length && <tr><td colSpan={3} className="loading">Δεν υπάρχουν ώρες — πρόσθεσε παραπάνω</td></tr>}
              </tbody>
            </table>
          </div>
        </>
      )}
    </Layout>
  );
}
