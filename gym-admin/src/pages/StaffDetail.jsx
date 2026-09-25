import { useEffect, useMemo, useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import Layout from '../components/Layout';
import api from '../api/client';
import toast from 'react-hot-toast';
import { ArrowLeft, Save, Upload, Plus, X, CalendarOff, KeyRound, Clock, Check, Trash2, Copy } from 'lucide-react';
import LocationCheckboxes from '../components/LocationCheckboxes';
import StaffDeleteModal from '../components/StaffDeleteModal';
import { mediaUrl, API_BASE } from '../utils/media';
import AvailabilityEditor from '../components/AvailabilityEditor';

function StaffPortalSection({ staffId }) {
  const [portal, setPortal] = useState({ portal_email: '', portal_enabled: false, has_password: false });
  const [password, setPassword] = useState('');
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    api.get(`/client-admin/staff/${staffId}/portal`)
      .then(r => setPortal({
        portal_email: r.data.portal_email || '',
        portal_enabled: r.data.portal_enabled,
        has_password: r.data.has_password,
      }))
      .catch(() => {});
  }, [staffId]);

  const savePortal = async (enabled) => {
    if (enabled && !portal.portal_email.trim()) {
      toast.error('Συμπληρώστε email σύνδεσης');
      return;
    }
    if (enabled && !portal.has_password && !password.trim()) {
      toast.error('Ορίστε κωδικό για την πρώτη ενεργοποίηση');
      return;
    }
    setSaving(true);
    try {
      await api.put(`/client-admin/staff/${staffId}/portal`, {
        portal_email: portal.portal_email,
        password: password || undefined,
        enabled,
      });
      toast.success(enabled ? 'Portal ενεργοποιήθηκε' : 'Portal απενεργοποιήθηκε');
      setPassword('');
      const r = await api.get(`/client-admin/staff/${staffId}/portal`);
      setPortal({
        portal_email: r.data.portal_email || '',
        portal_enabled: r.data.portal_enabled,
        has_password: r.data.has_password,
      });
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="card" style={{ marginBottom: 16 }}>
      <div className="card-header">
        <span className="card-title"><KeyRound size={16} style={{ verticalAlign: -3, marginRight: 6 }} />Portal γυμναστή</span>
      </div>
      <p className="text-muted" style={{ marginBottom: 14, fontSize: '0.88rem' }}>
        Κάθε γυμναστής έχει δικό του email/κωδικό. Βλέπει μόνο το πρόγραμμα και τους πελάτες των υπηρεσιών που του έχεις αναθέσει.
      </p>
      <div className="form-grid-2" style={{ maxWidth: 520 }}>
        <div className="form-group">
          <label className="form-label">Email σύνδεσης</label>
          <input
            className="form-input"
            type="email"
            value={portal.portal_email}
            onChange={e => setPortal(p => ({ ...p, portal_email: e.target.value }))}
            placeholder="trainer@gym.com"
          />
        </div>
        <div className="form-group">
          <label className="form-label">{portal.has_password ? 'Νέος κωδικός (προαιρ.)' : 'Κωδικός'}</label>
          <input
            className="form-input"
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            placeholder="••••••••"
          />
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8, marginTop: 8, flexWrap: 'wrap' }}>
        <button type="button" className="btn btn-primary btn-sm" disabled={saving} onClick={() => savePortal(true)}>
          {portal.portal_enabled ? 'Ενημέρωση portal' : 'Ενεργοποίηση portal'}
        </button>
        {portal.portal_enabled && (
          <button type="button" className="btn btn-secondary btn-sm" disabled={saving} onClick={() => savePortal(false)}>
            Απενεργοποίηση
          </button>
        )}
      </div>
    </div>
  );
}

