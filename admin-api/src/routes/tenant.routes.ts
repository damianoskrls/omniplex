// ============================================================
// BookUp Admin API
// FILE: admin-api/src/routes/tenant.routes.ts
// Handles: create tenant, update config, upload logo, trigger build
// ============================================================

import { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { db } from '../db';
import { uploadToStorage } from '../services/storage';
import { triggerBuildPipeline } from '../services/build-pipeline';
import { invalidateConfigCache } from '../services/cache';

// ── Validation schemas ────────────────────────────────────────

const CreateTenantSchema = z.object({
  name:            z.string().min(2),
  slug:            z.string().regex(/^[a-z0-9-]+$/, 'slug must be lowercase-hyphenated'),
  business_type:   z.enum(['gym', 'barbershop', 'salon', 'spa']),
  owner_email:     z.string().email(),
  app_name:        z.string().min(2),
  bundle_id:       z.string().regex(/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/),
  primary_color:   z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  secondary_color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  plan:            z.enum(['starter', 'pro', 'enterprise']).default('starter'),
});

const UpdateConfigSchema = z.object({
  primary_color:               z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  secondary_color:             z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  accent_color:                z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  font_family:                 z.string().optional(),
  label_overrides:             z.record(z.string()).optional(),
  feature_online_booking:      z.boolean().optional(),
  feature_loyalty_points:      z.boolean().optional(),
  feature_memberships:         z.boolean().optional(),
  feature_pos_integration:     z.boolean().optional(),
  feature_multi_location:      z.boolean().optional(),
  feature_waitlist:            z.boolean().optional(),
  feature_video_consultations: z.boolean().optional(),
  feature_custom_module_id:    z.string().nullable().optional(),
});

// ── Routes ────────────────────────────────────────────────────

export async function tenantRoutes(app: FastifyInstance) {

  // POST /admin/tenants — Create a new tenant
  app.post('/admin/tenants', {
    preHandler: [app.authenticate, app.requireMasterAdmin],
  }, async (req, reply) => {
    const body = CreateTenantSchema.parse(req.body);

    const business = await db.transaction(async (trx) => {
      // Insert the root business record
      const [biz] = await trx('businesses').insert({
        name:          body.name,
        slug:          body.slug,
        business_type: body.business_type,
        owner_email:   body.owner_email,
        plan:          body.plan,
      }).returning('*');

      // Seed config with business-type defaults
      await trx('business_configs').insert({
        business_id:     biz.id,
        app_name:        body.app_name,
        bundle_id:       body.bundle_id,
        android_package: body.bundle_id,
        primary_color:   body.primary_color,
        secondary_color: body.secondary_color,
        label_overrides: getDefaultLabels(body.business_type),
        ...getDefaultFeatureFlags(body.plan),
      });

      return biz;
    });

    return reply.status(201).send({
      id:   business.id,
      slug: business.slug,
    });
  });

  // GET /admin/tenants — List all tenants
  app.get('/admin/tenants', {
    preHandler: [app.authenticate, app.requireMasterAdmin],
  }, async (_req, reply) => {
    const rows = await db('businesses')
      .join('business_configs', 'businesses.id', 'business_configs.business_id')
      .select(
        'businesses.id',
        'businesses.slug',
        'businesses.name',
        'businesses.business_type',
        'businesses.is_active',
        'businesses.plan',
        'business_configs.primary_color',
        'business_configs.app_name',
        'business_configs.logo_url',
      )
      .orderBy('businesses.created_at', 'desc');

    return reply.send(rows);
  });

  // GET /admin/tenants/:id — Full config for one tenant
  app.get('/admin/tenants/:id', {
    preHandler: [app.authenticate, app.requireMasterAdmin],
  }, async (req, reply) => {
    const { id } = req.params as { id: string };

    const row = await db('businesses')
      .join('business_configs', 'businesses.id', 'business_configs.business_id')
      .where('businesses.id', id)
      .first();

    if (!row) return reply.status(404).send({ error: 'Tenant not found' });
    return reply.send(row);
  });

  // GET /admin/tenants/:id/build-config — Called by the build script
  app.get('/admin/tenants/:id/build-config', {
    preHandler: [app.authenticate],  // build script uses service token
  }, async (req, reply) => {
    const { id } = req.params as { id: string };

    const row = await db('businesses')
      .join('business_configs', 'businesses.id', 'business_configs.business_id')
      .where({ 'businesses.id': id, 'businesses.is_active': true })
      .first();

    if (!row) return reply.status(404).send({ error: 'Tenant not found or inactive' });
    return reply.send(row);
  });

  // PATCH /admin/tenants/:id/config — Update branding or feature flags
  app.patch('/admin/tenants/:id/config', {
    preHandler: [app.authenticate, app.requireMasterAdmin],
  }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const updates = UpdateConfigSchema.parse(req.body);

    // label_overrides is a JSONB merge, not a full replace
    if (updates.label_overrides) {
      await db.raw(`
        UPDATE business_configs
        SET label_overrides = label_overrides || ?::jsonb,
            updated_at = now()
        WHERE business_id = ?
      `, [JSON.stringify(updates.label_overrides), id]);
      delete updates.label_overrides;
    }

    if (Object.keys(updates).length > 0) {
      await db('business_configs')
        .where({ business_id: id })
        .update({ ...updates, updated_at: new Date() });
    }

    // Bust the CDN/Redis config cache so the mobile app picks up changes
    await invalidateConfigCache(id);

    return reply.send({ ok: true });
  });

  // POST /admin/tenants/:id/logo — Upload logo, store to CDN
  app.post('/admin/tenants/:id/logo', {
    preHandler: [app.authenticate, app.requireMasterAdmin],
  }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const data = await req.file();

    if (!data) return reply.status(400).send({ error: 'No file uploaded' });

    const url = await uploadToStorage(`tenants/${id}/logo.png`, data.file, {
      contentType: 'image/png',
      cacheControl: 'public, max-age=31536000',
    });

    await db('business_configs')
      .where({ business_id: id })
      .update({ logo_url: url, updated_at: new Date() });

    await invalidateConfigCache(id);
    return reply.send({ logo_url: url });
  });

  // POST /admin/tenants/:id/toggle-active — Enable / disable tenant
  app.post('/admin/tenants/:id/toggle-active', {
    preHandler: [app.authenticate, app.requireMasterAdmin],
  }, async (req, reply) => {
    const { id } = req.params as { id: string };

    const [biz] = await db('businesses')
      .where({ id })
      .update({ is_active: db.raw('NOT is_active'), updated_at: new Date() })
      .returning(['id', 'is_active']);

    return reply.send({ id: biz.id, is_active: biz.is_active });
  });

  // POST /admin/tenants/:id/build — Trigger CI build pipeline
  app.post('/admin/tenants/:id/build', {
    preHandler: [app.authenticate, app.requireMasterAdmin],
  }, async (req, reply) => {
    const { id } = req.params as { id: string };
    const { platform } = req.body as { platform: 'android' | 'ios' | 'both' };

    const jobId = await triggerBuildPipeline({ tenantId: id, platform });
    return reply.send({ job_id: jobId, status: 'queued' });
  });
}

