import { useEffect, useRef, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { ArrowLeft, Save, Upload, Plus, X, CalendarOff, Clock, Check, Trash2, Copy } from 'lucide-react';
import StaffDeleteModal from '../components/StaffDeleteModal';
import { mediaUrl, API_BASE } from '../utils/media';
import AvailabilityEditor from '../components/AvailabilityEditor';

function PendingAvailabilityRequests({ staffId, onResolved }) {
  const [requests, setRequests] = useState([]);

  const load = () => api.get(`/client-admin/staff/${staffId}/availability-requests`, { params: { status: 'pending' } })
    .then(r => setRequests(Array.isArray(r.data) ? r.data : []))
    .catch(() => {});

  useEffect(() => { load(); }, [staffId]);

  const approve = async (requestId) => {
    try {
      await api.post(`/client-admin/staff/${staffId}/availability-requests/${requestId}/approve`);
      toast.success('Η διαθεσιμότητα εγκρίθηκε');
      load();
      onResolved?.();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  const reject = async (requestId) => {
    const note = window.prompt('Λόγος απόρριψης (προαιρετικά)') || '';
    try {
      await api.post(`/client-admin/staff/${staffId}/availability-requests/${requestId}/reject`, { note });
      toast.success('Η αίτηση απορρίφθηκε');
      load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    }
  };

  if (!requests.length) return null;

  return (
    <div className="card" style={{ marginBottom: 16, borderLeft: '4px solid #f59e0b' }}>
      <div className="card-header">
        <span className="card-title"><Clock size={16} style={{ marginRight: 6 }} />Αιτήσεις διαθεσιμότητας (αναμονή)</span>
      </div>
      {requests.map(req => (
        <div key={req.id} style={{ padding: '12px 16px', borderTop: '1px solid #e2e8f0' }}>
          <div style={{ fontWeight: 700, marginBottom: 4 }}>{req.service_name || 'Υπηρεσία'}</div>
          <div className="text-muted" style={{ fontSize: '0.82rem', marginBottom: 10 }}>
            Υποβλήθηκε {new Date(req.submitted_at).toLocaleString('el-GR')} · {req.proposed_slots?.length || 0} slots
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <button type="button" className="btn btn-primary btn-sm" onClick={() => approve(req.id)}>
              <Check size={14} /> Έγκριση
            </button>
            <button type="button" className="btn btn-secondary btn-sm" onClick={() => reject(req.id)}>
              Απόρριψη
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}

const DAYS = ['Δευτέρα', 'Τρίτη', 'Τετάρτη', 'Πέμπτη', 'Παρασκευή', 'Σάββατο', 'Κυριακή'];

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

function LeavesSection({ staffId }) {
  const [leaves, setLeaves] = useState([]);
  const [balance, setBalance] = useState(null);
  const [allowance, setAllowance] = useState('');
  const [form, setForm] = useState({ date_from: '', date_to: '', reason: '' });
  const [saving, setSaving] = useState(false);

  const load = () => api.get(`/client-admin/staff/${staffId}/leaves`)
    .then(r => {
      const data = r.data || {};
      setLeaves(Array.isArray(data) ? data : (data.leaves || []));
      if (!Array.isArray(data)) {
        setBalance(data);
        setAllowance(data.annual_leave_days != null ? String(data.annual_leave_days) : '');
      }
    }).catch(() => {});

  useEffect(() => { load(); }, [staffId]);

  const saveAllowance = async () => {
    const days = Number(allowance);
    if (!Number.isInteger(days) || days < 0) return toast.error('Βάλε ακέραιες ημέρες άδειας');
    setSaving(true);
    try {
      await api.patch(`/client-admin/staff/${staffId}`, { annual_leave_days: days });
      toast.success('Αποθηκεύτηκαν οι ημέρες που δικαιούται');
      load();
    } catch (err) { toast.error(err.response?.data?.error || 'Σφάλμα'); }
    finally { setSaving(false); }
  };

  const add = async (e) => {
    e.preventDefault();
    if (!form.date_from || !form.date_to) return toast.error('Βάλε ημερομηνίες');
    setSaving(true);
    try {
      await api.post(`/client-admin/staff/${staffId}/leaves`, form);
      setForm({ date_from: '', date_to: '', reason: '' });
      load();
      toast.success('Άδεια καταχωρήθηκε');
    } catch (err) { toast.error(err.response?.data?.error || 'Σφάλμα'); }
    finally { setSaving(false); }
  };

  const remove = async (id) => {
    await api.delete(`/client-admin/staff/${staffId}/leaves/${id}`);
    load();
  };

  const fmt = (d) => new Date(d).toLocaleDateString('el-GR');

  return (
    <div className="card" style={{ marginBottom: 16 }}>
      <div className="card-header">
        <span className="card-title"><CalendarOff size={16} style={{ marginRight: 6 }} />Άδειες / Απουσίες</span>
      </div>

      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', alignItems: 'flex-end', marginBottom: 16 }}>
        <div className="form-group" style={{ marginBottom: 0 }}>
          <label className="form-label">Ημέρες που δικαιούται</label>
          <input type="number" min="0" className="form-input" style={{ width: 90 }} value={allowance} onChange={e => setAllowance(e.target.value)} />
        </div>
        <button type="button" className="btn btn-secondary btn-sm" onClick={saveAllowance} disabled={saving}>Αποθήκευση</button>
        {balance && (
          <div className="text-muted" style={{ fontSize: '0.85rem', paddingBottom: 8 }}>
            Χρησιμοποιήθηκαν <strong>{balance.days_used ?? 0}</strong>
            {' · '}
            Απομένουν <strong>{balance.days_remaining ?? 0}</strong>
            {balance.personal ? '' : ' · από την προεπιλογή του γυμναστηρίου'}
          </div>
        )}
      </div>

      <form onSubmit={add} style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginBottom: 16, alignItems: 'flex-end' }}>
        <div className="form-group" style={{ marginBottom: 0 }}>
          <label className="form-label">Από</label>
          <input type="date" className="form-input" value={form.date_from} onChange={e => setForm({ ...form, date_from: e.target.value })} />
        </div>
        <div className="form-group" style={{ marginBottom: 0 }}>
          <label className="form-label">Έως</label>
          <input type="date" className="form-input" value={form.date_to} onChange={e => setForm({ ...form, date_to: e.target.value })} />
        </div>
        <div className="form-group" style={{ marginBottom: 0, flex: 1 }}>
          <label className="form-label">Αιτία (προαιρετικό)</label>
          <input className="form-input" placeholder="π.χ. Ετήσια άδεια" value={form.reason} onChange={e => setForm({ ...form, reason: e.target.value })} />
        </div>
        <button type="submit" className="btn btn-primary btn-sm" disabled={saving}>
          <Plus size={13} /> Προσθήκη
        </button>
      </form>

      {leaves.length === 0 ? (
        <div className="text-muted" style={{ fontSize: '0.85rem' }}>Δεν υπάρχουν καταχωρημένες άδειες.</div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
          {leaves.map(l => (
            <div key={l.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '8px 12px', background: '#fef3c7', borderRadius: 8, border: '1px solid #fcd34d' }}>
              <CalendarOff size={14} style={{ color: '#d97706', flexShrink: 0 }} />
              <div style={{ flex: 1 }}>
                <span style={{ fontWeight: 600 }}>{fmt(l.date_from)}</span>
                {l.date_from !== l.date_to && <span> — <span style={{ fontWeight: 600 }}>{fmt(l.date_to)}</span></span>}
                {l.days_count != null && <span style={{ color: '#92400e', marginLeft: 8, fontSize: '0.85rem' }}>· {l.days_count} ημ.</span>}
                {l.status && l.status !== 'approved' && <span style={{ color: '#64748b', marginLeft: 8, fontSize: '0.85rem' }}>· {l.status === 'pending' ? 'αναμονή' : 'απορρίφθηκε'}</span>}
                {l.reason && <span style={{ color: '#64748b', marginLeft: 8, fontSize: '0.85rem' }}>· {l.reason}</span>}
              </div>
              <button onClick={() => remove(l.id)} style={{ border: 'none', background: 'none', cursor: 'pointer', color: '#ef4444' }}>
                <X size={14} />
              </button>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

export default function StaffDetail() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [profile, setProfile] = useState({ full_name: '', role: '', bio: '', phone: '', color_hex: '#607D8B', avatar_url: null });
  const [services, setServices] = useState([]);
  const [places, setPlaces] = useState([]);
  const [activePlaceId, setActivePlaceId] = useState('');
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [showDelete, setShowDelete] = useState(false);
  const fillSeq = useRef(0);

  const activePlace = places.find((p) => p.id === activePlaceId) || places[0] || null;

  const load = async () => {
    const [staffRes, placesRes] = await Promise.all([
      api.get('/client-admin/staff'),
      api.get(`/client-admin/staff/${id}/places`),
    ]);

    const member = staffRes.data.find(s => s.id === id);
    if (!member) { navigate('/staff'); return; }

    setProfile({ full_name: member.full_name, role: member.role, bio: member.bio || '', phone: member.phone || '', color_hex: member.color_hex || '#607D8B', avatar_url: member.avatar_url });
    setServices(placesRes.data.services || []);
    const nextPlaces = placesRes.data.places || [];
    setPlaces(nextPlaces);
    setActivePlaceId((current) => (
      nextPlaces.some((p) => p.id === current) ? current : (nextPlaces.find((p) => p.works_here)?.id || nextPlaces[0]?.id || '')
    ));
  };

  useEffect(() => { load().catch(() => navigate('/staff')); }, [id]);

  const patchPlace = (placeId, patch) => {
    setPlaces((prev) => prev.map((p) => (p.id === placeId ? { ...p, ...patch } : p)));
  };

  const applyProgramHours = async (placeId, serviceIds) => {
    const seq = ++fillSeq.current;
    if (!serviceIds.length) {
      patchPlace(placeId, { slots: [], hours_inherited: false });
      toast.error('Διάλεξε τουλάχιστον μία υπηρεσία');
      return;
    }
    const next = await slotsFromServices(placeId, serviceIds, services);
    if (seq !== fillSeq.current) return;
    if (!next.length) {
      toast.error('Δεν υπάρχει πρόγραμμα για τις επιλεγμένες υπηρεσίες σε αυτό το κατάστημα');
      return;
    }
    patchPlace(placeId, { slots: next, hours_inherited: false });
  };

  const togglePlaceService = (place, serviceId) => {
    const has = (place.service_ids || []).includes(serviceId);
    const serviceIds = has
      ? place.service_ids.filter((x) => x !== serviceId)
      : [...(place.service_ids || []), serviceId];
    patchPlace(place.id, { service_ids: serviceIds });
    applyProgramHours(place.id, serviceIds);
  };

  const copyScheduleToOtherLocations = () => {
    if (!activePlace) return;
    if (!activePlace.slots?.length) {
      toast.error('Ορίσε πρώτα ώρες για αυτό το κατάστημα');
      return;
    }
    setPlaces((prev) => prev.map((p) => (
      p.works_here && p.id !== activePlace.id
        ? { ...p, slots: activePlace.slots.map((s) => ({ ...s })), hours_inherited: false }
        : p
    )));
    toast.success('Οι ώρες αντιγράφηκαν στα άλλα καταστήματα όπου δουλεύει');
  };

  const save = async () => {
    setSaving(true);
    try {
      await api.patch(`/client-admin/staff/${id}`, profile);
      await api.put(`/client-admin/staff/${id}/places`, {
        places: places.map((p) => ({
          location_id: p.id,
          works_here: !!p.works_here,
          service_ids: p.works_here ? (p.service_ids || []) : [],
          slots: p.works_here ? (p.slots || []) : [],
        })),
      });
      toast.success('Αποθηκεύτηκε');
      await load();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally { setSaving(false); }
  };

  const uploadPhoto = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    setUploading(true);
    const fd = new FormData();
    fd.append('avatar', file);
    try {
      const r = await api.post(`/client-admin/staff/${id}/avatar`, fd);
      setProfile(p => ({ ...p, avatar_url: r.data.avatar_url }));
      toast.success('Φωτογραφία ανέβηκε');
    } catch { toast.error('Αποτυχία upload'); }
    finally { setUploading(false); }
  };

  const avatarSrc = profile.avatar_url
    ? (profile.avatar_url.startsWith('http') ? profile.avatar_url : `${API_BASE}${profile.avatar_url}`)
    : null;

  return (
    <Layout title={profile.full_name || 'Προσωπικό'}>
      <button className="btn btn-secondary btn-sm" onClick={() => navigate('/staff')} style={{ marginBottom: 16 }}>
        <ArrowLeft size={14} /> Πίσω
      </button>

      {/* Profile */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-header"><span className="card-title">Προφίλ γυμναστή</span></div>
        <div style={{ display: 'flex', gap: 20, alignItems: 'flex-start' }}>
          <div style={{ textAlign: 'center' }}>
            {avatarSrc ? (
              <img src={avatarSrc} alt="" style={{ width: 96, height: 96, borderRadius: '50%', objectFit: 'cover' }} />
            ) : (
              <div style={{ width: 96, height: 96, borderRadius: '50%', background: profile.color_hex, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 32, fontWeight: 700 }}>
                {profile.full_name?.[0] || '?'}
              </div>
            )}
            <label className="btn btn-secondary btn-sm" style={{ marginTop: 8, cursor: 'pointer' }}>
              <Upload size={14} /> {uploading ? '...' : 'Φωτό'}
              <input type="file" accept="image/*" style={{ display: 'none' }} onChange={uploadPhoto} />
            </label>
          </div>
          <div style={{ flex: 1 }}>
            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Ονοματεπώνυμο</label>
                <input className="form-input" value={profile.full_name} onChange={e => setProfile({ ...profile, full_name: e.target.value })} />
              </div>
              <div className="form-group">
                <label className="form-label">Ρόλος / Ειδικότητα</label>
                <input className="form-input" value={profile.role} onChange={e => setProfile({ ...profile, role: e.target.value })} placeholder="π.χ. Personal Trainer" />
              </div>
            </div>
            <div className="form-grid-2">
              <div className="form-group">
                <label className="form-label">Κινητό</label>
                <input className="form-input" value={profile.phone} onChange={e => setProfile({ ...profile, phone: e.target.value })} placeholder="69XXXXXXXX" inputMode="tel" />
              </div>
              <div className="form-group">
                <label className="form-label">Bio</label>
                <textarea className="form-input" rows={2} value={profile.bio} onChange={e => setProfile({ ...profile, bio: e.target.value })} />
              </div>
            </div>
            <p className="text-muted" style={{ fontSize: '0.82rem', marginTop: -4 }}>
              Με αυτό το κινητό μπαίνει στο app και βλέπει το γυμναστήριο ως trainer.
            </p>
            <div className="form-group">
              <label className="form-label">Χρώμα</label>
              <input type="color" className="form-input" value={profile.color_hex} onChange={e => setProfile({ ...profile, color_hex: e.target.value })} style={{ width: 80 }} />
            </div>
          </div>
        </div>
      </div>

      <PendingAvailabilityRequests staffId={id} onResolved={load} />

      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-header"><span className="card-title">Καταστήματα, υπηρεσίες και ώρες</span></div>
        <p className="text-muted" style={{ fontSize: '0.85rem', marginBottom: 14, lineHeight: 1.5 }}>
          Σε κάθε κατάστημα διάλεξε αν δουλεύει και ποιες υπηρεσίες κάνει. Οι ώρες διαθεσιμότητας ακολουθούν το πρόγραμμα που έχεις περάσει σε κάθε υπηρεσία.
        </p>
        {!places.length ? (
          <div className="text-muted">Δεν υπάρχουν καταστήματα. Πρόσθεσέ τα από το μενού Καταστήματα.</div>
        ) : (
          <>
            <div style={{ display: 'flex', gap: 0, borderBottom: '1px solid #e2e8f0', marginBottom: 16, flexWrap: 'wrap' }}>
              {places.map((place) => {
                const active = activePlace?.id === place.id;
                const ready = place.works_here && (place.service_ids || []).length > 0 && (place.slots || []).length > 0;
                return (
                  <button
                    key={place.id}
                    type="button"
                    onClick={() => setActivePlaceId(place.id)}
                    style={{
                      padding: '8px 18px',
                      border: 'none',
                      borderBottom: `2px solid ${active ? '#76C043' : 'transparent'}`,
                      background: 'none',
                      cursor: 'pointer',
                      fontWeight: active ? 600 : 400,
                      color: active ? '#76C043' : '#64748b',
                      fontSize: '0.9rem',
                    }}
                  >
                    {place.name} {place.works_here ? (ready ? '· έτοιμο' : '· ελλιπές') : '· όχι'}
                  </button>
                );
              })}
            </div>
            {activePlace && (
              <>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 12, cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={!!activePlace.works_here}
                    onChange={(e) => patchPlace(activePlace.id, { works_here: e.target.checked })}
                  />
                  Δουλεύει στο {activePlace.name}
                </label>
                {activePlace.works_here && (
                  <>
                    <div className="form-label">Τι κάνει εδώ</div>
                    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginBottom: 16 }}>
                      {services.map((svc) => {
                        const on = (activePlace.service_ids || []).includes(svc.id);
                        return (
                          <button
                            key={svc.id}
                            type="button"
                            onClick={() => togglePlaceService(activePlace, svc.id)}
                            style={{
                              border: `1px solid ${on ? '#76C043' : '#e2e8f0'}`,
                              background: on ? '#f0fdf4' : '#fff',
                              borderRadius: 999,
                              padding: '6px 12px',
                              cursor: 'pointer',
                            }}
                          >
                            {svc.name}
                          </button>
                        );
                      })}
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                      <div className="form-label" style={{ marginBottom: 0 }}>Ώρες διαθεσιμότητας</div>
                      {places.filter((p) => p.works_here).length > 1 && (
                        <button type="button" className="btn btn-secondary btn-sm" onClick={copyScheduleToOtherLocations}>
                          <Copy size={14} /> Ίδιο ωράριο στα άλλα καταστήματα
                        </button>
                      )}
                    </div>
                    {activePlace.hours_inherited && (
                      <div className="text-muted" style={{ fontSize: '0.78rem', marginBottom: 8 }}>
                        Αυτές οι ώρες δεν έχουν αποθηκευτεί ακόμα ειδικά για αυτό το κατάστημα. Πάτα αποθήκευση για να ισχύσουν μόνο εδώ.
                      </div>
                    )}
                    <AvailabilityEditor
                      slots={activePlace.slots || []}
                      onChange={(next) => patchPlace(activePlace.id, { slots: next, hours_inherited: false })}
                      fillLabel="Γέμισε από το πρόγραμμα των υπηρεσιών"
                      onFill={() => applyProgramHours(activePlace.id, activePlace.service_ids || [])}
                    />
                  </>
                )}
              </>
            )}
          </>
        )}
      </div>

      {/* Leaves */}
      <LeavesSection staffId={id} />

      <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap', marginTop: 8 }}>
        <button className="btn btn-primary" onClick={save} disabled={saving}>
          <Save size={14} /> {saving ? 'Αποθήκευση...' : 'Αποθήκευση'}
        </button>
        <button type="button" className="btn btn-danger" onClick={() => setShowDelete(true)}>
          <Trash2 size={14} /> Διαγραφή προσωπικού
        </button>
      </div>

      <StaffDeleteModal
        open={showDelete}
        staffId={id}
        staffName={profile.full_name}
        onClose={() => setShowDelete(false)}
        onDeleted={() => navigate('/staff')}
      />
    </Layout>
  );
}
