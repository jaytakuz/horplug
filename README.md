# HorPlug

A mobile app that brings dormitory management and the tenant experience
into one place.

## Overview

Running a small dormitory usually means juggling a notebook of meter
readings, a stack of paper bills, and a group chat where repair requests
get lost between other messages. Tenants, meanwhile, often have no
reliable way to check what they owe or whether their request was ever
received.

HorPlug closes that gap. Landlords manage their property from one app,
and tenants see their own room, bills, and requests — the same data, each
side viewing only what belongs to them.

## Who it's for

The app serves two roles from a single codebase, each with its own
navigation and permissions.

**Landlords** oversee the whole property: rooms and occupancy, monthly
meter readings, billing, and conversations with every tenant.

**Tenants** see only their own unit: what they owe this month, how much
electricity and water they used, the status of any repair they reported,
and a direct line to their landlord.

Which experience you get is decided at sign-up and enforced throughout —
neither role can reach the other's screens or data.

## What it does

**Rooms and occupancy** — Track units across floors, their rate and
status, and who currently lives in each one. Moving a tenant in starts
with an invitation the tenant accepts from their own device, so nobody is
assigned to a room without agreeing to it.

**Utilities** — Record monthly electricity and water readings per room.
Consumption and cost are derived from the readings rather than entered by
hand, which keeps both sides looking at the same numbers.

**Billing** — Monthly charges are assembled from the room's rate, its
metered usage, and any additional services. Tenants see the same
itemised breakdown their landlord sees.

**Maintenance and cleaning** — Tenants report an issue and follow it
through to completion. Requests raised anywhere in the app appear in the
landlord's queue and post a message into the conversation, so nothing
depends on someone remembering to mention it.

**Messaging** — A direct conversation per room, with photo attachments
and unread indicators. Because requests flow through the same thread,
the history of a problem stays in one readable place.

## Built with

- **Flutter** — a single codebase targeting mobile, desktop, and web
- **Supabase** — authentication, Postgres, realtime subscriptions, and
  file storage
- **MVVM** — views stay declarative, view models hold state, and a
  service layer owns all data access
- **Row Level Security** — the database itself enforces who can read
  what, so access rules do not depend on the client behaving correctly

The interface is in Thai and follows a single design system, with shared
components so both sides of the app feel like one product.

## Project structure

lib/
models/       domain types shared across the app
services/     all data access
viewmodels/   screen state and business logic
screens/      UI, grouped by role
widgets/      shared components
theme/        colours, typography, and design tokens
utils/        formatting helpers
database/       SQL migrations and security policies
test/           unit tests