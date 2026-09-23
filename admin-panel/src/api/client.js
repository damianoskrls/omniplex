// ============================================================
// FILE: src/api/client.js
// Axios instance — automatically attaches JWT token
// ============================================================

import axios from 'axios';

const API_BASE = import.meta.env.VITE_API_URL ?? 'https://passionate-grace-production-98ad.up.railway.app';

const api = axios.create({
  baseURL: `${API_BASE}/api`,
});

// Attach token to every request
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('bookup_token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// Redirect to login on 401
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('bookup_token');
      window.location.href = '/login';
    }
    return Promise.reject(err);
  }
);

export default api;