// ── Helpers ───────────────────────────────────────────────────

function getDefaultLabels(type: string): Record<string, string> {
  const maps: Record<string, Record<string, string>> = {
    gym: {
      book_cta:         'Book a Class',
      staff_noun:       'Trainer',
      service_noun:     'Class',
      appointment_noun: 'Session',
      home_hero:        'Train harder. Live better.',
      cancel_booking:   'Cancel Session',
      loyalty_label:    'Fitness Points',
    },
    barbershop: {
      book_cta:         'Book a Barber',
      staff_noun:       'Barber',
      service_noun:     'Cut',
      appointment_noun: 'Appointment',
      home_hero:        'Look sharp. Feel sharp.',
      cancel_booking:   'Cancel Appointment',
      loyalty_label:    'Loyalty Points',
    },
    salon: {
      book_cta:         'Book a Stylist',
      staff_noun:       'Stylist',
      service_noun:     'Treatment',
      appointment_noun: 'Appointment',
      home_hero:        'Beauty, redefined.',
      cancel_booking:   'Cancel Appointment',
      loyalty_label:    'Beauty Points',
    },
    spa: {
      book_cta:         'Book a Treatment',
      staff_noun:       'Therapist',
      service_noun:     'Treatment',
      appointment_noun: 'Reservation',
      home_hero:        'Your sanctuary awaits.',
      cancel_booking:   'Cancel Reservation',
      loyalty_label:    'Wellness Points',
    },
  };
  return maps[type] ?? maps['salon'];
}

function getDefaultFeatureFlags(plan: string) {
  return {
    feature_online_booking:      true,
    feature_loyalty_points:      plan !== 'starter',
    feature_memberships:         plan === 'enterprise',
    feature_pos_integration:     plan === 'enterprise',
    feature_multi_location:      plan === 'enterprise',
    feature_waitlist:            plan !== 'starter',
    feature_video_consultations: false,
  };
}
