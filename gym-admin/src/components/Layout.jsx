import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard, Users, Calendar, Scissors, UserCog,
  Package, LogOut, CreditCard, QrCode, DoorOpen, Settings, Bell, Apple, UserCircle, Dumbbell, Menu, X, MapPin, MessageSquare, BarChart2, UsersRound, ChevronDown,
  AlertTriangle, TrendingUp, ListOrdered, ShoppingBag, Receipt, Tag, Truck, ClipboardList,
} from 'lucide-react';
import BrandLogo from './BrandLogo';
import NotificationBell from './NotificationBell';
import Avatar from './ui/Avatar';
import { useEffect, useState } from 'react';
import api from '../api/client';
import useMessagesUnreadCount from '../hooks/useMessagesUnreadCount';

const NAV_GROUPS = [
  {
    key: 'main',
    label: 'Κύρια',
    links: [
      { to: '/', end: true, icon: LayoutDashboard, label: 'Dashboard' },
      { to: '/reports', icon: BarChart2, label: 'Αναφορές' },
      { to: '/monthly-report', icon: TrendingUp, label: 'Αναφορά Αξίας' },
    ],
  },
  {
    key: 'clients',
    label: 'Πελάτες & Κρατήσεις',
    links: [
      { to: '/bookings', icon: Calendar, label: 'Κρατήσεις' },
      { to: '/clients', icon: Users, label: 'Πελάτες' },
      { to: '/payments', icon: CreditCard, label: 'Πληρωμές' },
      { to: '/at-risk', icon: AlertTriangle, label: 'Μέλη σε Κίνδυνο' },
      { to: '/programs', icon: Dumbbell, label: 'Προγράμματα' },
    ],
  },
  {
    key: 'communication',
    label: 'Επικοινωνία',
    links: [
      { to: '/messages', icon: MessageSquare, label: 'Μηνύματα' },
      { to: '/community', icon: UsersRound, label: 'Κοινότητα' },
      { to: '/notifications', icon: Bell, label: 'Ειδοποιήσεις' },
    ],
  },
  {
    key: 'setup',
    label: 'Ρύθμιση',
    links: [
      { to: '/services', icon: Scissors, label: 'Υπηρεσίες' },
      { to: '/plans', icon: Package, label: 'Πακέτα' },
      { to: '/staff', icon: UserCog, label: 'Προσωπικό' },
      { to: '/rooms', icon: DoorOpen, label: 'Αίθουσες' },
      { to: '/locations', icon: MapPin, label: 'Τοποθεσίες' },
      { to: '/waitlist-config', icon: ListOrdered, label: 'Λίστα Αναμονής' },
      { to: '/trainer-fees', icon: UserCog, label: 'Αμοιβές Εκπαιδευτών' },
      { to: '/expenses', icon: Receipt, label: 'Γενικά Έξοδα' },
      { to: '/online-payments', icon: CreditCard, label: 'Online Πληρωμές' },
    ],
  },
  {
    key: 'marketplace',
    label: 'Marketplace',
    links: [
      { to: '/marketplace', end: true, icon: Package, label: 'Προϊόντα' },
      { to: '/marketplace/orders', icon: ClipboardList, label: 'Παραγγελίες' },
      { to: '/marketplace/categories', icon: Tag, label: 'Κατηγορίες' },
      { to: '/marketplace/shipping', icon: Truck, label: 'Τρόπος Αποστολής' },
      { to: '/marketplace/payment-methods', icon: CreditCard, label: 'Τρόπος Πληρωμής' },
    ],
  },
  {
    key: 'other',
    label: 'Άλλα',
    links: [
      { to: '/kiosk', icon: QrCode, label: 'QR Check-in', external: true },
      { to: '/entrance-scanner', icon: DoorOpen, label: 'Scanner Εισόδου', external: true },
      { to: '/settings', icon: Settings, label: 'Ρυθμίσεις' },
    ],
  },
];

const NUTRITION_LINKS = [
  { to: '/messages', icon: MessageSquare, label: 'Μηνύματα' },
  { to: '/nutrition/clients', icon: Users, label: 'Πελάτες διατροφής' },
  { to: '/nutrition/bookings', icon: Calendar, label: 'Κρατήσεις' },
  { to: '/nutrition/schedule', icon: Calendar, label: 'Ωράριο επισκέψεων' },
  { to: '/nutrition/plans', icon: Package, label: 'Πακέτα διατροφής', ownerOnly: true },
  { to: '/nutrition/nutritionists', icon: UserCircle, label: 'Διατροφολόγοι', ownerOnly: true },
];

