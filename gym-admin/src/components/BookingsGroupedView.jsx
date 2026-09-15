import { Dumbbell, Check, MapPin, Pencil, QrCode, Trash2, User, Users, X } from 'lucide-react';
import Avatar from './ui/Avatar';
import { hashColor, initials, mediaUrl } from '../utils/media';
import { groupBookingsBySlot, slotKey } from '../utils/groupBookingsBySlot';
import { filterGymBookings, filterGymServices, isGymService } from '../utils/gym_services';

function parseTime(startsAt) {
  const d = new Date(startsAt);
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function groupKey(booking, groupBy) {
  if (groupBy === 'service') return booking.service_id;
  if (groupBy === 'staff') return booking.staff_id;
  return booking.room_name || '__none__';
}

function groupMeta(booking, groupBy, catalogs) {
  if (groupBy === 'service') {
    const svc = catalogs.services?.find(s => s.id === booking.service_id);
    return {
      id: booking.service_id,
      label: booking.service_name,
      image: booking.service_image_url || svc?.image_url,
      subtitle: booking.schedule_label || `${booking.duration_mins} λεπτά`,
      accent: '#76C043',
    };
  }
  if (groupBy === 'staff') {
    const member = catalogs.staff?.find(s => s.id === booking.staff_id);
    return {
      id: booking.staff_id,
      label: booking.staff_name,
      image: booking.staff_avatar_url || member?.avatar_url,
      subtitle: member?.role || 'Γυμναστής',
      accent: booking.color_hex || member?.color_hex || '#607D8B',
    };
  }
  const room = booking.room_name || 'Χωρίς αίθουσα';
  return {
    id: booking.room_name || '__none__',
    label: room,
    image: null,
    subtitle: 'Αίθουσα / χώρος',
    accent: hashColor(room),
  };
}

function buildGroups(bookings, groupBy, catalogs) {
  const gymBookings = filterGymBookings(bookings);
  const gymCatalogs = {
    ...catalogs,
    services: filterGymServices(catalogs.services || []),
  };
  const map = new Map();
  for (const b of gymBookings) {
    const key = groupKey(b, groupBy);
    if (!map.has(key)) {
      map.set(key, { ...groupMeta(b, groupBy, gymCatalogs), bookings: [] });
    }
    map.get(key).bookings.push(b);
  }
  return [...map.values()]
    .map(g => ({
      ...g,
      bookings: g.bookings.sort((a, b) => String(a.starts_at).localeCompare(String(b.starts_at))),
    }))
    .sort((a, b) => a.label.localeCompare(b.label, 'el'));
}

function buildFilterOptions(bookings, groupBy, catalogs) {
  const gymBookings = filterGymBookings(bookings);
  const gymServices = filterGymServices(catalogs.services || []);
  const groups = buildGroups(gymBookings, groupBy, { ...catalogs, services: gymServices });
  if (groupBy === 'service') {
    const bookedIds = new Set(gymBookings.map(b => String(b.service_id)));
    const extras = gymServices
      .filter(s => !bookedIds.has(String(s.id)))
      .map(s => ({
        id: s.id,
        label: s.name,
        image: s.image_url,
        subtitle: 'Χωρίς κρατήσεις',
        accent: '#94a3b8',
        bookings: [],
      }));
    return [...groups, ...extras];
  }
  if (groupBy === 'staff') {
    const bookedIds = new Set(bookings.map(b => b.staff_id));
    const extras = (catalogs.staff || [])
      .filter(s => !bookedIds.has(s.id))
      .map(s => ({
        id: s.id,
        label: s.full_name,
        image: s.avatar_url,
        subtitle: s.role || 'Γυμναστής',
        accent: s.color_hex || '#607D8B',
        bookings: [],
      }));
    return [...groups, ...extras];
  }
  return groups;
}

function EntityAvatar({ groupBy, item, size = 48, large = false }) {
  const dim = large ? 72 : size;
  const img = mediaUrl(item.image);
  const style = {
    width: dim,
    height: dim,
    borderRadius: groupBy === 'staff' ? '50%' : large ? 16 : 12,
    objectFit: 'cover',
    flexShrink: 0,
  };

  if (img) {
    return <img src={img} alt={item.label} style={style} />;
  }

  const bg = groupBy === 'room'
    ? `linear-gradient(135deg, ${item.accent}, ${hashColor(item.label, 45, 35)})`
    : `linear-gradient(135deg, ${item.accent}, ${hashColor(item.label, 50, 55)})`;

  const Icon = groupBy === 'room' ? MapPin : groupBy === 'staff' ? User : Dumbbell;

  return (
    <div
      style={{
        ...style,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: bg,
        color: '#fff',
        fontWeight: 800,
        fontSize: large ? '1.5rem' : '1rem',
      }}
    >
      {groupBy === 'staff' || groupBy === 'service' ? initials(item.label) : <Icon size={large ? 28 : 20} />}
    </div>
  );
}

function LocationBadge({ name, prominent = false }) {
  if (!name) return null;
  return (
    <span className={`bk-location-badge ${prominent ? 'prominent' : ''}`}>
      <MapPin size={prominent ? 13 : 12} />
      {name}
    </span>
  );
}

function resolveBookingLocation(booking, locations = []) {
  if (booking?.location_name) return booking.location_name;
  if (booking?.location_id) {
    const found = locations.find((l) => String(l.id) === String(booking.location_id));
    if (found?.name) return found.name;
  }
  if (locations.length === 1) return locations[0].name;
  return null;
}

function needsAttendanceConfirm(booking) {
  if (!booking || booking.attendance_confirmed) return false;
  if (['cancelled', 'no_show'].includes(booking.status)) return false;
  return new Date(booking.starts_at) < new Date();
}

function ParticipantChip({ booking, onEdit, onDelete, onConfirmAttendance, confirmingId }) {
  const showAttendance = needsAttendanceConfirm(booking) && onConfirmAttendance;
  const busy = confirmingId === booking.id;

  return (
    <div className="bk-participant-chip">
      <Avatar name={booking.user_name} image={booking.user_avatar_url} size={34} />
      <span className="bk-participant-chip__name" title={booking.user_name}>
        {booking.user_name}
      </span>
      {booking.is_trial ? <span className="badge badge-yellow bk-participant-chip__badge">Δοκ.</span> : null}
      {booking.attendance_confirmed ? (
        <span className="badge badge-green bk-participant-chip__badge" title="Παρουσία">
          <QrCode size={10} />
        </span>
      ) : null}
      {booking.health_calories_kcal != null && (
        <span className="bk-participant-chip__meta" title="Θερμίδες">
          🔥 {booking.health_calories_kcal}
        </span>
      )}
      <div className="bk-participant-chip__actions">
        {showAttendance && (
          <>
            <button
              type="button"
              className="btn btn-primary btn-sm bk-participant-chip__btn"
              disabled={busy}
              onClick={() => onConfirmAttendance(booking, true)}
              title="Επιβεβαίωση παρουσίας"
            >
              <Check size={13} />
            </button>
            <button
              type="button"
              className="btn btn-secondary btn-sm bk-participant-chip__btn"
              disabled={busy}
              onClick={() => onConfirmAttendance(booking, false)}
              title="Απόντας"
            >
              <X size={13} />
            </button>
          </>
        )}
        <button
          type="button"
          className="btn btn-secondary btn-sm bk-participant-chip__btn"
          onClick={() => onEdit(booking)}
          title="Επεξεργασία"
        >
          <Pencil size={13} />
        </button>
        {onDelete && (
          <button
            type="button"
            className="btn btn-danger btn-sm bk-participant-chip__btn"
            onClick={() => onDelete(booking)}
            title="Διαγραφή"
          >
            <Trash2 size={13} />
          </button>
        )}
      </div>
    </div>
  );
}

function SlotBlock({ slot, groupBy, onEdit, onDelete, locationName, onConfirmAttendance, confirmingId }) {
  const time = parseTime(slot.starts_at);
  const loc = locationName || slot.location_name;
  const metaParts = [];
  if (groupBy !== 'service') metaParts.push(slot.service_name);
  if (groupBy !== 'staff') metaParts.push(slot.staff_name);
  if (groupBy !== 'room' && slot.room_name) metaParts.push(slot.room_name);
  if (slot.schedule_label) metaParts.push(slot.schedule_label);

  return (
    <div className={`bk-slot-block ${loc ? 'has-location' : ''}`}>
      <div className="bk-slot-header">
        <div className="bk-slot-time-col">
          <div className="bk-booking-time">{time}</div>
        </div>
        <div className="bk-slot-header-main">
          {(loc || metaParts.length > 0) && (
            <div className="bk-slot-meta-row">
              {loc && <LocationBadge name={loc} prominent />}
              {metaParts.length > 0 && (
                <div className="bk-booking-meta">{metaParts.join(' · ')}</div>
              )}
            </div>
          )}
          <div className="bk-slot-count">
            {slot.bookings.length} {slot.bookings.length === 1 ? 'άτομο' : 'άτομα'}
          </div>
        </div>
      </div>
      <div className="bk-slot-participants">
        {slot.bookings.map((b) => (
          <ParticipantChip
            key={b.id}
            booking={b}
            onEdit={onEdit}
            onDelete={onDelete}
            onConfirmAttendance={onConfirmAttendance}
            confirmingId={confirmingId}
          />
        ))}
      </div>
    </div>
  );
}

export default function BookingsGroupedView({
  bookings,
  waitlist = [],
  catalogs = {},
  groupBy,
  onGroupByChange,
  filterId,
  onFilterChange,
  onEdit,
  onDelete,
  onConvertWaitlist,
  onRemoveWaitlist,
  onConfirmAttendance,
  confirmingId,
}) {
  const locationList = catalogs.locations || [];
  const gymBookings = filterGymBookings(bookings).map((b) => ({
    ...b,
    location_name: resolveBookingLocation(b, locationList),
  }));
  const gymWaitlist = waitlist.filter((w) => isGymService({ name: w.service_name, category: w.service_category }));
  const gymCatalogs = { ...catalogs, services: filterGymServices(catalogs.services || []) };
  const groups = buildGroups(gymBookings, groupBy, gymCatalogs);
  const filterOptions = buildFilterOptions(gymBookings, groupBy, gymCatalogs);
  const activeGroup = filterId
    ? filterOptions.find(g => String(g.id) === String(filterId))
    : null;
  const visibleGroups = activeGroup ? [activeGroup] : groups.filter(g => g.bookings.length > 0);

  const groupLabels = {
    service: 'Υπηρεσία',
    staff: 'Γυμναστής',
    room: 'Αίθουσα',
  };

  return (
    <div className="bk-grouped">
      <div className="bk-group-tabs">
        {(['service', 'staff', 'room']).map(key => (
          <button
            key={key}
            type="button"
            className={`bk-group-tab ${groupBy === key ? 'active' : ''}`}
            onClick={() => onGroupByChange(key)}
          >
            {key === 'service' && <Dumbbell size={16} />}
            {key === 'staff' && <User size={16} />}
            {key === 'room' && <MapPin size={16} />}
            {groupLabels[key]}
          </button>
        ))}
      </div>

      <div className="bk-filter-scroll">
        <button
          type="button"
          className={`bk-filter-chip ${!filterId ? 'active' : ''}`}
          onClick={() => onFilterChange(null)}
        >
          <div className="bk-filter-chip-icon all">
            <Users size={18} />
          </div>
          <div>
            <div className="bk-filter-chip-label">Όλα</div>
            <div className="bk-filter-chip-sub">{gymBookings.length} κρατήσεις</div>
          </div>
        </button>
        {filterOptions.map(item => (
          <button
            key={item.id}
            type="button"
            className={`bk-filter-chip ${String(filterId) === String(item.id) ? 'active' : ''} ${!item.bookings.length ? 'empty' : ''}`}
            onClick={() => onFilterChange(item.id)}
          >
            <EntityAvatar groupBy={groupBy} item={item} size={44} />
            <div>
              <div className="bk-filter-chip-label">{item.label}</div>
              <div className="bk-filter-chip-sub">
                {item.bookings.length
                  ? `${item.bookings.length} ${item.bookings.length === 1 ? 'κράτηση' : 'κρατήσεις'}`
                  : 'Καμία σήμερα'}
              </div>
            </div>
          </button>
        ))}
      </div>

      {activeGroup && (
        <div className="bk-hero">
          <EntityAvatar groupBy={groupBy} item={activeGroup} large />
          <div>
            <div className="bk-hero-title">{activeGroup.label}</div>
            <div className="bk-hero-sub">
              {activeGroup.bookings.length} κρατήσεις σήμερα
              {activeGroup.subtitle ? ` · ${activeGroup.subtitle}` : ''}
            </div>
          </div>
        </div>
      )}

      {visibleGroups.length === 0 && (
        <div className="bk-empty">Δεν υπάρχουν κρατήσεις για αυτή την ημέρα.</div>
      )}

      {visibleGroups.map(group => (
        <section key={group.id} className="bk-group-section">
          {!activeGroup && (
            <div className="bk-group-header">
              <EntityAvatar groupBy={groupBy} item={group} size={52} />
              <div>
                <div className="bk-group-title">{group.label}</div>
                <div className="bk-group-sub">
                  {group.bookings.length} κρατήσεις
                  {group.subtitle ? ` · ${group.subtitle}` : ''}
                </div>
              </div>
            </div>
          )}
          <div className="bk-group-list">
            {groupBookingsBySlot(group.bookings).map((slot) => {
              const slotLocation = slot.location_name
                || resolveBookingLocation(slot.bookings[0], locationList);
              return (
              <SlotBlock
                key={slotKey(slot)}
                slot={{ ...slot, location_name: slotLocation }}
                groupBy={groupBy}
                onEdit={onEdit}
                onDelete={onDelete}
                locationName={slotLocation}
                onConfirmAttendance={onConfirmAttendance}
                confirmingId={confirmingId}
              />
              );
            })}
          </div>
        </section>
      ))}

      {gymWaitlist.length > 0 && (
        <section className="bk-waitlist-section">
          <div className="bk-group-title" style={{ marginBottom: 12 }}>Λίστα αναμονής ({gymWaitlist.length})</div>
          {gymWaitlist.map(w => (
            <div key={w.id} className="bk-waitlist-row">
              <EntityAvatar
                groupBy="service"
                item={{
                  label: w.service_name,
                  image: w.service_image_url,
                  accent: '#f59e0b',
                }}
                size={40}
              />
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 700 }}>{parseTime(w.starts_at)} — {w.service_name}</div>
                <div className="text-muted">{w.user_name} · θέση #{w.position}</div>
              </div>
              <span className={`badge ${w.status === 'offered' ? 'badge-green' : 'badge-yellow'}`}>
                {w.status === 'offered' ? 'Προσφέρθηκε' : 'Αναμονή'}
              </span>
              <button type="button" className="btn btn-primary btn-sm" onClick={() => onConvertWaitlist(w.id)}>
                Αποδοχή
              </button>
              {onRemoveWaitlist && (
                <button type="button" className="btn btn-danger btn-sm" onClick={() => onRemoveWaitlist(w.id)}>
                  Απόρριψη
                </button>
              )}
            </div>
          ))}
        </section>
      )}
    </div>
  );
}
