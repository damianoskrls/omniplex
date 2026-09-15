// ============================================================
// FILE: src/api/client.js
// Axios instance — automatically attaches JWT token
// ============================================================

import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:3001/api',
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