const TRAINER_LINKS = [
  { to: '/messages', icon: MessageSquare, label: 'Μηνύματα' },
  { to: '/trainer', end: true, icon: Calendar, label: 'Πρόγραμμα' },
  { to: '/trainer/clients', icon: Users, label: 'Πελάτες μου' },
  { to: '/trainer/availability', icon: Calendar, label: 'Διαθεσιμότητα' },
  { to: '/trainer/profile', icon: UserCircle, label: 'Ρυθμίσεις' },
];

function MessagesNavBadge({ count }) {
  if (!count) return null;
  return (
    <span className="sidebar-nav-badge" aria-label={`${count} αδιάβαστα μηνύματα`}>
      {count > 99 ? '99+' : count}
    </span>
  );
}

function NavItem({ link, unreadCount, className = '' }) {
  const isMessages = link.to === '/messages';
  const content = (
    <>
      <link.icon size={className ? 14 : 16} />
      <span className="sidebar-nav-link__label">{link.label}</span>
      {isMessages && <MessagesNavBadge count={unreadCount} />}
    </>
  );
  if (link.external) {
    return (
      <NavLink to={link.to} target="_blank" rel="noopener noreferrer" className={className || undefined}>
        {content}
      </NavLink>
    );
  }
  return (
    <NavLink to={link.to} end={link.end} className={className || undefined}>
      {content}
    </NavLink>
  );
}

function AccordionGroup({ groupKey, label, links, unreadCount, defaultOpen }) {
  const location = useLocation();
  const isActive = links.some(l => l.end ? location.pathname === l.to : location.pathname.startsWith(l.to));
  const [open, setOpen] = useState(defaultOpen || isActive);

  useEffect(() => {
    if (isActive) setOpen(true);
  }, [location.pathname]);

  return (
    <div className="sidebar-accordion">
      <button
        type="button"
        className={`sidebar-accordion__header ${isActive ? 'sidebar-accordion__header--active' : ''}`}
        onClick={() => setOpen(v => !v)}
        aria-expanded={open}
      >
        <span className="sidebar-accordion__title">{label}</span>
        <ChevronDown size={14} className={`sidebar-accordion__chevron ${open ? 'sidebar-accordion__chevron--open' : ''}`} />
      </button>
      {open && (
        <div className="sidebar-accordion__items">
          {links.map(link => (
            <NavItem key={link.to} link={link} unreadCount={unreadCount} className="sidebar-subnav-link" />
          ))}
        </div>
      )}
    </div>
  );
}

function TrainerNav({ unreadCount }) {
  return (
    <div className="sidebar-group sidebar-group--active">
      <div className="sidebar-group__title"><Dumbbell size={16} /> Γυμναστής</div>
      <div className="sidebar-group__items">
        {TRAINER_LINKS.map(link => (
          <NavItem key={link.to} link={link} unreadCount={unreadCount} className="sidebar-subnav-link" />
        ))}
      </div>
    </div>
  );
}

function NutritionNav({ isOwner, unreadCount }) {
  const links = NUTRITION_LINKS
    .filter(l => !l.ownerOnly || isOwner)
    .filter(l => !(isOwner && l.to === '/messages'));
  return (
    <div className="sidebar-group sidebar-group--active">
      <div className="sidebar-group__title"><Apple size={16} /> Διατροφολόγος</div>
      <div className="sidebar-group__items">
        {links.map(link => (
          <NavItem key={link.to} link={link} unreadCount={unreadCount} className="sidebar-subnav-link" />
        ))}
      </div>
    </div>
  );
}

