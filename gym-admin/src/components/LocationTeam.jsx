import { useEffect, useState } from 'react';
import api from '../api/client';
import toast from 'react-hot-toast';
import AvailabilityEditor from './AvailabilityEditor';

const DAYS = ['Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σαβ', 'Κυρ'];

function summarizeSlots(slots) {
  if (!slots?.length) return 'Χωρίς ώρες διαθεσιμότητας';
  const groups = new Map();
  for (const slot of slots) {
    const key = `${slot.start_time}–${slot.end_time}`;
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(DAYS[slot.weekday] || '');
  }
  return [...groups.entries()].map(([range, days]) => `${days.join(', ')} ${range}`).join(' · ');
}

function cloneSlots(slots) {
  return (slots || []).map((s) => ({ ...s }));
}

function addMinutes(time, mins) {
  const [h, m] = String(time).slice(0, 5).split(':').map(Number);
  const total = (h * 60 + (m || 0) + mins) % (24 * 60);
  return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
}

function rangesFromSchedules(rows, durationMins) {
  const dur = Number(durationMins) > 0 ? Number(durationMins) : 60;
  return (rows || []).flatMap((row) => {
    if (row.is_active === 0 || row.is_active === false) return [];
    const start = String(row.start_time || '').slice(0, 5);
    if (!start) return [];
    return [{ weekday: Number(row.weekday), start_time: start, end_time: addMinutes(start, dur) }];
  });
}

