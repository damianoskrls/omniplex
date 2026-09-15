const NUTRITION_CATEGORIES = ['nutrition', 'nutrition_consultation'];

export function isGymService(service) {
  if (!service) return false;
  const cat = service.category ?? service.service_category;
  return !cat || !NUTRITION_CATEGORIES.includes(cat);
}

export function filterGymBookings(bookings = []) {
  return bookings.filter((b) => isGymService({ category: b.service_category, ...b }));
}

export function filterGymServices(services = []) {
  return services.filter(isGymService);
}
