import axios from 'axios';

const api = axios.create({ baseURL: (import.meta.env.VITE_API_URL || 'https://passionate-grace-production-98ad.up.railway.app') + '/api' });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('gym_admin_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;

  // Append active branch filter to all GET requests when a branch is selected
  const branchId = localStorage.getItem('gym_admin_active_branch_id');
  if (branchId && (config.method === 'get' || !config.method)) {
    config.params = { ...config.params, location_id: branchId };
  }

  return config;
});

api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401 && !window.location.pathname.includes('/login')) {
      localStorage.removeItem('gym_admin_token');
      localStorage.removeItem('gym_admin_business');
      window.location.href = '/login';
    }
    return Promise.reject(err);
  }
);

export default api;
