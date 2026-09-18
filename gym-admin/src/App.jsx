import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Toaster } from 'react-hot-toast';
import { AuthProvider, useAuth } from './context/AuthContext';
import { PrivateRoute, NutritionRoute, TrainerRoute } from './components/PrivateRoute';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import Clients from './pages/Clients';
import ClientDetail from './pages/ClientDetail';
import Services from './pages/Services';
import ServiceSchedule from './pages/ServiceSchedule';
import Staff from './pages/Staff';
import StaffDetail from './pages/StaffDetail';
import Bookings from './pages/Bookings';
import Plans from './pages/Plans';
import Payments from './pages/Payments';
import Kiosk from './pages/Kiosk';
import EntranceScanner from './pages/EntranceScanner';
import Rooms from './pages/Rooms';
import Locations from './pages/Locations';
import Settings from './pages/Settings';
import Notifications from './pages/Notifications';
import Nutrition from './pages/Nutrition';
import NutritionClients from './pages/NutritionClients';
import Nutritionists from './pages/Nutritionists';
import NutritionPlans from './pages/NutritionPlans';
import NutritionSchedule from './pages/NutritionSchedule';
import NutritionBookings from './pages/NutritionBookings';
import TrainerSchedule from './pages/trainer/TrainerSchedule';
import TrainerClients from './pages/trainer/TrainerClients';
import TrainerClientDetail from './pages/trainer/TrainerClientDetail';
import TrainerProfile from './pages/trainer/TrainerProfile';
import TrainerAvailability from './pages/trainer/TrainerAvailability';
import Messages from './pages/Messages';
import Community from './pages/Community';
import Reports from './pages/Reports';
import Programs from './pages/Programs';
import AtRisk from './pages/AtRisk';
import MonthlyReport from './pages/MonthlyReport';
import WaitlistConfig from './pages/WaitlistConfig';
import TrainerFees from './pages/TrainerFees';
import Expenses from './pages/Expenses';
import OnlinePayments from './pages/OnlinePayments';
import Marketplace from './pages/Marketplace';
import Reviews from './pages/Reviews';
import Analytics from './pages/Analytics';
import StaffLeaves from './pages/StaffLeaves';
import Trials from './pages/Trials';
import Export from './pages/Export';

