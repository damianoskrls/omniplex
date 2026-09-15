import axios from 'axios';

const api = axios.create({ baseURL: (import.meta.env.VITE_API_URL || 'https://passionate-grace-production-98ad.up.railway.app') + '/api' });

api.interceptors.request.use((config) => {
  const token = localStorage.getItem('gym_admin_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
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
