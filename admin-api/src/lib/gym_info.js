const { parseOpeningHours } = require('./slots');
const { listLocations, isMultiLocationEnabled } = require('./locations');
const { GYM_STAFF_WHERE_ALIAS } = require('./gym_staff');

function mapOpeningHours(raw) {
  return parseOpeningHours(raw);
}

async function buildGymInfoPayload(dbConn, bizId) {
  const [[biz]] = await dbConn.query(
    'SELECT id, name, slug FROM businesses WHERE id = ? AND is_active = 1',
    [bizId],
  );
  if (!biz) return null;

  const [[cfg]] = await dbConn.query(
    `SELECT app_name, logo_url, gym_address, gym_phone, gym_email,
            opening_hours, owner_name, owner_phone, feature_nutrition
     FROM business_configs WHERE business_id = ?`,
    [bizId],
  );

  const multiLocation = await isMultiLocationEnabled(dbConn, bizId);
  const locations = await listLocations(dbConn, bizId, { activeOnly: true });

  const [roomRows] = await dbConn.query(
    `SELECT id, location_id, name, short_info, description, photo_url, sort_order
     FROM rooms
     WHERE business_id = ? AND is_active = 1
     ORDER BY sort_order, name`,
    [bizId],
  );

  const roomsByLocation = new Map();
  for (const room of roomRows) {
    const key = room.location_id || '__default__';
    if (!roomsByLocation.has(key)) roomsByLocation.set(key, []);
    roomsByLocation.get(key).push({
      id: room.id,
      name: room.name,
      short_info: room.short_info || room.description || null,
      photo_url: room.photo_url || null,
    });
  }

  const mappedLocations = locations.map((loc) => ({
    id: loc.id,
    name: loc.name,
    slug: loc.slug,
    address: loc.address || null,
    city: loc.city || null,
    phone: loc.phone || null,
    email: loc.email || null,
    opening_hours: mapOpeningHours(loc.opening_hours),
    rooms: roomsByLocation.get(loc.id) || [],
  }));

  const orphanRooms = roomsByLocation.get('__default__') || [];
  if (orphanRooms.length && mappedLocations.length === 1) {
    mappedLocations[0].rooms = [...mappedLocations[0].rooms, ...orphanRooms];
  } else if (orphanRooms.length && !mappedLocations.length) {
    mappedLocations.push({
      id: null,
      name: cfg?.app_name || biz.name,
      slug: null,
      address: cfg?.gym_address || null,
      city: null,
      phone: cfg?.gym_phone || null,
      email: cfg?.gym_email || null,
      opening_hours: mapOpeningHours(cfg?.opening_hours),
      rooms: orphanRooms,
    });
  }

  const [staffRows] = await dbConn.query(
    `SELECT s.id, s.full_name, s.role, s.bio, s.avatar_url, s.color_hex,
            COALESCE(s.is_nutritionist, 0) AS is_nutritionist,
            GROUP_CONCAT(DISTINCT l.name ORDER BY l.name SEPARATOR ', ') AS location_names
     FROM staff s
     LEFT JOIN staff_locations sl ON sl.staff_id = s.id
     LEFT JOIN locations l ON l.id = sl.location_id AND l.is_active = 1
     WHERE ${GYM_STAFF_WHERE_ALIAS}
     GROUP BY s.id
     ORDER BY s.full_name`,
    [bizId],
  );

  const trainers = staffRows.map((row) => ({
    id: row.id,
    full_name: row.full_name,
    role: row.role || null,
    bio: row.bio || null,
    avatar_url: row.avatar_url || null,
    color_hex: row.color_hex || null,
    location_names: row.location_names
      ? row.location_names.split(', ').filter(Boolean)
      : [],
  }));

  const [nutritionistRows] = cfg?.feature_nutrition
    ? await dbConn.query(
      `SELECT n.id, n.full_name, n.email, n.staff_id,
              s.role, s.bio, s.avatar_url, s.color_hex,
              l.name AS location_name
       FROM nutritionists n
       LEFT JOIN staff s ON s.id = n.staff_id AND s.is_active = 1
       LEFT JOIN locations l ON l.id = n.location_id AND l.is_active = 1
       WHERE n.business_id = ? AND n.is_active = 1
       ORDER BY n.full_name`,
      [bizId],
    )
    : [[]];

  const nutritionists = nutritionistRows.map((n) => ({
    id: n.staff_id || n.id,
    full_name: n.full_name,
    role: n.role || 'Διατροφολόγος',
    bio: n.bio || null,
    avatar_url: n.avatar_url || null,
    color_hex: n.color_hex || '#0d9488',
    location_names: n.location_name ? [n.location_name] : [],
  }));

  return {
    name: biz.name,
    appName: cfg?.app_name || biz.name,
    slug: biz.slug,
    logoUrl: cfg?.logo_url || null,
    address: cfg?.gym_address || null,
    phone: cfg?.gym_phone || null,
    email: cfg?.gym_email || null,
    owner_name: cfg?.owner_name || null,
    owner_phone: cfg?.owner_phone || null,
    opening_hours: mapOpeningHours(cfg?.opening_hours),
    multi_location: multiLocation,
    locations: mappedLocations,
    trainers,
    nutritionists,
  };
}

module.exports = { buildGymInfoPayload };