function HomeRedirect() {
  const { isNutritionist, isTrainer } = useAuth();
  if (isTrainer) return <Navigate to="/trainer" replace />;
  if (isNutritionist) return <Navigate to="/nutrition/clients" replace />;
  return <Navigate to="/" replace />;
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Toaster position="top-right" />
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/" element={<PrivateRoute ownerOnly><Dashboard /></PrivateRoute>} />
          <Route path="/bookings" element={<PrivateRoute ownerOnly><Bookings /></PrivateRoute>} />
          <Route path="/clients" element={<PrivateRoute ownerOnly><Clients /></PrivateRoute>} />
          <Route path="/clients/:id" element={<PrivateRoute ownerOnly><ClientDetail /></PrivateRoute>} />
          <Route path="/reports" element={<PrivateRoute ownerOnly><Reports /></PrivateRoute>} />
          <Route path="/payments" element={<PrivateRoute ownerOnly><Payments /></PrivateRoute>} />
          <Route path="/services" element={<PrivateRoute ownerOnly><Services /></PrivateRoute>} />
          <Route path="/services/:id/schedule" element={<PrivateRoute ownerOnly><ServiceSchedule /></PrivateRoute>} />
          <Route path="/staff" element={<PrivateRoute ownerOnly><Staff /></PrivateRoute>} />
          <Route path="/staff/:id" element={<PrivateRoute ownerOnly><StaffDetail /></PrivateRoute>} />
          <Route path="/plans" element={<PrivateRoute ownerOnly><Plans /></PrivateRoute>} />
          <Route path="/programs" element={<PrivateRoute><Programs /></PrivateRoute>} />
          <Route path="/rooms" element={<PrivateRoute ownerOnly><Rooms /></PrivateRoute>} />
          <Route path="/locations" element={<PrivateRoute ownerOnly><Locations /></PrivateRoute>} />
          <Route path="/notifications" element={<PrivateRoute ownerOnly><Notifications /></PrivateRoute>} />
          <Route path="/settings" element={<PrivateRoute ownerOnly><Settings /></PrivateRoute>} />
          <Route path="/kiosk" element={<PrivateRoute ownerOnly><Kiosk /></PrivateRoute>} />
          <Route path="/entrance-scanner" element={<PrivateRoute ownerOnly><EntranceScanner /></PrivateRoute>} />
          <Route path="/nutrition" element={<NutritionRoute><Navigate to="/nutrition/clients" replace /></NutritionRoute>} />
          <Route path="/nutrition/clients" element={<NutritionRoute><NutritionClients /></NutritionRoute>} />
          <Route path="/nutrition/clients/:id" element={<NutritionRoute><Nutrition /></NutritionRoute>} />
          <Route path="/nutrition/bookings" element={<NutritionRoute><NutritionBookings /></NutritionRoute>} />
          <Route path="/nutrition/schedule" element={<NutritionRoute><NutritionSchedule /></NutritionRoute>} />
          <Route path="/nutrition/plans" element={<NutritionRoute ownerOnly><NutritionPlans /></NutritionRoute>} />
          <Route path="/nutrition/nutritionists" element={<NutritionRoute ownerOnly><Nutritionists /></NutritionRoute>} />
          <Route path="/nutrition/profile" element={<Navigate to="/nutrition/nutritionists" replace />} />
          <Route path="/trainer" element={<TrainerRoute><TrainerSchedule /></TrainerRoute>} />
          <Route path="/trainer/clients" element={<TrainerRoute><TrainerClients /></TrainerRoute>} />
          <Route path="/trainer/clients/:id" element={<TrainerRoute><TrainerClientDetail /></TrainerRoute>} />
          <Route path="/trainer/availability" element={<TrainerRoute><TrainerAvailability /></TrainerRoute>} />
          <Route path="/trainer/profile" element={<TrainerRoute><TrainerProfile /></TrainerRoute>} />
          <Route path="/messages" element={<PrivateRoute><Messages /></PrivateRoute>} />
          <Route path="/community" element={<PrivateRoute ownerOnly><Community /></PrivateRoute>} />
          <Route path="/at-risk" element={<PrivateRoute ownerOnly><AtRisk /></PrivateRoute>} />
          <Route path="/monthly-report" element={<PrivateRoute ownerOnly><MonthlyReport /></PrivateRoute>} />
          <Route path="/waitlist-config" element={<PrivateRoute ownerOnly><WaitlistConfig /></PrivateRoute>} />
          <Route path="/trainer-fees" element={<PrivateRoute ownerOnly><TrainerFees /></PrivateRoute>} />
          <Route path="/expenses" element={<PrivateRoute ownerOnly><Expenses /></PrivateRoute>} />
          <Route path="/online-payments" element={<PrivateRoute ownerOnly><OnlinePayments /></PrivateRoute>} />
          <Route path="/marketplace" element={<PrivateRoute ownerOnly><Marketplace /></PrivateRoute>} />
          <Route path="/marketplace/orders" element={<PrivateRoute ownerOnly><Marketplace /></PrivateRoute>} />
          <Route path="/marketplace/categories" element={<PrivateRoute ownerOnly><Marketplace /></PrivateRoute>} />
          <Route path="/marketplace/shipping" element={<PrivateRoute ownerOnly><Marketplace /></PrivateRoute>} />
          <Route path="/marketplace/payment-methods" element={<PrivateRoute ownerOnly><Marketplace /></PrivateRoute>} />
          <Route path="/reviews" element={<PrivateRoute ownerOnly><Reviews /></PrivateRoute>} />
          <Route path="/analytics" element={<PrivateRoute ownerOnly><Analytics /></PrivateRoute>} />
          <Route path="/staff-leaves" element={<PrivateRoute ownerOnly><StaffLeaves /></PrivateRoute>} />
          <Route path="/trials" element={<PrivateRoute ownerOnly><Trials /></PrivateRoute>} />
          <Route path="/export" element={<PrivateRoute ownerOnly><Export /></PrivateRoute>} />
          <Route path="*" element={<HomeRedirect />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
