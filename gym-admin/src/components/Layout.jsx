import { NavLink, useLocation, useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import {
  LayoutDashboard, Users, Calendar, Scissors, UserCog,
  Package, LogOut, CreditCard, QrCode, DoorOpen, Settings, Bell, Apple, UserCircle, Dumbbell, Menu, X, MapPin, MessageSquare, BarChart2, UsersRound, ChevronDown,
  AlertTriangle, TrendingUp, ListOrdered, ShoppingBag, Receipt, Tag, Truck, ClipboardList, Star, Activity, CalendarOff, Target, FileDown, ShieldCheck, Send, ClipboardCheck, Zap,
} from 'lucide-react';
import BrandLogo from './BrandLogo';
import NotificationBell from './NotificationBell';
import Avatar from './ui/Avatar';
import GlobalSearch from './GlobalSearch';
import { useEffect, useRef, useState } from 'react';
import api from '../api/client';
import useMessagesUnreadCount from '../hooks/useMessagesUnreadCount';
import useMarketplacePending from '../hooks/useMarketplacePending';

function buildNavGroups({ features, featureNutrition }) {
  return [
    {
      key: 'clients',
      label: 'Πελάτες & Κρατήσεις',
      links: [
        { to: '/bookings', icon: Calendar, label: 'Κρατήσεις' },
        { to: '/clients', icon: Users, label: 'Πελάτες' },
        { to: '/trials', icon: Target, label: 'Δοκιμαστικά' },
        ...(features.programs ? [{ to: '/programs', icon: Dumbbell, label: 'Προγράμματα Άσκησης' }] : []),
      ],
    },
    {
      key: 'reports',
      label: 'Αναφορές',
      links: [
        { to: '/reports', icon: BarChart2, label: 'Αναφορές' },
        { to: '/analytics', icon: Activity, label: 'Αναλυτικά' },
        { to: '/monthly-report', icon: TrendingUp, label: 'Αναφορά Αξίας' },
        { to: '/reviews', icon: Star, label: 'Αξιολογήσεις' },
        { to: '/at-risk', icon: AlertTriangle, label: 'Πελάτες σε Κίνδυνο' },
        { to: '/export', icon: FileDown, label: 'Εξαγωγή Excel' },
      ],
    },
    {
      key: 'communication',
      label: 'Επικοινωνία',
      links: [
        { to: '/messages', icon: MessageSquare, label: 'Μηνύματα' },
        { to: '/bulk-message', icon: Send, label: 'Μαζική Αποστολή' },
        { to: '/questionnaires', icon: ClipboardCheck, label: 'Ερωτηματολόγια' },
        { to: '/community', icon: UsersRound, label: 'Κοινότητα' },
        { to: '/notifications', icon: Bell, label: 'Ειδοποιήσεις' },
      ],
    },
    {
      key: 'marketplace',
      label: 'Marketplace',
      links: [
        { to: '/marketplace', end: true, icon: ShoppingBag, label: 'Προϊόντα & Κατηγορίες' },
        { to: '/marketplace/orders', icon: ClipboardList, label: 'Παραγγελίες' },
        { to: '/marketplace/shipping', icon: Truck, label: 'Τρόπος Αποστολής' },
        { to: '/marketplace/payment-methods', icon: CreditCard, label: 'Τρόπος Πληρωμής' },
      ],
    },
    ...(featureNutrition ? [{
      key: 'nutrition',
      label: 'Διατροφολόγος',
      links: [
        { to: '/nutrition/clients', icon: Users, label: 'Πελάτες διατροφής' },
        { to: '/nutrition/bookings', icon: Calendar, label: 'Κρατήσεις' },
        { to: '/nutrition/schedule', icon: Calendar, label: 'Ωράριο επισκέψεων' },
        { to: '/nutrition/plans', icon: Package, label: 'Πακέτα διατροφής' },
        { to: '/nutrition/nutritionists', icon: UserCircle, label: 'Διατροφολόγοι' },
      ],
    }] : []),
    {
      key: 'management',
      label: 'Διαχείριση',
      links: [
        { to: '/services', icon: Scissors, label: 'Υπηρεσίες & Πακέτα' },
        { to: '/staff', icon: UserCog, label: 'Προσωπικό' },
        { to: '/staff-leaves', icon: CalendarOff, label: 'Άδειες Προσωπικού' },
        { to: '/dropin-bookings', icon: Zap, label: 'Drop-in' },
        ...(features.trainers ? [{ to: '/trainer-fees', icon: Receipt, label: 'Αμοιβές Συνεργατών' }] : []),
        { to: '/rooms', icon: DoorOpen, label: 'Χώροι & Αίθουσες' },
        { to: '/locations', icon: MapPin, label: 'Τοποθεσίες' },
        { to: '/waitlist-config', icon: ListOrdered, label: 'Λίστα Αναμονής' },
        { to: '/expenses', icon: Receipt, label: 'Γενικά Έξοδα' },
      ],
    },
    {
      key: 'settings',
      label: 'Ρυθμίσεις',
      links: [
        { to: '/settings', icon: Settings, label: 'Γενικές Ρυθμίσεις' },
        { to: '/online-payments', icon: CreditCard, label: 'Online Πληρωμές' },
        { to: '/gdpr', icon: ShieldCheck, label: 'GDPR — Συναίνεση' },
        { to: '/reminders', icon: Bell, label: 'Αυτόματες Υπενθυμίσεις' },
        { to: '/kiosk', icon: QrCode, label: 'QR Check-in / Scanner', external: true },
      ],
    },
  ];
}

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

function NavItem({ link, unreadCount, marketplacePending, className = '' }) {
  const isMessages = link.to === '/messages';
  const isMarketplaceOrders = link.to === '/marketplace/orders';
  const content = (
    <>
      <link.icon size={className ? 14 : 16} />
      <span className="sidebar-nav-link__label">{link.label}</span>
      {isMessages && <MessagesNavBadge count={unreadCount} />}
      {isMarketplaceOrders && marketplacePending > 0 && <MessagesNavBadge count={marketplacePending} />}
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

function AccordionGroup({ groupKey, label, links, unreadCount, marketplacePending, defaultOpen }) {
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
        {groupKey === 'communication' && unreadCount > 0 && <span className="sidebar-nav-badge" style={{ marginRight: 6 }}>{unreadCount > 99 ? '99+' : unreadCount}</span>}
        {groupKey === 'marketplace' && marketplacePending > 0 && <span className="sidebar-nav-badge" style={{ marginRight: 6, background: '#f59e0b' }}>{marketplacePending}</span>}
        <ChevronDown size={14} className={`sidebar-accordion__chevron ${open ? 'sidebar-accordion__chevron--open' : ''}`} />
      </button>
      {open && (
        <div className="sidebar-accordion__items">
          {links.map(link => (
            <NavItem key={link.to} link={link} unreadCount={unreadCount} marketplacePending={marketplacePending} className="sidebar-subnav-link" />
          ))}
        </div>
      )}
    </div>
  );
}

function TrainerNav({ unreadCount }) {
  return (
    <div className="sidebar-group sidebar-group--active">
      <div className="sidebar-group__title"><Dumbbell size={16} /> {staffLabel}</div>
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

export default function Layout({ children, title, variant, headerActions }) {
  const { logout, business, isNutritionist, isTrainer, isOwner, features } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [navOpen, setNavOpen] = useState(false);
  const [featureNutrition, setFeatureNutrition] = useState(false);
  const [trainerStaff, setTrainerStaff] = useState(null);
  const [avatarOpen, setAvatarOpen] = useState(false);
  const avatarRef = useRef(null);
  const { unreadCount: messagesUnread } = useMessagesUnreadCount();
  const { pendingCount: marketplacePending } = useMarketplacePending();

  useEffect(() => {
    function handleClick(e) {
      if (avatarRef.current && !avatarRef.current.contains(e.target)) setAvatarOpen(false);
    }
    document.addEventListener('mousedown', handleClick);
    return () => document.removeEventListener('mousedown', handleClick);
  }, []);

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

  const staffLabel = business?.type === 'gym' ? 'Γυμναστής' : 'Συνεργάτης';

  const ownerGroups = buildNavGroups({ features: features || {}, featureNutrition });

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
              name={trainerStaff?.full_name || staffLabel}
              image={trainerStaff?.avatar_url}
              color={trainerStaff?.color_hex}
              size={72}
            />
            <div className="sidebar-business">
              <div className="sidebar-business__role">{trainerStaff?.full_name || staffLabel}</div>
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
            <>
              <NavLink to="/" end className="sidebar-dashboard-link">
                <LayoutDashboard size={16} />
                <span>Dashboard</span>
              </NavLink>
              {ownerGroups.map(group => (
                <AccordionGroup
                  key={group.key}
                  groupKey={group.key}
                  label={group.label}
                  links={group.links}
                  unreadCount={messagesUnread}
                  marketplacePending={marketplacePending}
                  defaultOpen={false}
                />
              ))}
            </>
          )}
        </nav>

        {isOwner && (
          <div className="sidebar-promo">
            <div className="sidebar-promo__title">Αυτόματες Υπενθυμίσεις</div>
            <div className="sidebar-promo__text">Ενεργοποίησε SMS/email για κρατήσεις, λήξεις & ανενεργούς.</div>
            <button type="button" className="sidebar-promo__btn" onClick={() => navigate('/reminders')}>
              Ρύθμισε τώρα →
            </button>
          </div>
        )}
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

          {/* Centered search */}
          {isOwner && (
            <div className="topbar-center">
              <GlobalSearch />
            </div>
          )}

          <div className="topbar-right">
            {headerActions && <div style={{ display: 'flex', gap: 8 }}>{headerActions}</div>}

            {/* Messages quick-access */}
            {(isOwner || isTrainer) && (
              <NavLink to="/messages" className="topbar-msg-btn" title="Μηνύματα">
                <MessageSquare size={20} />
                {messagesUnread > 0 && (
                  <span className="topbar-msg-badge">{messagesUnread > 99 ? '99+' : messagesUnread}</span>
                )}
              </NavLink>
            )}

            {/* Notifications */}
            {(isOwner || isTrainer) && <NotificationBell />}

            {/* Avatar dropdown */}
            <div className="topbar-avatar-wrap" ref={avatarRef}>
              <button
                type="button"
                className="topbar-avatar-btn"
                onClick={() => setAvatarOpen(v => !v)}
                aria-label="Μενού χρήστη"
              >
                <Avatar
                  name={isTrainer ? (trainerStaff?.full_name || staffLabel) : (business?.name || 'Admin')}
                  image={isTrainer ? trainerStaff?.avatar_url : null}
                  color={isTrainer ? trainerStaff?.color_hex : null}
                  size={36}
                />
              </button>
              {avatarOpen && (
                <div className="topbar-avatar-dropdown">
                  <div className="topbar-avatar-dropdown__name">
                    {isTrainer ? (trainerStaff?.full_name || staffLabel) : business?.name}
                  </div>
                  <div className="topbar-avatar-dropdown__role">
                    {isOwner ? 'Διαχειριστής' : isTrainer ? staffLabel : 'Χρήστης'}
                  </div>
                  <div className="topbar-avatar-dropdown__divider" />
                  {isOwner && (
                    <button
                      type="button"
                      className="topbar-avatar-dropdown__item"
                      onClick={() => { setAvatarOpen(false); navigate('/settings'); }}
                    >
                      <Settings size={14} /> Ρυθμίσεις
                    </button>
                  )}
                  <button
                    type="button"
                    className="topbar-avatar-dropdown__item topbar-avatar-dropdown__item--danger"
                    onClick={() => { setAvatarOpen(false); logout(); navigate('/login'); }}
                  >
                    <LogOut size={14} /> Αποσύνδεση
                  </button>
                </div>
              )}
            </div>
          </div>
        </div>
        <div className="content content--modern">{children}</div>
      </main>
    </div>
  );
}
