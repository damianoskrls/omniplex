import { Navigate, useLocation } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

export function PrivateRoute({ children, ownerOnly = false }) {
  const { isLoggedIn, isNutritionist, isTrainer } = useAuth();
  const location = useLocation();

  if (!isLoggedIn) return <Navigate to="/login" replace />;

  if (ownerOnly && (isNutritionist || isTrainer)) {
    return <Navigate to={isTrainer ? '/trainer' : '/nutrition/clients'} replace />;
  }

  if (isTrainer && !location.pathname.startsWith('/trainer') && !location.pathname.startsWith('/messages')) {
    return <Navigate to="/trainer" replace />;
  }

  if (isNutritionist && !location.pathname.startsWith('/nutrition') && !location.pathname.startsWith('/messages')) {
    return <Navigate to="/nutrition/clients" replace />;
  }

  return children;
}

export function NutritionRoute({ children, ownerOnly = false }) {
  const { isLoggedIn, isNutritionist, isTrainer } = useAuth();
  const location = useLocation();

  if (!isLoggedIn) return <Navigate to="/login" replace />;

  if (isTrainer) return <Navigate to="/trainer" replace />;

  if (ownerOnly && isNutritionist) {
    return <Navigate to="/nutrition/clients" replace />;
  }

  if (isNutritionist && (location.pathname === '/nutrition/plans' || location.pathname === '/nutrition/profile')) {
    return <Navigate to="/nutrition/clients" replace />;
  }

  return children;
}

export function TrainerRoute({ children }) {
  const { isLoggedIn, isTrainer, isNutritionist } = useAuth();

  if (!isLoggedIn) return <Navigate to="/login" replace />;
  if (isNutritionist) return <Navigate to="/nutrition/clients" replace />;
  if (!isTrainer) return <Navigate to="/" replace />;

  return children;
}
