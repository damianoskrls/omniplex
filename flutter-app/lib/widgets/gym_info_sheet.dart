import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/tenant_config.dart';
import '../models/gym_info.dart';
import '../models/opening_hours.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';
import 'staff_avatar.dart';
import 'staff_detail_sheet.dart';
import 'tenant_logo.dart';
import 'ui_kit.dart';

const _dayLabels = [
  'Δευτέρα',
  'Τρίτη',
  'Τετάρτη',
  'Πέμπτη',
  'Παρασκευή',
  'Σάββατο',
  'Κυριακή',
];

Future<void> showGymInfoSheet(BuildContext context, {required GymInfo info}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final config = ctx.read<TenantConfig>();
      final logoUrl = resolveMediaUrl(config, info.logoUrl ?? config.logoUrl);

      return Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      tooltip: 'Κλείσιμο',
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                Center(
                  child: logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            logoUrl,
                            width: 88,
                            height: 88,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const TenantLogo(size: 88, borderRadius: 20, showShadow: false),
                          ),
                        )
                      : const TenantLogo(size: 88, borderRadius: 20, showShadow: false),
                ),
                const SizedBox(height: 16),
                Text(
                  info.appName.isNotEmpty ? info.appName : info.name,
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.headlineMedium,
                ),
                if (info.name.isNotEmpty && info.name != info.appName) ...[
                  const SizedBox(height: 4),
                  Text(
                    info.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(ctx).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 24),
                if (_hasContactInfo(info)) ...[
                  _SectionTitle(title: 'Επικοινωνία'),
                  const SizedBox(height: 10),
                  if (info.address != null && info.address!.trim().isNotEmpty)
                    _InfoRow(
                      icon: Icons.location_on_outlined,
                      title: 'Διεύθυνση',
                      value: info.address!,
                      actionLabel: 'Οδηγίες',
                      onAction: () => _openDirections(info.address!),
                    ),
                  if (info.phone != null && info.phone!.trim().isNotEmpty) ...[
                    if (info.address != null && info.address!.trim().isNotEmpty) const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.phone_outlined,
                      title: 'Τηλέφωνο',
                      value: info.phone!,
                      actionLabel: 'Κλήση',
                      onAction: () => _openPhone(info.phone!),
                    ),
                  ],
                  if (info.email != null && info.email!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.mail_outline,
                      title: 'Email',
                      value: info.email!,
                      actionLabel: 'Αποστολή',
                      onAction: () => _openEmail(info.email!),
                    ),
                  ],
                  if (info.ownerName != null && info.ownerName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.person_outline,
                      title: 'Υπεύθυνος',
                      value: info.ownerPhone != null && info.ownerPhone!.trim().isNotEmpty
                          ? '${info.ownerName!}\n${info.ownerPhone!}'
                          : info.ownerName!,
                      actionLabel: info.ownerPhone != null && info.ownerPhone!.trim().isNotEmpty
                          ? 'Κλήση'
                          : null,
                      onAction: info.ownerPhone != null && info.ownerPhone!.trim().isNotEmpty
                          ? () => _openPhone(info.ownerPhone!)
                          : null,
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
                if (info.openingHours != null && info.openingHours!.days.isNotEmpty) ...[
                  _SectionTitle(
                    title: info.locations.isNotEmpty ? 'Γενικό ωράριο' : 'Ωράριο λειτουργίας',
                  ),
                  const SizedBox(height: 10),
                  _OpeningHoursTable(hours: info.openingHours!),
                  const SizedBox(height: 24),
                ],
                if (info.locations.isNotEmpty) ...[
                  _SectionTitle(
                    title: info.multiLocation ? 'Τοποθεσίες & Αίθουσες' : 'Τοποθεσία & Αίθουσες',
                  ),
                  const SizedBox(height: 10),
                  ...info.locations.map(
                    (loc) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _LocationCard(location: loc, config: config),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (info.trainers.isNotEmpty) ...[
                  _SectionTitle(title: 'Γυμναστές'),
                  const SizedBox(height: 10),
                  _StaffList(
                    profiles: info.trainers,
                    config: config,
                  ),
                  const SizedBox(height: 24),
                ],
                if (info.nutritionists.isNotEmpty) ...[
                  _SectionTitle(title: 'Διατροφολόγοι'),
                  const SizedBox(height: 10),
                  _StaffList(
                    profiles: info.nutritionists,
                    config: config,
                  ),
                ],
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Κλείσιμο'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

bool _hasContactInfo(GymInfo info) {
  return (info.address?.trim().isNotEmpty ?? false) ||
      (info.phone?.trim().isNotEmpty ?? false) ||
      (info.email?.trim().isNotEmpty ?? false) ||
      (info.ownerName?.trim().isNotEmpty ?? false);
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _OpeningHoursTable extends StatelessWidget {
  const _OpeningHoursTable({required this.hours});

  final OpeningHoursConfig hours;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: List.generate(7, (day) {
          final dayHours = hours.days[day];
          final label = _dayLabels[day];
          final value = dayHours == null
              ? '09:00 – 21:00'
              : dayHours.closed
                  ? 'Κλειστά'
                  : '${dayHours.open} – ${dayHours.close}';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 92,
                  child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: dayHours?.closed == true
                              ? AppColors.textSecondary
                              : AppColors.lime,
                        ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.location,
    required this.config,
  });

  final GymLocationDetail location;
  final TenantConfig config;

  @override
  Widget build(BuildContext context) {
    final address = location.fullAddress;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(location.name, style: Theme.of(context).textTheme.titleSmall),
          if (address != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: AppColors.purple),
                const SizedBox(width: 8),
                Expanded(child: Text(address, style: Theme.of(context).textTheme.bodyMedium)),
                TextButton(
                  onPressed: () => _openDirections(address),
                  child: const Text('Οδηγίες'),
                ),
              ],
            ),
          ],
          if (location.phone != null && location.phone!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _LocationContactRow(
              icon: Icons.phone_outlined,
              value: location.phone!,
              actionLabel: 'Κλήση',
              onAction: () => _openPhone(location.phone!),
            ),
          ],
          if (location.email != null && location.email!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            _LocationContactRow(
              icon: Icons.mail_outline,
              value: location.email!,
              actionLabel: 'Email',
              onAction: () => _openEmail(location.email!),
            ),
          ],
          if (location.openingHours != null && location.openingHours!.days.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Ωράριο', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            const SizedBox(height: 8),
            _OpeningHoursTable(hours: location.openingHours!),
          ],
          if (location.rooms.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Αίθουσες', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            const SizedBox(height: 10),
            ...location.rooms.map(
              (room) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RoomTile(room: room, config: config),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LocationContactRow extends StatelessWidget {
  const _LocationContactRow({
    required this.icon,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String value;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.purple),
        const SizedBox(width: 8),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.config,
  });

  final GymRoom room;
  final TenantConfig config;

  @override
  Widget build(BuildContext context) {
    final photoUrl = resolveMediaUrl(config, room.photoUrl);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
              child: Image.network(
                photoUrl,
                width: 88,
                height: 88,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _RoomPlaceholder(name: room.name),
              ),
            )
          else
            _RoomPlaceholder(name: room.name),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(room.name, style: Theme.of(context).textTheme.titleSmall),
                  if (room.shortInfo != null && room.shortInfo!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      room.shortInfo!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomPlaceholder extends StatelessWidget {
  const _RoomPlaceholder({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
      ),
      child: Icon(Icons.meeting_room_outlined, color: AppColors.purple.withValues(alpha: 0.7), size: 32),
    );
  }
}

class _StaffList extends StatelessWidget {
  const _StaffList({
    required this.profiles,
    required this.config,
  });

  final List<GymStaffProfile> profiles;
  final TenantConfig config;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < profiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            _StaffCard(
              profile: profiles[i],
              config: config,
              onTap: () => showStaffDetailSheet(
                context,
                staff: profiles[i].member,
                config: config,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.profile,
    required this.config,
    required this.onTap,
  });

  final GymStaffProfile profile;
  final TenantConfig config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final member = profile.member;
    final locations = profile.locationNames.join(', ');

    return GestureDetector(
      onTap: onTap,
      child: SurfaceCard(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StaffAvatar(staff: member, config: config, radius: 32),
              const SizedBox(height: 8),
              Text(
                member.fullName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13, height: 1.2),
              ),
              if (member.role != null && member.role!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  member.role!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11, height: 1.2),
                ),
              ],
              if (locations.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  locations,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 10,
                        height: 1.2,
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.purple, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

Future<void> _openDirections(String address) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
  );
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _openPhone(String phone) async {
  final normalized = phone.replaceAll(RegExp(r'\s+'), '');
  final uri = Uri.parse('tel:$normalized');
  await launchUrl(uri);
}

Future<void> _openEmail(String email) async {
  final uri = Uri.parse('mailto:$email');
  await launchUrl(uri);
}