function PendingAvailabilityRequests({ staffId, onResolved }) {
  const [requests, setRequests] = useState([]);

  const load = () => api.get(`/client-admin/staff/${staffId}/availability-requests`, { params: { status: 'pending' } })
    .then(r => setRequests(r.data))
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

function parseGymHours(raw) {
  if (!raw) return null;
  try { return typeof raw === 'string' ? JSON.parse(raw) : raw; } catch { return null; }
}

function LeavesSection({ staffId }) {
  const [leaves, setLeaves] = useState([]);
  const [form, setForm] = useState({ date_from: '', date_to: '', reason: '' });
  const [saving, setSaving] = useState(false);

  const load = () => api.get(`/client-admin/staff/${staffId}/leaves`)
    .then(r => setLeaves(r.data)).catch(() => {});

  useEffect(() => { load(); }, [staffId]);

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

  const [profile, setProfile] = useState({ full_name: '', role: '', bio: '', color_hex: '#607D8B', avatar_url: null });
  const [services, setServices] = useState([]);
  const [assigned, setAssigned] = useState([]);
  const [availability, setAvailability] = useState({});
  const [activeTab, setActiveTab] = useState(null);
  const [gymHours, setGymHours] = useState(null);
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [showDelete, setShowDelete] = useState(false);
  const [locationIds, setLocationIds] = useState([]);
  const [locations, setLocations] = useState([]);
  const [activeAvailLocationId, setActiveAvailLocationId] = useState('');

  const staffLocations = useMemo(() => {
    if (!locations.length) return [];
    if (!locationIds.length) return locations;
    return locations.filter((l) => locationIds.includes(l.id));
  }, [locations, locationIds]);

  const avKey = (sid, locId = activeAvailLocationId) => (
    staffLocations.length > 1 ? `${sid}:${locId}` : sid
  );

  const serviceAvailStatus = (svcId) => {
    if (staffLocations.length <= 1) {
      const count = (availability[avKey(svcId)] || []).length;
      return count > 0 ? 'ok' : 'empty';
    }
    const counts = staffLocations.map(
      (loc) => (availability[`${svcId}:${loc.id}`] || []).length,
    );
    if (counts.every((c) => c > 0)) return 'ok';
    if (counts.some((c) => c > 0)) return 'partial';
    return 'empty';
  };

  const load = async () => {
    const [staffRes, svcRes, assignedRes, settingsRes, locRes, allLocsRes] = await Promise.all([
      api.get('/client-admin/staff'),
      api.get('/client-admin/services'),
      api.get(`/client-admin/staff/${id}/services`),
      api.get('/client-admin/settings').catch(() => ({ data: null })),
      api.get(`/client-admin/staff/${id}/locations`).catch(() => ({ data: [] })),
      api.get('/client-admin/locations').catch(() => ({ data: [] })),
    ]);

    const member = staffRes.data.find(s => s.id === id);
    if (!member) { navigate('/staff'); return; }

    setProfile({ full_name: member.full_name, role: member.role, bio: member.bio || '', color_hex: member.color_hex || '#607D8B', avatar_url: member.avatar_url });

    const gh = parseGymHours(settingsRes.data?.opening_hours);
    setGymHours(gh);

    const allServices = Array.isArray(svcRes.data) ? svcRes.data : [];
    setServices(allServices);
    const assignedIds = Array.isArray(assignedRes.data) ? assignedRes.data.map(r => r.service_id) : [];
    setAssigned(assignedIds);
    setLocationIds(locRes.data || []);
    const locs = (allLocsRes.data || []).filter((l) => l.is_active);
    setLocations(locs);
    const assignedLocIds = locRes.data || [];
    const staffLocs = assignedLocIds.length
      ? locs.filter((l) => assignedLocIds.includes(l.id))
      : locs;
    const availLoc = activeAvailLocationId && staffLocs.some((l) => l.id === activeAvailLocationId)
      ? activeAvailLocationId
      : (staffLocs[0]?.id || '');
    if (availLoc && availLoc !== activeAvailLocationId) setActiveAvailLocationId(availLoc);
    if (assignedIds.length > 0 && !activeTab) setActiveTab(assignedIds[0]);

    const avResults = await Promise.all(
      assignedIds.flatMap((sid) => {
        if (staffLocs.length > 1) {
          return staffLocs.map((loc) =>
            api.get(`/client-admin/staff/${id}/availability`, {
              params: { service_id: sid, location_id: loc.id },
            })
              .then((r) => ({
                key: `${sid}:${loc.id}`,
                slots: r.data.map((s) => ({
                  weekday: s.weekday,
                  start_time: s.start_time?.slice(0, 5),
                  end_time: s.end_time?.slice(0, 5),
                })),
              }))
              .catch(() => ({ key: `${sid}:${loc.id}`, slots: [] }))
          );
        }
        return [
          api.get(`/client-admin/staff/${id}/availability?service_id=${sid}`)
            .then((r) => ({
              key: sid,
              slots: r.data.map((s) => ({
                weekday: s.weekday,
                start_time: s.start_time?.slice(0, 5),
                end_time: s.end_time?.slice(0, 5),
              })),
            }))
            .catch(() => ({ key: sid, slots: [] })),
        ];
      })
    );
    const av = {};
    for (const { key, slots } of avResults) av[key] = slots;
    setAvailability(av);
  };

  useEffect(() => { load().catch(() => navigate('/staff')); }, [id]);

  useEffect(() => {
    if (!staffLocations.length) return;
    if (!staffLocations.some((l) => l.id === activeAvailLocationId)) {
      setActiveAvailLocationId(staffLocations[0].id);
    }
  }, [staffLocations, activeAvailLocationId]);

  const toggleService = async (sid) => {
    const next = assigned.includes(sid)
      ? assigned.filter(x => x !== sid)
      : [...assigned, sid];
    setAssigned(next);
    if (!assigned.includes(sid) && !availability[avKey(sid)]) {
      setAvailability(prev => ({ ...prev, [avKey(sid)]: [] }));
      setActiveTab(sid);
    }
  };

  const setSlots = (sid, slots) => setAvailability((prev) => ({ ...prev, [avKey(sid)]: slots }));

  const copyScheduleToOtherLocations = () => {
    if (!activeTab || staffLocations.length < 2) return;
    const source = availability[avKey(activeTab)] || [];
    if (!source.length) {
      toast.error('Ορίσε πρώτα ωράριο για αυτό το γυμναστήριο');
      return;
    }
    const updates = {};
    staffLocations.forEach((loc) => {
      if (loc.id !== activeAvailLocationId) {
        updates[`${activeTab}:${loc.id}`] = source.map((s) => ({ ...s }));
      }
    });
    setAvailability((prev) => ({ ...prev, ...updates }));
    toast.success('Το ωράριο αντιγράφηκε στα υπόλοιπα γυμναστήρια');
  };

  const save = async () => {
    setSaving(true);
    try {
      await Promise.all([
        api.patch(`/client-admin/staff/${id}`, profile),
        api.put(`/client-admin/staff/${id}/services`, { service_ids: assigned }),
        api.put(`/client-admin/staff/${id}/locations`, { location_ids: locationIds }),
      ]);
      // Delete general availability (no longer used)
      await api.put(`/client-admin/staff/${id}/availability`, { slots: [], service_id: null });
      for (const sid of assigned) {
        if (staffLocations.length > 1) {
          for (const loc of staffLocations) {
            await api.put(`/client-admin/staff/${id}/availability`, {
              slots: availability[`${sid}:${loc.id}`] || [],
              service_id: sid,
              location_id: loc.id,
            });
          }
        } else {
          await api.put(`/client-admin/staff/${id}/availability`, {
            slots: availability[sid] || [],
            service_id: sid,
          });
        }
      }
      toast.success('Αποθηκεύτηκε');
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

  const assignedServices = services.filter(s => assigned.includes(s.id));

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
            <div className="form-group">
              <label className="form-label">Bio</label>
              <textarea className="form-input" rows={2} value={profile.bio} onChange={e => setProfile({ ...profile, bio: e.target.value })} />
            </div>
            <div className="form-group">
              <label className="form-label">Χρώμα</label>
              <input type="color" className="form-input" value={profile.color_hex} onChange={e => setProfile({ ...profile, color_hex: e.target.value })} style={{ width: 80 }} />
            </div>
          </div>
        </div>
      </div>

      {/* Services */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-header"><span className="card-title">Υπηρεσίες</span></div>
        <LocationCheckboxes value={locationIds} onChange={setLocationIds} label="Γυμναστήρια" />
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {services.map(s => (
            <label key={s.id} style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '6px 12px', border: '1px solid #e2e8f0', borderRadius: 8, cursor: 'pointer', background: assigned.includes(s.id) ? '#f0fdf4' : '#fff' }}>
              <input type="checkbox" checked={assigned.includes(s.id)} onChange={() => toggleService(s.id)} />
              {s.name}
            </label>
          ))}
        </div>
      </div>

      <PendingAvailabilityRequests staffId={id} onResolved={load} />

      {/* Per-service availability */}
      <div className="card" style={{ marginBottom: 16 }}>
        <div className="card-header">
          <span className="card-title">Ωράριο ανά υπηρεσία</span>
          {!gymHours && (
            <span style={{ fontSize: '0.75rem', color: '#f59e0b' }}>
              ⚠ Δεν έχει οριστεί ωράριο γυμναστηρίου στις <a href="/settings">Ρυθμίσεις</a>
            </span>
          )}
        </div>

        {assignedServices.length === 0 ? (
          <div className="text-muted">Επίλεξε υπηρεσίες παραπάνω για να ορίσεις ωράριο.</div>
        ) : (
          <>
            {staffLocations.length > 1 && (
              <div style={{ marginBottom: 16 }}>
                <label className="form-label">Γυμναστήριο</label>
                <p className="text-muted" style={{ fontSize: '0.8rem', marginBottom: 8 }}>
                  Όρισε ξεχωριστό ωράριο για κάθε τοποθεσία. Τα γυμναστήρια προέρχονται από την επιλογή παραπάνω.
                </p>
                <div style={{ display: 'flex', gap: 0, borderBottom: '1px solid #e2e8f0', flexWrap: 'wrap' }}>
                  {staffLocations.map((loc) => {
                    const locSlots = activeTab
                      ? (availability[`${activeTab}:${loc.id}`] || []).length
                      : assignedServices.reduce(
                        (sum, svc) => sum + (availability[`${svc.id}:${loc.id}`] || []).length,
                        0,
                      );
                    const active = activeAvailLocationId === loc.id;
                    return (
                      <button
                        key={loc.id}
                        type="button"
                        onClick={() => setActiveAvailLocationId(loc.id)}
                        style={{
                          padding: '8px 18px',
                          border: 'none',
                          borderBottom: `2px solid ${active ? '#76C043' : 'transparent'}`,
                          background: 'none',
                          cursor: 'pointer',
                          fontWeight: active ? 600 : 400,
                          color: active ? '#76C043' : '#64748b',
                          fontSize: '0.9rem',
                          display: 'flex',
                          alignItems: 'center',
                          gap: 6,
                        }}
                      >
                        {loc.name}
                        {locSlots > 0 ? (
                          <span style={{ background: '#76C043', color: '#fff', borderRadius: 10, padding: '1px 6px', fontSize: '0.7rem' }}>
                            {locSlots}
                          </span>
                        ) : (
                          <span style={{ background: '#fca5a5', color: '#7f1d1d', borderRadius: 10, padding: '1px 6px', fontSize: '0.7rem' }}>
                            !
                          </span>
                        )}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}
            {/* Service tabs */}
            <div style={{ display: 'flex', gap: 0, borderBottom: '1px solid #e2e8f0', marginBottom: 16, flexWrap: 'wrap' }}>
              {assignedServices.map(svc => {
                const status = serviceAvailStatus(svc.id);
                const slotCount = staffLocations.length > 1
                  ? staffLocations.filter(
                    (loc) => (availability[`${svc.id}:${loc.id}`] || []).length > 0,
                  ).length
                  : (availability[avKey(svc.id)] || []).length;
                return (
                  <button
                    key={svc.id}
                    type="button"
                    onClick={() => setActiveTab(svc.id)}
                    style={{
                      padding: '8px 18px',
                      border: 'none',
                      borderBottom: `2px solid ${activeTab === svc.id ? '#76C043' : 'transparent'}`,
                      background: 'none',
                      cursor: 'pointer',
                      fontWeight: activeTab === svc.id ? 600 : 400,
                      color: activeTab === svc.id ? '#76C043' : '#64748b',
                      fontSize: '0.9rem',
                      display: 'flex', alignItems: 'center', gap: 6,
                    }}
                  >
                    {svc.name}
                    {status === 'ok' && (
                      <span style={{ background: '#76C043', color: '#fff', borderRadius: 10, padding: '1px 6px', fontSize: '0.7rem' }}>
                        {staffLocations.length > 1 ? `${slotCount}/${staffLocations.length}` : slotCount}
                      </span>
                    )}
                    {status === 'partial' && (
                      <span style={{ background: '#fbbf24', color: '#78350f', borderRadius: 10, padding: '1px 6px', fontSize: '0.7rem' }}>
                        {slotCount}/{staffLocations.length}
                      </span>
                    )}
                    {status === 'empty' && (
                      <span style={{ background: '#fca5a5', color: '#7f1d1d', borderRadius: 10, padding: '1px 6px', fontSize: '0.7rem' }}>
                        !
                      </span>
                    )}
                  </button>
                );
              })}
            </div>

            {activeTab && (
              <>
                {staffLocations.length > 1 && (
                  <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 10 }}>
                    <button
                      type="button"
                      className="btn btn-secondary btn-sm"
                      onClick={copyScheduleToOtherLocations}
                    >
                      <Copy size={14} /> Αντιγραφή σε όλα τα γυμναστήρια
                    </button>
                  </div>
                )}
                <AvailabilityEditor
                  slots={availability[avKey(activeTab)] || []}
                  onChange={(slots) => setSlots(activeTab, slots)}
                  gymHours={gymHours}
                />
              </>
            )}
          </>
        )}
      </div>

      {/* Leaves */}
      <LeavesSection staffId={id} />

      <StaffPortalSection staffId={id} />

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
