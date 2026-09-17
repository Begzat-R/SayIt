# Cadence

**Find your rhythm.**

Cadence is a mobile app that helps people who stutter — or anyone who experiences speech anxiety — practice real-life speaking situations at their own pace, and connect with a supportive community of people working on similar goals.

## Why

Fluency isn't the goal. Showing up is. Cadence is built around low-pressure, repeatable practice rather than "fixing" how someone talks — situational drills (ordering food, phone calls, job interviews, small talk), breathing/grounding exercises with no timers or counts, and a community where progress is shared as small wins, not performance.

## Features

- **Situational practice** — a growing library of everyday, social, and work scenarios to rehearse
- **Breathing exercise** — a calm, ambient grounding tool with no countdowns or hold/release timers
- **Daily reminders** — an optional daily nudge with a rotating bank of non-generic motivational messages
- **Community feed** — a "What did you try today?" prompt tied to practice situations, plus likes and comments
- **Following & search** — follow other users, search profiles, view followers/following lists
- **Direct messaging** — request-based DMs with real-time delivery, read receipts, and block/report tools
- **Notifications** — live in-app notifications for follows, message requests, likes, and comments

## Tech Stack

- **Flutter** (Dart) — Android first, iOS planned
- **Riverpod** — state management
- **Supabase** — auth, Postgres database, Row Level Security, and Realtime subscriptions
- **flutter_local_notifications** — daily reminder scheduling

## Getting Started

```bash
flutter pub get
flutter run
```

You'll need a Supabase project set up with the migrations in `supabase/migrations/` applied, and your Supabase URL/anon key configured for the app to connect to a backend.

## Status

Actively in development. Core practice tools and community features (follow, message, post, like, comment, notify) are built and verified on-device. Not yet published to an app store.

## License

TBD
