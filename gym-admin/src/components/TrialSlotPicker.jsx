import { useEffect, useRef, useState } from 'react';
import api from '../api/client';

const WEEKDAYS = ['Κυρ', 'Δευ', 'Τρί', 'Τετ', 'Πέμ', 'Παρ', 'Σάβ'];
const MONTHS = ['Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μαΐ', 'Ιουν', 'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ'];

function dayParts(date) {
  const d = new Date(`${date}T12:00:00`);
  return { main: `${d.getDate()} ${MONTHS[d.getMonth()]}`, week: WEEKDAYS[d.getDay()] };
}

function isBookable(slot) {
  return !slot.is_full && (slot.available_staff?.length > 0);
}

function hhmm(value) {
  return String(value || '').slice(0, 5);
}

export default function TrialSlotPicker({
  serviceId,
  locationId,
  locationRequired = false,
  date,
  time,
  suggestedDate = '',
  suggestedTime = '',
  autoPick = true,
  excludeBookingId = '',
  onChange,
}) {
  const [dates, setDates] = useState([]);
  const [slots, setSlots] = useState([]);
  const [datesLoading, setDatesLoading] = useState(false);
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [dayMessage, setDayMessage] = useState('');
  const [error, setError] = useState('');
  const dateRef = useRef(date);
  const onChangeRef = useRef(onChange);
  dateRef.current = date;
  onChangeRef.current = onChange;

  useEffect(() => {
    let cancel = false;
    async function loadDates() {
      if (!serviceId || (locationRequired && !locationId)) {
        setDates([]);
        setSlots([]);
        return;
      }
      setDatesLoading(true);
      setError('');
      try {
        const params = { service_id: serviceId, days: 21 };
        if (locationId) params.location_id = locationId;
        const r = await api.get('/client-admin/booking-available-dates', { params });
        if (cancel) return;
        const list = r.data.dates || [];
        setDates(list);
        if (!autoPick) return;
        const selectable = list.filter(d => d.selectable);
        const current = dateRef.current;
        const hinted = (suggestedDate || '').slice(0, 10);
        const preferred = [current, hinted].find(d => d && selectable.some(s => s.date === d));
        const next = preferred || selectable[0]?.date || '';
        if (next !== current) onChangeRef.current({ date: next, time: '' });
      } catch {
        if (!cancel) {
          setDates([]);
          setError('Δεν φορτώθηκαν οι διαθέσιμες ημέρες');
        }
      } finally {
        if (!cancel) setDatesLoading(false);
      }
    }
    loadDates();
    return () => { cancel = true; };
    // Reload when the class or the store changes, not on every day click.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [serviceId, locationId, locationRequired, autoPick]);

  useEffect(() => {
    let cancel = false;
    async function loadSlots() {
      if (!serviceId || !date || (locationRequired && !locationId)) {
        setSlots([]);
        setDayMessage('');
        return;
      }
      setSlotsLoading(true);
      const requested = date;
      try {
        const params = { service_id: serviceId, date };
        if (locationId) params.location_id = locationId;
        if (excludeBookingId) params.exclude_booking_id = excludeBookingId;
        const r = await api.get('/client-admin/booking-slots', { params });
        if (cancel || dateRef.current !== requested) return;
        const list = r.data.slots || [];
        setSlots(list);
        setDayMessage(r.data.message || '');
        if (!autoPick) return;
        const open = list.filter(isBookable);
        const suggested = hhmm(suggestedTime);
        const current = hhmm(time);
        const onSuggestedDay = !suggestedDate || requested === suggestedDate.slice(0, 10);
        if (onSuggestedDay && suggested && open.some(s => hhmm(s.time) === suggested)) {
          if (current !== suggested) onChangeRef.current({ date: requested, time: suggested });
        } else if (current && !open.some(s => hhmm(s.time) === current)) {
          onChangeRef.current({ date: requested, time: '' });
        }
      } catch {
        if (!cancel && dateRef.current === requested) {
          setSlots([]);
          setDayMessage('Δεν φορτώθηκαν οι ώρες');
        }
      } finally {
        if (!cancel) setSlotsLoading(false);
      }
    }
    loadSlots();
    return () => { cancel = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [serviceId, locationId, date, locationRequired, excludeBookingId, autoPick]);

  if (!serviceId) {
    return <div className="text-muted">Επίλεξε υπηρεσία για να δεις ποιες μέρες και ώρες δέχονται δοκιμαστικό.</div>;
  }
  if (locationRequired && !locationId) {
    return <div className="text-muted">Διάλεξε κατάστημα για να δεις τις ώρες αυτού του μαθήματος.</div>;
  }

  const hintedDay = (suggestedDate || '').slice(0, 10);
  const hintedDayInfo = dates.find(d => d.date === hintedDay);
  const suggested = hhmm(suggestedTime);
  const suggestedMissing = Boolean(
    suggested
    && date
    && (!suggestedDate || date === suggestedDate.slice(0, 10))
    && !slotsLoading
    && !slots.some(s => isBookable(s) && hhmm(s.time) === suggested),
  );

  return (
    <div>
      <div className="cb-section-label">Διαθέσιμες ημέρες</div>
      {datesLoading ? (
        <div className="text-muted">Φόρτωση ημερών...</div>
      ) : error ? (
        <div className="text-muted">{error}</div>
      ) : dates.length === 0 ? (
        <div className="text-muted">Δεν βρέθηκαν ημέρες με πρόγραμμα για αυτή την υπηρεσία.</div>
      ) : (
        <div className="cb-day-row">
          {dates.map(d => {
            const parts = dayParts(d.date);
            const active = date === d.date;
            return (
              <button
                key={d.date}
                type="button"
                disabled={!d.selectable}
                title={!d.selectable ? (d.message || 'Μη διαθέσιμο') : `${d.slot_count || 0} ώρες`}
                className={`cb-day-pill ${active ? 'active' : ''}`}
                onClick={() => d.selectable && onChange({ date: d.date, time: '' })}
              >
                <span className="cb-day-main">{parts.main}</span>
                <span className="cb-day-week">{parts.week}</span>
              </button>
            );
          })}
        </div>
      )}
      {hintedDayInfo && !hintedDayInfo.selectable && !datesLoading && (
        <div className="text-muted" style={{ marginTop: 8, color: '#b45309' }}>
          Η προτεινόμενη μέρα {dayParts(hintedDay).main} δεν είναι ανοιχτή{hintedDayInfo.message ? `: ${hintedDayInfo.message}` : ''}. Διάλεξε άλλη μέρα.
        </div>
      )}

      <div className="cb-section-label" style={{ marginTop: 14 }}>Ώρες αυτής της ημέρας</div>
      {suggestedMissing && (
        <div className="text-muted" style={{ marginBottom: 8, color: '#b45309' }}>
          Η προτεινόμενη ώρα {suggested} δεν είναι στο πρόγραμμα. Διάλεξε μία από τις ανοιχτές ώρες.
        </div>
      )}
      {!date ? (
        <div className="text-muted">Δεν υπάρχει διαθέσιμη ημέρα.</div>
      ) : slotsLoading ? (
        <div className="text-muted">Φόρτωση ωρών...</div>
      ) : slots.filter(isBookable).length === 0 ? (
        <div className="text-muted">{dayMessage || 'Δεν υπάρχουν ελεύθερες ώρες αυτή την ημέρα.'}</div>
      ) : (
        <div className="cb-time-grid">
          {slots.map(s => {
            const open = isBookable(s);
            const active = hhmm(time) === hhmm(s.time);
            return (
              <button
                key={s.time}
                type="button"
                disabled={!open}
                className={`cb-time-pill ${active ? 'active' : ''} ${s.is_full ? 'full' : ''}`}
                onClick={() => open && onChange({ date, time: hhmm(s.time) })}
              >
                <span className="cb-time-main">{hhmm(s.time)}</span>
                {s.is_full && <span className="cb-time-badge">Πλήρες</span>}
                {!s.is_full && s.booked_count != null && s.capacity != null && (
                  <span className="cb-time-sub">{s.booked_count}/{s.capacity}</span>
                )}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