async function slotsFromServices(locationId, serviceIds, services) {
  const chosen = services.filter((svc) => serviceIds.includes(svc.id));
  if (!locationId || !chosen.length) return [];
  const lists = await Promise.all(chosen.map((svc) => api.get(`/client-admin/services/${svc.id}/slot-schedules`, { params: { location_id: locationId } })
    .then((res) => rangesFromSchedules(res.data, svc.duration_mins))
    .catch(() => [])));
  const seen = new Set();
  return lists.flat().filter((slot) => {
    const key = `${slot.weekday}-${slot.start_time}-${slot.end_time}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  }).sort((a, b) => a.weekday - b.weekday || a.start_time.localeCompare(b.start_time));
}

export default function LocationTeam({ locationId, gymHours }) {
  const [services, setServices] = useState([]);
  const [trainers, setTrainers] = useState([]);
  const [hoursTarget, setHoursTarget] = useState('all');
  const [slots, setSlots] = useState([]);
  const [savingTeam, setSavingTeam] = useState(false);
  const [savingHours, setSavingHours] = useState(false);

  const load = async () => {
    const r = await api.get(`/client-admin/locations/${locationId}/team`);
    const list = r.data.trainers || [];
    setServices(r.data.services || []);
    setTrainers(list);
    setHoursTarget('all');
    const sample = list.find((t) => t.works_here && t.slots?.length) || list.find((t) => t.works_here);
    setSlots(cloneSlots(sample?.slots));
  };

  useEffect(() => {
    load().catch(() => toast.error('Δεν φορτώθηκε η ομάδα του καταστήματος'));
  }, [locationId]);

  const patchTrainer = (id, patch) => {
    setTrainers((prev) => prev.map((t) => (t.id === id ? { ...t, ...patch } : t)));
  };

  const toggleService = (trainer, serviceId) => {
    const has = trainer.service_ids.includes(serviceId);
    patchTrainer(trainer.id, {
      service_ids: has
        ? trainer.service_ids.filter((x) => x !== serviceId)
        : [...trainer.service_ids, serviceId],
    });
  };

  const payloadTrainers = () => trainers.map((t) => ({
    staff_id: t.id,
    works_here: !!t.works_here,
    service_ids: t.works_here ? t.service_ids : [],
  }));

  const saveTeam = async () => {
    setSavingTeam(true);
    try {
      await api.put(`/client-admin/locations/${locationId}/team`, { trainers: payloadTrainers() });
      toast.success('Αποθηκεύτηκε ποιοι δουλεύουν εδώ και τι κάνουν');
      await load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSavingTeam(false);
    }
  };

  const saveHours = async () => {
    const working = trainers.filter((t) => t.works_here);
    if (!working.length) {
      toast.error('Διάλεξε πρώτα ποιοι δουλεύουν σε αυτό το κατάστημα');
      return;
    }
    if (hoursTarget === 'all') {
      const ok = window.confirm(`Το ίδιο ωράριο θα μπει και στους ${working.length} που δουλεύουν εδώ. Συνέχεια;`);
      if (!ok) return;
    }
    setSavingHours(true);
    try {
      await api.put(`/client-admin/locations/${locationId}/team`, {
        trainers: payloadTrainers(),
        hours: { apply_to: hoursTarget, slots },
      });
      toast.success(hoursTarget === 'all' ? 'Το ωράριο μπήκε σε όλους' : 'Αποθηκεύτηκε το ωράριο');
      await load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSavingHours(false);
    }
  };

  const fillFromPrograms = async () => {
    const people = hoursTarget === 'all' ? working : working.filter((t) => t.id === hoursTarget);
    const serviceIds = [...new Set(people.flatMap((t) => t.service_ids || []))];
    if (!serviceIds.length) {
      toast.error('Διάλεξε πρώτα τις υπηρεσίες');
      return;
    }
    const next = await slotsFromServices(locationId, serviceIds, services);
    if (!next.length) {
      toast.error('Δεν υπάρχει πρόγραμμα για τις επιλεγμένες υπηρεσίες σε αυτό το κατάστημα');
      return;
    }
    setSlots(next);
  };

  const pickTarget = (value) => {
    setHoursTarget(value);
    if (value === 'all') {
      const sample = trainers.find((t) => t.works_here && t.slots?.length);
      setSlots(cloneSlots(sample?.slots));
      return;
    }
    const person = trainers.find((t) => t.id === value);
    setSlots(cloneSlots(person?.slots));
  };

  const working = trainers.filter((t) => t.works_here);
  const serviceName = (id) => services.find((s) => s.id === id)?.name;

  return (
    <div style={{ marginTop: 16, paddingTop: 14, borderTop: '1px solid #e2e8f0' }}>
      <div style={{ fontWeight: 700, marginBottom: 4 }}>Ποιοι δουλεύουν εδώ και τι κάνουν</div>
      <div className="text-muted" style={{ fontSize: '0.78rem', marginBottom: 12, lineHeight: 1.5 }}>
        Τσέκαρε τον γυμναστή, διάλεξε τις υπηρεσίες αυτού του καταστήματος και μετά όρισε τις ώρες διαθεσιμότητας — για έναν ή για όλους.
      </div>

      {!trainers.length && (
        <div className="text-muted" style={{ fontSize: '0.85rem' }}>Δεν υπάρχει προσωπικό ακόμα. Πρόσθεσέ το από το μενού Προσωπικό.</div>
      )}

      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {trainers.map((trainer) => (
          <div key={trainer.id} style={{ border: '1px solid #e2e8f0', borderRadius: 10, padding: 12, background: trainer.works_here ? '#f8fafc' : '#fff' }}>
            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
              <input
                type="checkbox"
                checked={!!trainer.works_here}
                onChange={(e) => patchTrainer(trainer.id, { works_here: e.target.checked })}
              />
              <span style={{ width: 10, height: 10, borderRadius: '50%', background: trainer.color_hex || '#64748b' }} />
              <span style={{ fontWeight: 650 }}>{trainer.full_name}</span>
              <span className="text-muted" style={{ fontSize: '0.78rem' }}>{trainer.role}</span>
              {trainer.implicit_all && trainer.works_here && (
                <span style={{ fontSize: '0.7rem', color: '#b45309' }}>φαίνεται σε όλα μέχρι να τον αφαιρέσεις από κάποιο</span>
              )}
            </label>
            {trainer.works_here && (
              <>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, marginTop: 10 }}>
                  {services.map((svc) => {
                    const on = trainer.service_ids.includes(svc.id);
                    return (
                      <button
                        key={svc.id}
                        type="button"
                        onClick={() => toggleService(trainer, svc.id)}
                        style={{
                          border: `1px solid ${on ? '#76C043' : '#e2e8f0'}`,
                          background: on ? '#f0fdf4' : '#fff',
                          borderRadius: 999,
                          padding: '4px 10px',
                          fontSize: '0.78rem',
                          cursor: 'pointer',
                        }}
                      >
                        {svc.name}
                      </button>
                    );
                  })}
                  {!services.length && <span className="text-muted" style={{ fontSize: '0.78rem' }}>Δεν υπάρχουν υπηρεσίες.</span>}
                </div>
                <div className="text-muted" style={{ fontSize: '0.75rem', marginTop: 8 }}>
                  {(trainer.service_ids || []).map(serviceName).filter(Boolean).join(', ') || 'Καμία υπηρεσία'}
                  {' · '}
                  {trainer.hours_inherited ? `Κληρονομημένο: ${summarizeSlots(trainer.slots)}` : summarizeSlots(trainer.slots)}
                </div>
              </>
            )}
          </div>
        ))}
      </div>

      {!!trainers.length && (
        <button type="button" className="btn btn-secondary" style={{ marginTop: 12 }} onClick={saveTeam} disabled={savingTeam}>
          {savingTeam ? 'Αποθήκευση...' : 'Αποθήκευση ομάδας'}
        </button>
      )}

      {!!working.length && (
        <div style={{ marginTop: 18 }}>
          <div style={{ fontWeight: 700, marginBottom: 4 }}>Ώρες διαθεσιμότητας σε αυτό το κατάστημα</div>
          <div className="text-muted" style={{ fontSize: '0.78rem', marginBottom: 10, lineHeight: 1.5 }}>
            Οι ώρες βγαίνουν από το πρόγραμμα των υπηρεσιών που κάνει εδώ. Μπορείς να τις βάλεις σε όλους ή μόνο σε έναν.
          </div>
          <div className="form-group" style={{ maxWidth: 360 }}>
            <label className="form-label">Σε ποιον ισχύει</label>
            <select className="form-input" value={hoursTarget} onChange={(e) => pickTarget(e.target.value)}>
              <option value="all">Όλοι όσοι δουλεύουν εδώ ({working.length})</option>
              {working.map((t) => (
                <option key={t.id} value={t.id}>{t.full_name}</option>
              ))}
            </select>
          </div>
          <AvailabilityEditor
            slots={slots}
            onChange={setSlots}
            fillLabel="Γέμισε από το πρόγραμμα των υπηρεσιών"
            onFill={fillFromPrograms}
          />
          <button type="button" className="btn btn-primary" style={{ marginTop: 12 }} onClick={saveHours} disabled={savingHours}>
            {savingHours ? 'Αποθήκευση...' : hoursTarget === 'all' ? 'Αποθήκευση ωραρίου για όλους' : 'Αποθήκευση ωραρίου'}
          </button>
        </div>
      )}
    </div>
  );
}