export default function Layout({ children, title, variant }) {
  const { logout, business, isNutritionist, isTrainer, isOwner } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [navOpen, setNavOpen] = useState(false);
  const [featureNutrition, setFeatureNutrition] = useState(false);
  const [trainerStaff, setTrainerStaff] = useState(null);
  const { unreadCount: messagesUnread } = useMessagesUnreadCount();

  useEffect(() => { setNavOpen(false); }, [location.pathname]);

  useEffect(() => {
    if (isTrainer) {
      api.get('/client-admin/trainer/bootstrap')
        .then(r => { if (r.data?.staff) setTrainerStaff(r.data.staff); })
        .catch(() => {});
      return;
    }
    api.get('/client-admin/settings')
      .then(r => setFeatureNutrition(!!r.data?.feature_nutrition))
      .catch(() => {});
  }, [isTrainer, location.pathname]);

  const ownerGroups = featureNutrition
    ? [
        ...NAV_GROUPS.slice(0, 2),
        {
          key: 'nutrition',
          label: 'Διατροφολόγος',
          links: NUTRITION_LINKS.filter(l => !l.ownerOnly || isOwner).filter(l => l.to !== '/messages'),
        },
        ...NAV_GROUPS.slice(2),
      ]
    : NAV_GROUPS;

  return (
    <div className={`layout ${variant === 'nutrition' || isNutritionist ? 'layout--nutrition' : ''} ${variant === 'trainer' || isTrainer ? 'layout--trainer' : ''}`}>
      <div
        className={`sidebar-backdrop ${navOpen ? 'sidebar-backdrop--visible' : ''}`}
        onClick={() => setNavOpen(false)}
        aria-hidden={!navOpen}
      />
      <aside className={`sidebar ${navOpen ? 'sidebar--open' : ''}`}>
        <BrandLogo variant="sidebar" logoUrl={business?.logo_url} gymName={business?.name} />
        {isTrainer ? (
          <div className="sidebar-trainer-identity">
            <Avatar
              name={trainerStaff?.full_name || 'Γυμναστής'}
              image={trainerStaff?.avatar_url}
              color={trainerStaff?.color_hex}
              size={72}
            />
            <div className="sidebar-business">
              <div className="sidebar-business__role">{trainerStaff?.full_name || 'Γυμναστής'}</div>
            </div>
          </div>
        ) : isNutritionist ? (
          <div className="sidebar-business">
            <div className="sidebar-business__role">Διατροφολόγος</div>
          </div>
        ) : null}

        <nav className="sidebar-nav">
          {isTrainer ? (
            <TrainerNav unreadCount={messagesUnread} />
          ) : isNutritionist ? (
            <NutritionNav isOwner={false} unreadCount={messagesUnread} />
          ) : (
            ownerGroups.map((group, i) => (
              <AccordionGroup
                key={group.key}
                groupKey={group.key}
                label={group.label}
                links={group.links}
                unreadCount={messagesUnread}
                defaultOpen={i === 0}
              />
            ))
          )}
        </nav>

        <div style={{ padding: '16px 20px', borderTop: '1px solid var(--border)' }}>
          <button className="btn btn-secondary btn-sm" style={{ width: '100%' }} onClick={() => { logout(); navigate('/login'); }}>
            <LogOut size={14} /> Αποσύνδεση
          </button>
        </div>
      </aside>

      <main className="main">
        <div className="topbar topbar--modern">
          <div className="topbar-left">
            <button
              type="button"
              className="mobile-menu-btn"
              onClick={() => setNavOpen(v => !v)}
              aria-label={navOpen ? 'Κλείσιμο μενού' : 'Άνοιγμα μενού'}
            >
              {navOpen ? <X size={22} /> : <Menu size={22} />}
            </button>
            <div>
              <span className="topbar-title">{title}</span>
              {(variant === 'nutrition' || isNutritionist) && (
                <div className="topbar-sub">Διαχείριση διατροφής & μετρήσεων</div>
              )}
              {(variant === 'trainer' || isTrainer) && (
                <div className="topbar-sub">Πρόγραμμα, πελάτες & στόχοι</div>
              )}
            </div>
          </div>
          <div className="topbar-right">
            {isTrainer && (
              <button
                type="button"
                className="topbar-trainer-avatar"
                onClick={() => navigate('/trainer/profile')}
                aria-label="Το προφίλ μου"
                title={trainerStaff?.full_name || 'Γυμναστής'}
              >
                <Avatar
                  name={trainerStaff?.full_name || 'Γυμναστής'}
                  image={trainerStaff?.avatar_url}
                  color={trainerStaff?.color_hex}
                  size={40}
                />
              </button>
            )}
            {isOwner && <NotificationBell />}
          </div>
        </div>
        <div className="content content--modern">{children}</div>
      </main>
    </div>
  );
}
