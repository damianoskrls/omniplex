import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './context/AuthContext';
import Login         from './pages/Login';
import Dashboard     from './pages/Dashboard';
import Tenants       from './pages/Tenants';
import TenantDetail  from './pages/TenantDetail';
import TenantBilling from './pages/TenantBilling';

function PrivateRoute({ children }) {
  const { isLoggedIn } = useAuth();
  return isLoggedIn ? children : <Navigate to="/login" replace />;
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Toaster position="top-right" />
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/" element={<PrivateRoute><Dashboard /></PrivateRoute>} />
          <Route path="/tenants" element={<PrivateRoute><Tenants /></PrivateRoute>} />
          <Route path="/tenants/:id" element={<PrivateRoute><TenantDetail /></PrivateRoute>} />
          <Route path="/tenants/:id/billing" element={<PrivateRoute><TenantBilling /></PrivateRoute>} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
