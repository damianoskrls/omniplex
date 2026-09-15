import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Calendar, Check, CreditCard, FlaskConical, MapPin, Package, Search, Shield, Sparkles, User, X, Zap } from 'lucide-react';
import { Link } from 'react-router-dom';
import api from '../api/client';
import toast from 'react-hot-toast';
import Avatar from './ui/Avatar';
import ServiceIcon from './ui/ServiceIcon';
import { mediaUrl } from '../utils/media';

function normalize(str) {
  return String(str || '').toLowerCase().normalize('NFD').replace(/\p{M}/gu, '');
}

function normalizeUserId(value) {
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'object' && value.id != null) return String(value.id);
  return '';
}

const STEPS = ['Πελάτης', 'Πακέτο', 'Ραντεβού'];

export default function CreateBookingModal({
  open,
  onClose,
  initialDate,
  presetUserId = '',
  presetTrial = false,
  onSuccess,
}) {
  const [allClients, setAllClients] = useState([]);
  const [bookableMap, setBookableMap] = useState({});
  const [clientsLoading, setClientsLoading] = useState(false);
  const [bookingOptions, setBookingOptions] = useState([]);
  const [trialBlocks, setTrialBlocks] = useState([]);
  const [bookingOptionsLoading, setBookingOptionsLoading] = useState(false);
  const [selectedOption, setSelectedOption] = useState(null);
  const [clientQuery, setClientQuery] = useState('');
  const [clientOpen, setClientOpen] = useState(false);
  const clientSearchRef = useRef(null);
  const [slots, setSlots] = useState([]);
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [hideStaffSelection, setHideStaffSelection] = useState(false);
  const [serviceStaff, setServiceStaff] = useState([]);
  const [excludedStaffIds, setExcludedStaffIds] = useState([]);
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [locations, setLocations] = useState([]);
  const [form, setForm] = useState({
    user_id: '',
    service_id: '',
    location_id: '',
    date: initialDate,
    time: '',
    staff_id: '',
    use_credit: true,
    is_trial: false,
    force: false,
  });

  const loadBookableClients = useCallback(async () => {
    setClientsLoading(true);
    try {
      const [allRes, bookableRes] = await Promise.all([
        api.get('/client-admin/clients'),
        api.get('/client-admin/bookings/bookable-clients'),
      ]);
      const active = (allRes.data || []).filter(
        (c) => (c.account_status || 'active') === 'active',
      );
      setAllClients(active);
      const map = {};
      (bookableRes.data || []).forEach((c) => {
        map[c.id] = c;
      });
      active.forEach((c) => {
        if (!map[c.id] && Number(c.active_packages) > 0) {
          map[c.id] = {
            id: c.id,
            full_name: c.full_name,
            bookable_mode: 'package',
            can_create_booking: true,
            package_count: Number(c.active_packages),
          };
        }
      });
      setBookableMap(map);
    } catch {
      setAllClients([]);
      setBookableMap({});
      toast.error('Δεν φορτώθηκαν οι πελάτες');
    } finally {
      setClientsLoading(false);
    }
  }, []);

  const loadBookingOptions = useCallback(async (userId) => {
    const id = normalizeUserId(userId);
    if (!id) {
      setBookingOptions([]);
      setTrialBlocks([]);
      return;
    }
    setBookingOptionsLoading(true);
    try {
      const r = await api.get(`/client-admin/clients/${id}/booking-options`);
      const payload = r.data || {};
      const options = Array.isArray(payload) ? payload : (payload.options || []);
      const blocks = Array.isArray(payload) ? [] : (payload.trial_blocks || []);
      setBookingOptions(options);
      setTrialBlocks(blocks);
    } catch {
      setBookingOptions([]);
      setTrialBlocks([]);
      toast.error('Δεν φορτώθηκαν τα πακέτα του πελάτη');
    } finally {
      setBookingOptionsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (!open) return;
    const presetId = normalizeUserId(presetUserId);
    setForm({
      user_id: presetId,
      service_id: '',
      location_id: '',
      date: initialDate,
      time: '',
      staff_id: '',
      use_credit: !presetTrial,
      is_trial: presetTrial,
      force: false,
    });
    setClientQuery('');
    setClientOpen(false);
    setSelectedOption(null);
    setBookingOptions([]);
    setTrialBlocks([]);
    setSlots([]);
    setLocations([]);
    setHideStaffSelection(false);
    setServiceStaff([]);
    setExcludedStaffIds([]);

    (async () => {
      setLoading(true);
      try {
        await loadBookableClients();
        if (presetId) {
          await loadBookingOptions(presetId);
        }
      } catch {
        toast.error('Δεν φορτώθηκαν τα στοιχεία');
      } finally {
        setLoading(false);
      }
    })();
  }, [open, initialDate, presetUserId, presetTrial, loadBookableClients, loadBookingOptions]);

  useEffect(() => {
    const presetId = normalizeUserId(presetUserId);
    if (!open || !presetId || !bookableMap[presetId]) return;
    const c = allClients.find((x) => x.id === presetId);
    if (!c) return;
    setForm((prev) => ({ ...prev, user_id: c.id }));
    setClientQuery('');
    setClientOpen(false);
  }, [open, presetUserId, allClients, bookableMap]);

  const clientRows = useMemo(() => {
    const rows = allClients.map((c) => {
      const bookable = bookableMap[c.id];
      const canSelect = !!bookable || Number(c.active_packages) > 0;
      const canCreateBooking = canSelect
        && bookable?.can_create_booking !== false
        && bookable?.bookable_mode !== 'trial_pending';
      return {
        ...c,
        canSelect,
        canCreateBooking,
        bookable_mode: bookable?.bookable_mode || (canSelect ? 'package' : null),
        remaining_sessions: bookable?.remaining_sessions ?? null,
        package_count: bookable?.package_count ?? (Number(c.active_packages) || 0),
      };
    });
    rows.sort((a, b) => {
      if (a.canSelect !== b.canSelect) return a.canSelect ? -1 : 1;
      return a.full_name.localeCompare(b.full_name, 'el');
    });
    const q = normalize(clientQuery).trim();
    if (!q) return [];
    const filtered = rows.filter((c) => {
      const hay = normalize(`${c.full_name} ${c.email || ''} ${c.phone || ''}`);
      return hay.includes(q);
    });
    return filtered.slice(0, 20);
  }, [allClients, bookableMap, clientQuery]);

  const showClientList = clientOpen && normalize(clientQuery).trim().length >= 2;

  const selectedClient = useMemo(() => {
    if (!form.user_id) return null;
    const base = allClients.find((c) => c.id === form.user_id);
    if (!base) return null;
    const bookable = bookableMap[form.user_id];
    if (bookable) return { ...base, ...bookable, canBook: true };
    if (Number(base.active_packages) > 0) {
      return { ...base, canBook: true, bookable_mode: 'package' };
    }
    return null;
  }, [allClients, bookableMap, form.user_id]);

  const step = !form.user_id ? 1 : !form.service_id ? 2 : 3;

  const staffOptions = useMemo(() => {
    const slot = slots.find(s => s.time === form.time);
    return slot?.available_staff || [];
  }, [slots, form.time]);

  const activeStaffPool = useMemo(() => {
    if (!hideStaffSelection) return staffOptions;
    const excluded = new Set(excludedStaffIds.map(String));
    return serviceStaff.filter((s) => !excluded.has(String(s.id)));
  }, [hideStaffSelection, staffOptions, serviceStaff, excludedStaffIds]);

  const hasSessionsLeft = useMemo(() => {
    if (!selectedOption || form.is_trial) return true;
    const rem = selectedOption.remaining_sessions;
    if (rem == null || rem >= 9999) return true;
    return rem > 0;
  }, [selectedOption, form.is_trial]);

  const loadSlots = async (serviceId, date, locationId) => {
    if (!serviceId || !date) {
      setSlots([]);
      setServiceStaff([]);
      return;
    }
    setSlotsLoading(true);
    try {
      const params = { service_id: serviceId, date };
      if (locationId) params.location_id = locationId;
      const r = await api.get('/client-admin/booking-slots', { params });
      setSlots(r.data.slots || []);
      setHideStaffSelection(!!r.data.hide_staff_selection);
      setServiceStaff(r.data.service_staff || []);
      setExcludedStaffIds([]);
    } catch {
      setSlots([]);
      setServiceStaff([]);
      toast.error('Δεν φορτώθηκαν οι διαθέσιμες ώρες');
    } finally {
      setSlotsLoading(false);
    }
  };

  const loadServiceLocations = async (serviceId) => {
    try {
      const r = await api.get(`/client-admin/services/${serviceId}/locations`);
      const allLocs = await api.get('/client-admin/locations');
      const assigned = new Set((r.data || []).map((id) => String(id)));
      const locs = (allLocs.data || []).filter((l) => l.is_active);
      const filtered = assigned.size
        ? locs.filter((l) => assigned.has(String(l.id)))
        : locs;
      setLocations(filtered);
      return filtered;
    } catch {
      setLocations([]);
      return [];
    }
  };

  const applyDefaultLocation = (locs, serviceId, date) => {
    if (locs.length !== 1) return '';
    const locId = locs[0].id;
    loadSlots(serviceId, date, locId);
    return locId;
  };

  const pickBookingOption = async (option) => {
    const locs = await loadServiceLocations(option.service_id);
    setHideStaffSelection(!!option.hide_staff_selection);
    setSelectedOption(option);
    setForm((prev) => {
      const defaultLoc = applyDefaultLocation(locs, option.service_id, prev.date);
      return {
        ...prev,
        service_id: option.service_id,
        location_id: defaultLoc,
        time: '',
        staff_id: '',
        is_trial: false,
        use_credit: true,
      };
    });
    if (locs.length !== 1) setSlots([]);
  };

  useEffect(() => {
    if (step !== 3 || !form.service_id || locations.length !== 1) return;
    const locId = locations[0].id;
    if (String(form.location_id) === String(locId)) return;
    setForm((prev) => ({
      ...prev,
      location_id: locId,
      time: '',
      staff_id: '',
    }));
    loadSlots(form.service_id, form.date, locId);
  }, [step, locations, form.service_id, form.date, form.location_id]);

  const pickLocation = (locationId) => {
    setForm((prev) => {
      loadSlots(prev.service_id, prev.date, locationId);
      return { ...prev, location_id: locationId, time: '', staff_id: '' };
    });
  };

  const pickDate = (date) => {
    setForm((prev) => {
      if (prev.service_id && (prev.location_id || locations.length <= 1)) {
        loadSlots(prev.service_id, date, prev.location_id || undefined);
      }
      return { ...prev, date, time: '', staff_id: '' };
    });
  };

  const pickTime = (time) => {
    const slot = slots.find(s => s.time === time);
    const staffList = slot?.available_staff || [];
    setForm(prev => ({
      ...prev,
      time,
      staff_id: hideStaffSelection
        ? ''
        : (staffList.some(s => s.id === prev.staff_id)
          ? prev.staff_id
          : (staffList[0]?.id || '')),
    }));
  };

  const toggleStaffInPool = (staffId) => {
    const id = String(staffId);
    setExcludedStaffIds((prev) => {
      const set = new Set(prev.map(String));
      if (set.has(id)) set.delete(id);
      else set.add(id);
      return [...set];
    });
    setForm((prev) => (
      String(prev.staff_id) === id ? { ...prev, staff_id: '' } : prev
    ));
  };

  const pickManualStaff = (staffId) => {
    const id = String(staffId);
    if (excludedStaffIds.map(String).includes(id)) {
      setExcludedStaffIds((prev) => prev.filter((x) => String(x) !== id));
    }
    setForm((prev) => ({
      ...prev,
      staff_id: String(prev.staff_id) === id ? '' : staffId,
    }));
  };

  const pickClient = (client) => {
    if (!client.canSelect) {
      toast.error('Ο πελάτης δεν έχει πακέτο ή δοκιμαστικό — πέρασέ του πρώτα από τους Πελάτες');
      return;
    }
    setForm(prev => ({
      ...prev,
      user_id: client.id,
      service_id: '',
      location_id: '',
      time: '',
      staff_id: '',
      is_trial: false,
      use_credit: true,
    }));
    setSelectedOption(null);
    setSlots([]);
    setLocations([]);
    setClientQuery('');
    setClientOpen(false);
    loadBookingOptions(client.id);
  };

  const changeClient = () => {
    setForm(prev => ({
      ...prev,
      user_id: '',
      service_id: '',
      location_id: '',
      time: '',
      staff_id: '',
      is_trial: false,
      use_credit: true,
    }));
    setSelectedOption(null);
    setBookingOptions([]);
    setTrialBlocks([]);
    setSlots([]);
    setLocations([]);
    setHideStaffSelection(false);
    setServiceStaff([]);
    setExcludedStaffIds([]);
    setClientQuery('');
    setClientOpen(true);
    requestAnimationFrame(() => clientSearchRef.current?.focus());
  };

  const changePackage = () => {
    setForm(prev => ({
      ...prev,
      service_id: '',
      location_id: '',
      time: '',
      staff_id: '',
      is_trial: false,
      use_credit: true,
    }));
    setSelectedOption(null);
    setSlots([]);
    setLocations([]);
    setHideStaffSelection(false);
    setServiceStaff([]);
    setExcludedStaffIds([]);
  };

  const submit = async (e) => {
    e.preventDefault();
    if (!form.user_id || !form.service_id || !form.time) return;
    if (locations.length > 1 && !form.location_id) {
      toast.error('Επίλεξε τοποθεσία');
      return;
    }
    if (!hideStaffSelection && !form.staff_id) {
      toast.error('Επίλεξε γυμναστή');
      return;
    }
    if (hideStaffSelection && activeStaffPool.length === 0) {
      toast.error('Πρέπει να μείνει τουλάχιστον ένας γυμναστής στο pool');
      return;
    }
    if (!hasSessionsLeft) {
      toast.error('Ο πελάτης δεν έχει διαθέσιμες συνεδρίες στο πακέτο του');
      return;
    }
    setSubmitting(true);
    try {
      await api.post('/client-admin/bookings', {
        user_id: form.user_id,
        service_id: form.service_id,
        date: form.date,
        time: form.time,
        staff_id: form.staff_id || undefined,
        location_id: form.location_id || undefined,
        use_credit: form.is_trial ? false : form.use_credit,
        is_trial: form.is_trial,
        force: form.force,
        excluded_staff_ids: hideStaffSelection && !form.staff_id ? excludedStaffIds : undefined,
      });
      toast.success(form.is_trial ? 'Το δοκιμαστικό μάθημα καταχωρήθηκε' : 'Η κράτηση δημιουργήθηκε');
      onSuccess?.();
      onClose();
    } catch (err) {
      toast.error(err.response?.data?.error || 'Σφάλμα');
    } finally {
      setSubmitting(false);
    }
  };

  if (!open) return null;

  const canSubmit = form.user_id && form.service_id && form.time && hasSessionsLeft
    && (hideStaffSelection ? activeStaffPool.length > 0 : !!form.staff_id)
    && (locations.length <= 1 || form.location_id) && !submitting;

  const bookableCount = Object.keys(bookableMap).length;
  const noClientsAtAll = !loading && !clientsLoading && allClients.length === 0;
  const noBookableClients = !loading && !clientsLoading && allClients.length > 0 && bookableCount === 0;

  const clientEmptyMessage = 'Δεν υπάρχουν πελάτες με ενεργό πακέτο ή δοκιμαστικό. Πέρασε πρώτα πακέτο ή δοκιμαστικό στους πελάτες σου.';

  const formatSessions = (option) => {
    if (option.remaining_sessions == null || option.remaining_sessions >= 9999) return 'Απεριόριστες συνεδρίες';
    return `${option.remaining_sessions} συνεδρίες απομένουν`;
  };

  const formatTrialWhen = (iso) => {
    if (!iso) return null;
    return new Date(iso).toLocaleString('el-GR', {
      day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit',
    });
  };

  return (
    <div className="modal-overlay" onClick={e => e.target === e.currentTarget && onClose()}>
      <div className="modal cb-modal" onClick={e => e.stopPropagation()}>
        <div className="cb-modal-header">
          <div>
            <div className="cb-modal-title">Νέα κράτηση</div>
            <div className="cb-modal-sub">Κράτηση για λογαριασμό πελάτη</div>
          </div>
          <button type="button" className="cb-icon-btn" onClick={onClose} aria-label="Κλείσιμο">
            <X size={18} />
          </button>
        </div>

        {loading ? (
          <div className="loading">Φόρτωση...</div>
        ) : noClientsAtAll ? (
          <div className="cb-bookable-empty">
            <Package size={40} className="cb-bookable-empty-icon" />
            <p className="cb-bookable-empty-title">Δεν μπορείς να κάνεις κράτηση ακόμα</p>
            <p className="cb-bookable-empty-text">{clientEmptyMessage}</p>
            <Link to="/clients" className="btn btn-primary" onClick={onClose}>
              Μετάβαση στους Πελάτες
            </Link>
            <button type="button" className="btn btn-secondary" onClick={onClose}>
              Κλείσιμο
            </button>
          </div>
        ) : (
          <form onSubmit={submit} className="cb-form">
            {noBookableClients && (
              <div className="cb-bookable-banner">
                <Package size={18} />
                <span>{clientEmptyMessage}</span>
                <Link to="/clients" className="cb-bookable-banner-link" onClick={onClose}>
                  Πελάτες
                </Link>
              </div>
            )}

            <div className="cb-stepper" aria-label="Βήματα κράτησης">
              {STEPS.map((label, i) => {
                const n = i + 1;
                const done = step > n;
                const active = step === n;
                return (
                  <div
                    key={label}
                    className={`cb-step ${active ? 'active' : ''} ${done ? 'done' : ''}`}
                  >
                    <div className="cb-step-num">
                      {done ? <Check size={14} strokeWidth={3} /> : n}
                    </div>
                    <div className="cb-step-label">{label}</div>
                  </div>
                );
              })}
            </div>

            {step === 1 && (
              <section className="cb-section">
                <div className="cb-section-label">
                  <User size={16} /> Επίλεξε πελάτη
                </div>

                <div className="cb-search">
                  <Search size={18} className="cb-search-icon" />
                  <input
                    ref={clientSearchRef}
                    className="cb-search-input"
                    placeholder="Αναζήτηση πελάτη (όνομα, τηλέφωνο, email)..."
                    value={clientQuery}
                    onChange={e => {
                      const val = e.target.value;
                      setClientQuery(val);
                      setClientOpen(val.trim().length >= 2);
                    }}
                    onFocus={() => {
                      if (clientQuery.trim().length >= 2) setClientOpen(true);
                    }}
                  />
                </div>

                {showClientList && (
                  <div className="cb-client-list">
                    {clientsLoading && (
                      <div className="cb-empty-inline">Φόρτωση πελατών...</div>
                    )}
                    {!clientsLoading && clientRows.length === 0 && (
                      <div className="cb-empty-inline">
                        Δεν βρέθηκε πελάτης
                      </div>
                    )}
                    {clientRows.map((c) => (
                      <button
                        key={c.id}
                        type="button"
                        disabled={!c.canSelect}
                        className={`cb-client-item ${!c.canSelect ? 'disabled' : ''} ${c.canSelect && !c.canCreateBooking ? 'trial-pending' : ''}`}
                        onClick={() => pickClient(c)}
                      >
                        <Avatar name={c.full_name} size={40} />
                        <div className="cb-client-item-text">
                          <div className="cb-client-item-name">{c.full_name}</div>
                          <div className="cb-client-item-meta">
                            {c.phone || c.email || '—'}
                            {c.canCreateBooking && c.bookable_mode === 'package' && c.remaining_sessions != null
                              && ` · ${c.remaining_sessions} συνεδρίες`}
                            {c.canCreateBooking && c.bookable_mode === 'package' && c.remaining_sessions == null
                              && ' · Πακέτο'}
                            {c.canSelect && !c.canCreateBooking && ' · Δοκιμαστικό — χρειάζεται ενεργοποίηση'}
                            {!c.canSelect && ' · Χωρίς πακέτο ή δοκιμαστικό'}
                          </div>
                        </div>
                      </button>
                    ))}
                  </div>
                )}

                {!clientsLoading && !showClientList && (
                  <p className="cb-bookable-hint">
                    Πληκτρολόγησε τουλάχιστον 2 χαρακτήρες για αναζήτηση πελάτη.
                  </p>
                )}

                {!clientsLoading && allClients.length > 0 && showClientList && (
                  <p className="cb-bookable-hint">
                    Για κράτηση χρειάζεται ενεργό πακέτο. Πελάτες μόνο με δοκιμαστικό εμφανίζουν οδηγίες ενεργοποίησης στο επόμενο βήμα.
                  </p>
                )}
              </section>
            )}

            {step >= 2 && selectedClient && (
              <div className="cb-selected-client cb-selected-client-compact">
                <Avatar name={selectedClient.full_name} size={40} />
                <div className="cb-selected-info">
                  <div className="cb-selected-name">{selectedClient.full_name}</div>
                  <div className="cb-selected-meta">
                    {selectedClient.phone || selectedClient.email || '—'}
                  </div>
                </div>
                <Check size={18} className="cb-selected-check" aria-hidden />
                {step === 2 && (
                  <button type="button" className="cb-text-btn" onClick={changeClient}>
                    Αλλαγή
                  </button>
                )}
              </div>
            )}

            {step === 2 && (
              <section className="cb-section">
                <div className="cb-section-label">
                  <Package size={16} /> Επίλεξε πακέτο / υπηρεσία
                </div>

                {bookingOptionsLoading ? (
                  <div className="cb-empty-inline">Φόρτωση πακέτων...</div>
                ) : bookingOptions.length === 0 ? (
                  <div className="cb-trial-blocks">
                    {trialBlocks.length > 0 ? (
                      trialBlocks.map((block) => (
                        <div key={block.membership_id} className="cb-trial-block">
                          <div className="cb-trial-block-icon">
                            <FlaskConical size={22} />
                          </div>
                          <div className="cb-trial-block-body">
                            <div className="cb-trial-block-title">
                              {block.code === 'trial_scheduled' ? 'Δοκιμαστικό προγραμματισμένο' : 'Απαιτείται ενεργοποίηση πακέτου'}
                            </div>
                            <p className="cb-trial-block-text">{block.message}</p>
                            {block.trial_starts_at && block.code === 'trial_scheduled' && (
                              <p className="cb-trial-block-when">
                                Ώρα δοκιμαστικού: {formatTrialWhen(block.trial_starts_at)}
                              </p>
                            )}
                          </div>
                        </div>
                      ))
                    ) : (
                      <p className="cb-bookable-empty-text">
                        Ο πελάτης δεν έχει ενεργό πακέτο για κράτηση.
                      </p>
                    )}
                    <Link to={`/clients/${form.user_id}`} className="btn btn-primary btn-sm" onClick={onClose}>
                      <Sparkles size={14} /> Μετάβαση στο προφίλ πελάτη
                    </Link>
                  </div>
                ) : (
                  <>
                    {trialBlocks.length > 0 && (
                      <div className="cb-trial-blocks compact">
                        {trialBlocks.map((block) => (
                          <div key={block.membership_id} className="cb-trial-block compact">
                            <FlaskConical size={16} />
                            <span>{block.message}</span>
                          </div>
                        ))}
                      </div>
                    )}
                    <div className="cb-service-grid">
                      {bookingOptions.map((option) => {
                        const img = mediaUrl(option.image_url);
                        return (
                          <button
                            key={`${option.service_id}-${option.membership_id}`}
                            type="button"
                            className="cb-service-card"
                            onClick={() => pickBookingOption(option)}
                          >
                            <div className={`cb-service-visual ${img ? 'has-photo' : 'has-icon'}`}>
                              {img ? (
                                <img src={img} alt="" className="cb-service-photo" />
                              ) : (
                                <div className="cb-service-icon-wrap">
                                  <ServiceIcon service={{ ...option, category: option.service_category }} size={36} />
                                </div>
                              )}
                            </div>
                            <div className="cb-service-text">
                              <div className="cb-service-name">{option.service_name}</div>
                              <div className="cb-service-meta">
                                {option.duration_mins} λεπτά
                                {option.package_label && option.package_label !== option.service_name
                                  && ` · ${option.package_label}`}
                              </div>
                              <div className="cb-package-badge package">
                                <CreditCard size={12} /> {formatSessions(option)}
                              </div>
                            </div>
                          </button>
                        );
                      })}
                    </div>
                  </>
                )}
              </section>
            )}

            {step === 3 && selectedOption && (
              <>
                <div className="cb-selected-client cb-selected-client-compact">
                  <div className={`cb-service-visual small ${mediaUrl(selectedOption.image_url) ? 'has-photo' : 'has-icon'}`}>
                    {mediaUrl(selectedOption.image_url) ? (
                      <img src={mediaUrl(selectedOption.image_url)} alt="" className="cb-service-photo" />
                    ) : (
                      <div className="cb-service-icon-wrap">
                        <ServiceIcon service={{ ...selectedOption, category: selectedOption.service_category }} size={28} />
                      </div>
                    )}
                  </div>
                  <div className="cb-selected-info">
                    <div className="cb-selected-name">{selectedOption.service_name}</div>
                    <div className="cb-selected-meta">
                      {formatSessions(selectedOption)}
                    </div>
                  </div>
                  <Check size={18} className="cb-selected-check" aria-hidden />
                  <button type="button" className="cb-text-btn" onClick={changePackage}>
                    Αλλαγή
                  </button>
                </div>

                {locations.length > 1 && (
                  <section className="cb-section">
                    <div className="cb-section-label">
                      <MapPin size={16} /> Τοποθεσία
                    </div>
                    <div className="cb-location-grid">
                      {locations.map((loc) => (
                        <button
                          key={loc.id}
                          type="button"
                          className={`cb-location-pill ${String(form.location_id) === String(loc.id) ? 'active' : ''}`}
                          onClick={() => pickLocation(loc.id)}
                        >
                          {loc.name}
                        </button>
                      ))}
                    </div>
                  </section>
                )}

                {locations.length === 1 && (
                  <div className="cb-location-chip">
                    <MapPin size={15} />
                    <span>{locations[0].name}</span>
                  </div>
                )}

                <section className="cb-section cb-section-row">
                  <div className="cb-date-wrap">
                    <div className="cb-section-label">
                      <Calendar size={16} /> Ημερομηνία
                    </div>
                    <input
                      className="cb-date-input"
                      type="date"
                      value={form.date}
                      onChange={e => pickDate(e.target.value)}
                      required
                    />
                  </div>
                </section>

                {(locations.length <= 1 || form.location_id) && (
                  <section className="cb-section">
                    <div className="cb-section-label">Ώρα</div>
                    {slotsLoading ? (
                      <div className="cb-empty-inline">Φόρτωση ωρών...</div>
                    ) : slots.length === 0 ? (
                      <div className="cb-empty-inline">Δεν υπάρχουν διαθέσιμες ώρες</div>
                    ) : (
                      <div className="cb-time-grid">
                        {slots.map(s => {
                          const disabled = s.is_full && !form.force;
                          const active = form.time === s.time;
                          return (
                            <button
                              key={s.time}
                              type="button"
                              disabled={disabled}
                              className={`cb-time-pill ${active ? 'active' : ''} ${s.is_full ? 'full' : ''}`}
                              onClick={() => pickTime(s.time)}
                            >
                              <span className="cb-time-main">{s.time}</span>
                              {s.label && <span className="cb-time-sub">{s.label}</span>}
                              {s.is_full && <span className="cb-time-badge">Πλήρες</span>}
                              {!s.is_full && s.booked_count != null && (
                                <span className="cb-time-sub">{s.booked_count}/{s.capacity}</span>
                              )}
                            </button>
                          );
                        })}
                      </div>
                    )}
                  </section>
                )}

                {form.time && (hideStaffSelection ? serviceStaff.length > 0 : staffOptions.length > 0) && (
                  <section className="cb-section">
                    <div className="cb-section-label">Γυμναστ{hideStaffSelection ? 'ές' : 'ής'}</div>
                    {hideStaffSelection && (
                      <p className="cb-bookable-hint" style={{ marginTop: 0, marginBottom: 10 }}>
                        Αυτόματη ανάθεση — ξετίκαρε όσους δεν θέλεις. Κλικ σε όνομα για συγκεκριμένο γυμναστή.
                      </p>
                    )}
                    <div className="cb-staff-row">
                      {(hideStaffSelection ? serviceStaff : staffOptions).map((s) => {
                        const excluded = excludedStaffIds.map(String).includes(String(s.id));
                        const manual = String(form.staff_id) === String(s.id);
                        const active = hideStaffSelection ? manual : String(form.staff_id) === String(s.id);
                        return (
                          <div
                            key={s.id}
                            className={`cb-staff-pick ${excluded ? 'excluded' : ''} ${active ? 'active' : ''}`}
                          >
                            {hideStaffSelection && (
                              <label className="cb-staff-check-label">
                                <input
                                  type="checkbox"
                                  checked={!excluded}
                                  onChange={() => toggleStaffInPool(s.id)}
                                />
                              </label>
                            )}
                            <button
                              type="button"
                              className={`cb-staff-card ${active ? 'active' : ''}`}
                              onClick={() => (
                                hideStaffSelection
                                  ? pickManualStaff(s.id)
                                  : setForm(prev => ({ ...prev, staff_id: s.id }))
                              )}
                            >
                              <Avatar
                                name={s.full_name}
                                image={s.avatar_url}
                                color={s.color_hex}
                                size={52}
                              />
                              <div className="cb-staff-name">{s.full_name}</div>
                              {s.role && <div className="cb-staff-role">{s.role}</div>}
                              {active && <Check size={16} className="cb-staff-check" />}
                            </button>
                          </div>
                        );
                      })}
                    </div>
                    {hideStaffSelection && form.staff_id && (
                      <button
                        type="button"
                        className="cb-text-btn"
                        style={{ marginTop: 8 }}
                        onClick={() => setForm(prev => ({ ...prev, staff_id: '' }))}
                      >
                        Επιστροφή σε αυτόματη ανάθεση
                      </button>
                    )}
                  </section>
                )}

                {!hasSessionsLeft && form.time && (
                  <div className="cb-bookable-banner">
                    <CreditCard size={18} />
                    <span>Ο πελάτης δεν έχει διαθέσιμες συνεδρίες για αυτό το πακέτο.</span>
                  </div>
                )}

                <section className="cb-options">
                  <button
                    type="button"
                    className={`cb-option ${form.force ? 'on' : ''}`}
                    onClick={() => setForm(prev => ({ ...prev, force: !prev.force }))}
                  >
                    <Zap size={18} />
                    <span>Force (υπέρβαση χωρητικότητας)</span>
                  </button>
                </section>

                {selectedClient && form.time && (
                  <div className="cb-summary">
                    <Shield size={16} />
                    <span>
                      {selectedClient.full_name} · {selectedOption.service_name} · {form.date} {form.time}
                      {form.is_trial && ' · Δοκιμαστικό (χωρίς χρέωση συνεδρίας)'}
                    </span>
                  </div>
                )}

                <div className="cb-footer">
                  <button type="button" className="btn btn-secondary" onClick={onClose}>Ακύρωση</button>
                  <button type="submit" className="btn btn-primary" disabled={!canSubmit}>
                    {submitting ? 'Δημιουργία...' : 'Δημιουργία κράτησης'}
                  </button>
                </div>
              </>
            )}
          </form>
        )}
      </div>
    </div>
  );
}
