export const EMPTY_AUDIENCE = {
  audience: 'clients',
  location_id: '',
  service_id: '',
  staff_kind: '',
  client_scope: 'all',
};

const CLIENT_SCOPES = [
  { value: 'all', label: 'Όλοι οι πελάτες' },
  { value: 'active', label: 'Μόνο ενεργοί' },
  { value: 'active_members', label: 'Με ενεργό πακέτο' },
  { value: 'at_risk', label: 'Σε κίνδυνο (30 μέρες χωρίς κράτηση)' },
  { value: 'no_active_package', label: 'Χωρίς ενεργό πακέτο' },
];

const STAFF_KINDS = [
  { value: '', label: 'Όλο το προσωπικό' },
  { value: 'trainer', label: 'Μόνο γυμναστές' },
  { value: 'nutritionist', label: 'Μόνο διατροφολόγοι' },
  { value: 'physiotherapist', label: 'Μόνο φυσιοθεραπευτές' },
];

export function audienceQuery(value) {
  const params = new URLSearchParams();
  params.set('audience', value.audience || 'clients');
  if (value.location_id) params.set('location_id', value.location_id);
  if (value.service_id) params.set('service_id', value.service_id);
  if (value.audience === 'staff' && value.staff_kind) params.set('staff_kind', value.staff_kind);
  if (value.audience !== 'staff') params.set('client_scope', value.client_scope || 'all');
  return params.toString();
}

export function audiencePayload(value) {
  return {
    audience: value.audience || 'clients',
    location_id: value.location_id || undefined,
    service_id: value.service_id || undefined,
    staff_kind: value.audience === 'staff' ? (value.staff_kind || undefined) : undefined,
    client_scope: value.audience === 'staff' ? undefined : (value.client_scope || 'all'),
  };
}

export function describeAudience(value, locations = [], services = []) {
  const place = locations.find((l) => l.id === value.location_id)?.name;
  const service = services.find((s) => s.id === value.service_id)?.name;
  const bits = [];
  if (value.audience === 'staff') {
    const kind = STAFF_KINDS.find((k) => k.value === (value.staff_kind || ''))?.label || 'Προσωπικό';
    bits.push(kind);
  } else {
    const scope = CLIENT_SCOPES.find((s) => s.value === (value.client_scope || 'all'))?.label || 'Πελάτες';
    bits.push(scope);
  }
  if (place) bits.push(place);
  if (service) bits.push(service);
  return bits.join(' · ');
}

export function campaignFilterLabel(campaign, locations = [], services = []) {
  let extra = {};
  try { extra = JSON.parse(campaign.filter_value || '{}'); } catch { extra = {}; }
  if (campaign.filter_type === 'staff' || extra.staff_kind || extra.location_id || extra.service_id) {
    return describeAudience({
      audience: campaign.filter_type === 'staff' ? 'staff' : 'clients',
      client_scope: campaign.filter_type === 'staff' ? 'all' : (campaign.filter_type || 'all'),
      location_id: extra.location_id || '',
      service_id: extra.service_id || '',
      staff_kind: extra.staff_kind || '',
    }, locations, services);
  }
  const known = {
    all: 'Όλοι οι ενεργοί πελάτες',
    active: 'Μόνο ενεργοί',
    active_members: 'Πελάτες με ενεργό πακέτο',
    at_risk: 'Πελάτες σε κίνδυνο',
    no_active_package: 'Πελάτες χωρίς ενεργό πακέτο',
    service: 'Συγκεκριμένη υπηρεσία',
  };
  return known[campaign.filter_type] || campaign.filter_type || 'Πελάτες';
}

export default function AudienceFields({ value, onChange, locations, services }) {
  const set = (patch) => onChange({ ...value, ...patch });
  const staff = value.audience === 'staff';

  return (
    <>
      <div className="form-group">
        <label className="form-label">Σε ποιους</label>
        <select className="form-input" value={value.audience} onChange={(e) => set({ audience: e.target.value })}>
          <option value="clients">Πελάτες</option>
          <option value="staff">Προσωπικό</option>
        </select>
      </div>
      <div className="form-group">
        <label className="form-label">Κατάστημα</label>
        <select className="form-input" value={value.location_id} onChange={(e) => set({ location_id: e.target.value })}>
          <option value="">Όλα τα καταστήματα</option>
          {locations.map((loc) => <option key={loc.id} value={loc.id}>{loc.name}</option>)}
        </select>
      </div>
      <div className="form-group">
        <label className="form-label">Υπηρεσία</label>
        <select className="form-input" value={value.service_id} onChange={(e) => set({ service_id: e.target.value })}>
          <option value="">Όλες οι υπηρεσίες</option>
          {services.map((svc) => <option key={svc.id} value={svc.id}>{svc.name}</option>)}
        </select>
      </div>
      {staff ? (
        <div className="form-group">
          <label className="form-label">Ρόλος</label>
          <select className="form-input" value={value.staff_kind} onChange={(e) => set({ staff_kind: e.target.value })}>
            {STAFF_KINDS.map((kind) => <option key={kind.value || 'all'} value={kind.value}>{kind.label}</option>)}
          </select>
        </div>
      ) : (
        <div className="form-group">
          <label className="form-label">Ομάδα πελατών</label>
          <select className="form-input" value={value.client_scope} onChange={(e) => set({ client_scope: e.target.value })}>
            {CLIENT_SCOPES.map((scope) => <option key={scope.value} value={scope.value}>{scope.label}</option>)}
          </select>
        </div>
      )}
      <div className="text-muted" style={{ fontSize: '0.78rem', marginTop: -8, marginBottom: 14 }}>
        Μπορείς να συνδυάσεις κατάστημα, υπηρεσία και ρόλο. Π.χ. μόνο οι γυμναστές ενός καταστήματος, ή οι πελάτες που κάνουν μία υπηρεσία εκεί.
      </div>
    </>
  );
}
