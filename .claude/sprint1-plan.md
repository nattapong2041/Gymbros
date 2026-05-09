# Sprint 1 — Foundation + Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete foundation layer for GymBros: folder structure, Codable models, Supabase schema, Apple Sign-In authentication, and four repositories — so Sprint 2 (Program Builder) can start immediately.

---

## ✅ CURRENT STATUS (as of 2026-05-08)

**Tasks 1–9 are fully implemented and verified.**

**Completed commits:**
- `feat: add Supabase schema and exercise seed data`
- `feat: add model enums with JSON round-trip tests`
- `feat: add Codable model structs with Supabase JSON decoding tests`
- `feat: add AppTheme, Constants, and Date extensions`
- `feat: set AccentColor to lime #C8FF00, add GymPurple #9B7FE8`
- `feat: add SupabaseClient singleton and AuthService with Apple Sign-In`
- `feat: add four Supabase repositories and RepositoryError`
- `feat: add SignInView with Apple Sign-In and RootView auth gate`
- `feat: wire RootView entry point and localize auth UI`

**Known issues / deviations from plan:**
- Available simulator is **iPhone 17e**, not iPhone 16 — substitute `name=iPhone 17e` in all xcodebuild commands
- **`Color.gymPurple` is NOT declared in `AppTheme.swift`** — Xcode 16 auto-generates it from `GymPurple.colorset`. Using `.gymPurple` in SwiftUI code works fine via the auto-generated symbol. Do NOT add it back manually.
- `AppTheme.swift` line 7 has minor indentation issue on `gymSurface` (cosmetic only, does not affect build)
- Supabase + KeychainAccess Swift packages are **already added** in Xcode — skip that user gate
- Capabilities (Sign in with Apple, HealthKit) are present in `Gymbros/Gymbros.entitlements`
- Task 8 now includes `SignInViewModel` so Apple Sign-In nonce/error handling lives in the presentation ViewModel instead of the SwiftUI view.
- Localization follows device language: Thai devices use Thai; all other device languages use English. Sprint 6 adds an easy Settings language override.
- Task 9.5 was added after the first repository/auth pass to remove `RepositoryError` and raw `String? errorMessage` patterns, replacing them with typed `AppError`, Swift standard `Result<Value, AppError>`, shared `ViewState`, and unit tests.

**Next step:** Proceed to Task 9.5 — standard Swift `Result<Value, AppError>` error-handling foundation and unit tests, then Task 10 Supabase setup and manual simulator verification.

---

**Architecture:** MVVM + Repository. Models are pure `Codable` structs with explicit `CodingKeys` mapping Swift camelCase ↔ Supabase snake_case. `AuthService` is a `@MainActor @Observable` singleton. Repositories are `@MainActor` classes wrapping Supabase queries. `RootView` gates between `SignInView` and a placeholder home view based on `AuthService.isAuthenticated`.

**Tech Stack:** SwiftUI, `@Observable` (iOS 17+), Supabase Swift SDK v2, AuthenticationServices + CryptoKit (Apple Sign-In nonce), Swift Testing (unit tests)

---

## Important Constraints

- **Module name is `Gymbros`** (not `GymBros`) — all `@testable import` must use `Gymbros`
- **Tests use Swift Testing** (`import Testing`, `#expect(...)`) — not XCTest
- **Two user-gated Xcode steps** block compilation of the Data layer:
  1. Add Swift packages (Supabase + KeychainAccess) — required before Task 6
  2. Add capabilities (Sign in with Apple, HealthKit) — required before Task 8
- **File system sync**: Xcode auto-discovers files in the `Gymbros/` folder — just create folders on disk
- **Existing files to handle**: `Gymbros/GymbrosApp.swift` (update), `Gymbros/ContentView.swift` (delete in Task 9)

---

## Files Map

| File | Action |
|------|--------|
| `supabase/schema.sql` | Create |
| `supabase/seed_exercises.sql` | Create |
| `Gymbros/Model/Enums/MovementPattern.swift` | Create |
| `Gymbros/Model/Enums/MuscleGroup.swift` | Create |
| `Gymbros/Model/Enums/Equipment.swift` | Create |
| `Gymbros/Model/Enums/ExperienceLevel.swift` | Create |
| `Gymbros/Model/Enums/Goal.swift` | Create |
| `Gymbros/Model/Enums/WeightUnit.swift` | Create |
| `Gymbros/Model/Enums/TrainingPhase.swift` | Create |
| `Gymbros/Model/Profile.swift` | Create |
| `Gymbros/Model/Exercise.swift` | Create |
| `Gymbros/Model/Program.swift` | Create |
| `Gymbros/Model/ProgramDay.swift` | Create |
| `Gymbros/Model/ProgramExercise.swift` | Create |
| `Gymbros/Model/WorkoutSession.swift` | Create |
| `Gymbros/Model/WorkoutSet.swift` | Create |
| `Gymbros/Core/AppTheme.swift` | Create |
| `Gymbros/Core/Constants.swift` | Create |
| `Gymbros/Core/Extensions/Date+Extensions.swift` | Create |
| `Gymbros/Core/ErrorHandling/AppError.swift` | Create |
| `Gymbros/Core/ErrorHandling/ErrorMapper.swift` | Create |
| `Gymbros/Core/ErrorHandling/ViewState.swift` | Create |
| `Gymbros/Assets.xcassets/AccentColor.colorset/Contents.json` | Modify |
| `Gymbros/Assets.xcassets/GymPurple.colorset/Contents.json` | Create |
| `Gymbros/Data/Remote/SupabaseClient.swift` | Create |
| `Gymbros/Data/Remote/AuthService.swift` | Create |
| `Gymbros/Data/Repository/RepositoryError.swift` | Delete in Task 9.5 |
| `Gymbros/Data/Repository/ProfileRepository.swift` | Create |
| `Gymbros/Data/Repository/ExerciseRepository.swift` | Create |
| `Gymbros/Data/Repository/ProgramRepository.swift` | Create |
| `Gymbros/Data/Repository/WorkoutRepository.swift` | Create |
| `Gymbros/Presentation/Auth/SignInView.swift` | Create |
| `Gymbros/App/RootView.swift` | Create |
| `Gymbros/GymbrosApp.swift` | Modify |
| `Gymbros/ContentView.swift` | Delete |
| `GymbrosTests/EnumsTests.swift` | Create |
| `GymbrosTests/CodableTests.swift` | Create |
| `GymbrosTests/ErrorHandlingTests.swift` | Create |

---

## Task 1: Supabase SQL Files

**Files:**
- Create: `supabase/schema.sql`
- Create: `supabase/seed_exercises.sql`

No Xcode involvement. These are run manually in the Supabase SQL editor in Task 10.

- [x] **Step 1: Create `supabase/schema.sql`**

```sql
-- User profile (extends Supabase auth.users)
create table public.profiles (
    id uuid references auth.users on delete cascade primary key,
    name text,
    experience_level text,
    goal text,
    days_per_week int,
    weight_unit text default 'kg' not null,
    locale text default 'th' not null,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

-- Master exercise library (shared, read-only for users)
create table public.exercises (
    id uuid primary key default gen_random_uuid(),
    name_en text not null,
    name_th text not null,
    movement_pattern text not null,
    primary_muscle text not null,
    secondary_muscles text[] default '{}' not null,
    equipment text not null,
    is_compound boolean default false not null,
    created_at timestamptz default now() not null
);

-- User-created programs
create table public.programs (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade not null,
    name text not null,
    description text,
    is_active boolean default false not null,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

-- Days within a program
create table public.program_days (
    id uuid primary key default gen_random_uuid(),
    program_id uuid references public.programs(id) on delete cascade not null,
    name text not null,
    day_order int not null,
    created_at timestamptz default now() not null
);

-- Exercises within a day
create table public.program_exercises (
    id uuid primary key default gen_random_uuid(),
    program_day_id uuid references public.program_days(id) on delete cascade not null,
    exercise_id uuid references public.exercises(id) not null,
    target_sets int not null default 3,
    target_reps_min int not null default 8,
    target_reps_max int not null default 12,
    rest_seconds int not null default 90,
    exercise_order int not null,
    notes text,
    created_at timestamptz default now() not null
);

-- Logged workout sessions
create table public.workout_sessions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid references public.profiles(id) on delete cascade not null,
    program_day_id uuid references public.program_days(id),
    started_at timestamptz not null,
    ended_at timestamptz,
    notes text,
    created_at timestamptz default now() not null
);

-- Sets logged in a session
create table public.workout_sets (
    id uuid primary key default gen_random_uuid(),
    session_id uuid references public.workout_sessions(id) on delete cascade not null,
    exercise_id uuid references public.exercises(id) not null,
    set_number int not null,
    weight numeric(6,2) not null,
    reps int not null,
    rpe numeric(3,1),
    completed_at timestamptz default now() not null,
    notes text
);

-- Indexes
create index idx_programs_user on public.programs(user_id);
create index idx_programs_active on public.programs(user_id, is_active) where is_active = true;
create index idx_program_days_program on public.program_days(program_id, day_order);
create index idx_program_exercises_day on public.program_exercises(program_day_id, exercise_order);
create index idx_sessions_user on public.workout_sessions(user_id);
create index idx_sessions_started on public.workout_sessions(started_at desc);
create index idx_sets_session on public.workout_sets(session_id);
create index idx_sets_exercise_user on public.workout_sets(exercise_id, completed_at desc);
create index idx_exercises_pattern on public.exercises(movement_pattern);
create index idx_exercises_muscle on public.exercises(primary_muscle);

-- RLS
alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.programs enable row level security;
alter table public.program_days enable row level security;
alter table public.program_exercises enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_sets enable row level security;

create policy "Users can view own profile" on public.profiles
    for select using (auth.uid() = id);
create policy "Users can insert own profile" on public.profiles
    for insert with check (auth.uid() = id);
create policy "Users can update own profile" on public.profiles
    for update using (auth.uid() = id);

create policy "Authenticated users can view exercises" on public.exercises
    for select using (auth.uid() is not null);

create policy "Users can view own programs" on public.programs
    for select using (auth.uid() = user_id);
create policy "Users can create own programs" on public.programs
    for insert with check (auth.uid() = user_id);
create policy "Users can update own programs" on public.programs
    for update using (auth.uid() = user_id);
create policy "Users can delete own programs" on public.programs
    for delete using (auth.uid() = user_id);

create policy "Users can manage own program days" on public.program_days
    for all using (
        exists (
            select 1 from public.programs
            where programs.id = program_days.program_id
            and programs.user_id = auth.uid()
        )
    );

create policy "Users can manage own program exercises" on public.program_exercises
    for all using (
        exists (
            select 1 from public.program_days
            join public.programs on programs.id = program_days.program_id
            where program_days.id = program_exercises.program_day_id
            and programs.user_id = auth.uid()
        )
    );

create policy "Users can view own sessions" on public.workout_sessions
    for select using (auth.uid() = user_id);
create policy "Users can create own sessions" on public.workout_sessions
    for insert with check (auth.uid() = user_id);
create policy "Users can update own sessions" on public.workout_sessions
    for update using (auth.uid() = user_id);
create policy "Users can delete own sessions" on public.workout_sessions
    for delete using (auth.uid() = user_id);

create policy "Users can manage own sets" on public.workout_sets
    for all using (
        exists (
            select 1 from public.workout_sessions
            where workout_sessions.id = workout_sets.session_id
            and workout_sessions.user_id = auth.uid()
        )
    );

-- Triggers
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
    insert into public.profiles (id, name)
    values (new.id, coalesce(new.raw_user_meta_data->>'full_name', null));
    return new;
end;
$$;

revoke all on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

create or replace function public.handle_updated_at()
returns trigger language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger profiles_updated_at
    before update on public.profiles
    for each row execute procedure public.handle_updated_at();

create trigger programs_updated_at
    before update on public.programs
    for each row execute procedure public.handle_updated_at();

create or replace function public.ensure_single_active_program()
returns trigger language plpgsql
as $$
begin
    if new.is_active = true then
        update public.programs
        set is_active = false
        where user_id = new.user_id
          and id != new.id
          and is_active = true;
    end if;
    return new;
end;
$$;

create trigger single_active_program
    before insert or update on public.programs
    for each row execute procedure public.ensure_single_active_program();
```

- [x] **Step 2: Create `supabase/seed_exercises.sql`**

```sql
insert into public.exercises (name_en, name_th, movement_pattern, primary_muscle, secondary_muscles, equipment, is_compound) values
('Barbell Back Squat', 'สควอทบาร์เบล', 'squat', 'quads', '{glutes,hamstrings,core}', 'barbell', true),
('Barbell Front Squat', 'สควอทบาร์หน้า', 'squat', 'quads', '{glutes,core}', 'barbell', true),
('Barbell Deadlift', 'เดดลิฟท์บาร์เบล', 'hinge', 'hamstrings', '{glutes,back,core}', 'barbell', true),
('Romanian Deadlift', 'โรมาเนียนเดดลิฟท์', 'hinge', 'hamstrings', '{glutes,back}', 'barbell', true),
('Sumo Deadlift', 'ซูโม่เดดลิฟท์', 'hinge', 'hamstrings', '{glutes,quads,back}', 'barbell', true),
('Barbell Bench Press', 'เบนช์เพรสบาร์เบล', 'push', 'chest', '{shoulders,triceps}', 'barbell', true),
('Barbell Incline Bench Press', 'อินไคลน์เบนช์เพรส', 'push', 'chest', '{shoulders,triceps}', 'barbell', true),
('Barbell Overhead Press', 'โอเวอร์เฮดเพรสบาร์เบล', 'push', 'shoulders', '{triceps,core}', 'barbell', true),
('Barbell Bent Over Row', 'เบนท์โอเวอร์โรว์', 'pull', 'back', '{biceps,traps}', 'barbell', true),
('Barbell Pendlay Row', 'เพนเดลย์โรว์', 'pull', 'back', '{biceps,traps}', 'barbell', true),
('Barbell Hip Thrust', 'ฮิปทรัสต์บาร์เบล', 'hinge', 'glutes', '{hamstrings}', 'barbell', true),
('Dumbbell Bench Press', 'เบนช์เพรสดัมเบล', 'push', 'chest', '{shoulders,triceps}', 'dumbbell', true),
('Dumbbell Incline Press', 'อินไคลน์เพรสดัมเบล', 'push', 'chest', '{shoulders,triceps}', 'dumbbell', true),
('Dumbbell Shoulder Press', 'โชลเดอร์เพรสดัมเบล', 'push', 'shoulders', '{triceps}', 'dumbbell', true),
('Dumbbell Row', 'ดัมเบลโรว์', 'pull', 'back', '{biceps,traps}', 'dumbbell', true),
('Dumbbell Romanian Deadlift', 'โรมาเนียนเดดลิฟท์ดัมเบล', 'hinge', 'hamstrings', '{glutes}', 'dumbbell', true),
('Dumbbell Lunge', 'ลันจ์ดัมเบล', 'lunge', 'quads', '{glutes,hamstrings}', 'dumbbell', true),
('Dumbbell Bulgarian Split Squat', 'บัลแกเรียนสปลิทสควอท', 'lunge', 'quads', '{glutes}', 'dumbbell', true),
('Dumbbell Goblet Squat', 'กอบเล็ทสควอท', 'squat', 'quads', '{glutes,core}', 'dumbbell', true),
('Dumbbell Lateral Raise', 'ไซด์เลทเทอรัล', 'push', 'shoulders', '{}', 'dumbbell', false),
('Dumbbell Front Raise', 'ฟรอนเรซดัมเบล', 'push', 'shoulders', '{}', 'dumbbell', false),
('Dumbbell Rear Delt Fly', 'รีเดลฟลายดัมเบล', 'pull', 'shoulders', '{}', 'dumbbell', false),
('Dumbbell Bicep Curl', 'ไบเซ็พเคิลดัมเบล', 'pull', 'biceps', '{}', 'dumbbell', false),
('Dumbbell Hammer Curl', 'แฮมเมอร์เคิล', 'pull', 'biceps', '{forearms}', 'dumbbell', false),
('Dumbbell Tricep Extension', 'ไตรเซ็พเอ็กซ์เทนชัน', 'push', 'triceps', '{}', 'dumbbell', false),
('Dumbbell Skull Crusher', 'สกัลครัชเชอร์', 'push', 'triceps', '{}', 'dumbbell', false),
('Dumbbell Fly', 'ฟลายดัมเบล', 'push', 'chest', '{}', 'dumbbell', false),
('Dumbbell Pullover', 'พูลโอเวอร์ดัมเบล', 'pull', 'back', '{chest}', 'dumbbell', false),
('Dumbbell Shrug', 'ชรักดัมเบล', 'pull', 'traps', '{}', 'dumbbell', false),
('Machine Chest Press', 'เครื่องเพรสอก', 'push', 'chest', '{shoulders,triceps}', 'machine', true),
('Machine Incline Chest Press', 'เครื่องเพรสอกบน', 'push', 'chest', '{shoulders,triceps}', 'machine', true),
('Machine Shoulder Press', 'เครื่องเพรสไหล่', 'push', 'shoulders', '{triceps}', 'machine', true),
('Machine Lat Pulldown', 'แลทพูลดาวน์', 'pull', 'back', '{biceps}', 'machine', true),
('Machine Seated Row', 'ซีตโรว์', 'pull', 'back', '{biceps,traps}', 'machine', true),
('Machine Chest Fly', 'เพคเด็ค', 'push', 'chest', '{}', 'machine', false),
('Machine Rear Delt Fly', 'เครื่องรีเดลฟลาย', 'pull', 'shoulders', '{}', 'machine', false),
('Leg Press', 'เลกเพรส', 'squat', 'quads', '{glutes,hamstrings}', 'machine', true),
('Hack Squat', 'แฮคสควอท', 'squat', 'quads', '{glutes}', 'machine', true),
('Leg Extension', 'เลกเอ็กซ์เทนชัน', 'squat', 'quads', '{}', 'machine', false),
('Leg Curl (Lying)', 'เลกเคิลนอน', 'hinge', 'hamstrings', '{}', 'machine', false),
('Leg Curl (Seated)', 'เลกเคิลนั่ง', 'hinge', 'hamstrings', '{}', 'machine', false),
('Calf Raise (Standing)', 'แคล์ฟเรซยืน', 'core', 'calves', '{}', 'machine', false),
('Calf Raise (Seated)', 'แคล์ฟเรซนั่ง', 'core', 'calves', '{}', 'machine', false),
('Smith Machine Bench Press', 'สมิธมาชีนเบนช์', 'push', 'chest', '{shoulders,triceps}', 'machine', true),
('Smith Machine Squat', 'สมิธมาชีนสควอท', 'squat', 'quads', '{glutes}', 'machine', true),
('Hip Abductor Machine', 'เครื่องสะโพกออก', 'core', 'glutes', '{}', 'machine', false),
('Hip Adductor Machine', 'เครื่องสะโพกใน', 'core', 'glutes', '{}', 'machine', false),
('Glute Kickback Machine', 'เครื่องคิกแบ็คก้น', 'hinge', 'glutes', '{hamstrings}', 'machine', false),
('Cable Lat Pulldown (Wide Grip)', 'พูลดาวน์เคเบิลกว้าง', 'pull', 'back', '{biceps}', 'cable', true),
('Cable Lat Pulldown (Close Grip)', 'พูลดาวน์เคเบิลแคบ', 'pull', 'back', '{biceps}', 'cable', true),
('Cable Row (Seated)', 'เคเบิลโรว์', 'pull', 'back', '{biceps,traps}', 'cable', true),
('Cable Face Pull', 'เฟซพูล', 'pull', 'shoulders', '{traps}', 'cable', false),
('Cable Tricep Pushdown', 'ทรายเซ็พพุชดาวน์', 'push', 'triceps', '{}', 'cable', false),
('Cable Tricep Rope Extension', 'ทรายเซ็พโรปเอ็กซ์เทนชัน', 'push', 'triceps', '{}', 'cable', false),
('Cable Bicep Curl', 'เคเบิลไบเซ็พเคิล', 'pull', 'biceps', '{}', 'cable', false),
('Cable Lateral Raise', 'เคเบิลไซด์เรซ', 'push', 'shoulders', '{}', 'cable', false),
('Cable Chest Fly', 'เคเบิลเชสฟลาย', 'push', 'chest', '{}', 'cable', false),
('Cable Crossover', 'เคเบิลครอสโอเวอร์', 'push', 'chest', '{}', 'cable', false),
('Cable Pull-Through', 'เคเบิลพูลทรู', 'hinge', 'glutes', '{hamstrings}', 'cable', false),
('Cable Crunch', 'เคเบิลครันช์', 'core', 'core', '{}', 'cable', false),
('Pull-Up', 'พูลอัพ', 'pull', 'back', '{biceps}', 'bodyweight', true),
('Chin-Up', 'ชินอัพ', 'pull', 'back', '{biceps}', 'bodyweight', true),
('Push-Up', 'พุชอัพ', 'push', 'chest', '{shoulders,triceps,core}', 'bodyweight', true),
('Dip', 'ดิป', 'push', 'chest', '{triceps,shoulders}', 'bodyweight', true),
('Bodyweight Squat', 'สควอทตัวเปล่า', 'squat', 'quads', '{glutes}', 'bodyweight', false),
('Bodyweight Lunge', 'ลันจ์ตัวเปล่า', 'lunge', 'quads', '{glutes,hamstrings}', 'bodyweight', false),
('Plank', 'แพลงก์', 'core', 'core', '{}', 'bodyweight', false),
('Side Plank', 'ไซด์แพลงก์', 'core', 'core', '{}', 'bodyweight', false),
('Glute Bridge', 'กลูตบริดจ์', 'hinge', 'glutes', '{hamstrings}', 'bodyweight', false),
('Hanging Leg Raise', 'แฮงกิ้งเลกเรซ', 'core', 'core', '{}', 'bodyweight', false),
('Hanging Knee Raise', 'แฮงกิ้งนีเรซ', 'core', 'core', '{}', 'bodyweight', false),
('Mountain Climber', 'เมาน์เทนไคลม์เบอร์', 'core', 'core', '{}', 'bodyweight', false),
('Burpee', 'เบอร์ปี', 'core', 'core', '{}', 'bodyweight', false),
('Kettlebell Swing', 'เคทเทิลเบลสวิง', 'hinge', 'glutes', '{hamstrings,back}', 'kettlebell', true),
('Kettlebell Goblet Squat', 'เคทเทิลกอบเล็ทสควอท', 'squat', 'quads', '{glutes,core}', 'kettlebell', true),
('Kettlebell Clean', 'เคทเทิลคลีน', 'pull', 'back', '{glutes,shoulders}', 'kettlebell', true),
('Kettlebell Press', 'เคทเทิลเพรส', 'push', 'shoulders', '{triceps}', 'kettlebell', true),
('Kettlebell Row', 'เคทเทิลโรว์', 'pull', 'back', '{biceps}', 'kettlebell', true),
('Turkish Get-Up', 'เทอร์กิชเก็ทอัพ', 'core', 'core', '{shoulders}', 'kettlebell', true),
('Barbell Curl', 'เคิลบาร์เบล', 'pull', 'biceps', '{}', 'barbell', false),
('Barbell Skull Crusher', 'สกัลครัชเชอร์บาร์เบล', 'push', 'triceps', '{}', 'barbell', false),
('Barbell Shrug', 'ชรักบาร์เบล', 'pull', 'traps', '{}', 'barbell', false),
('Barbell Calf Raise', 'แคล์ฟเรซบาร์เบล', 'core', 'calves', '{}', 'barbell', false),
('Barbell Good Morning', 'กู๊ดมอร์นิ่ง', 'hinge', 'hamstrings', '{back,glutes}', 'barbell', true),
('Barbell Reverse Lunge', 'รีเวิร์สลันจ์', 'lunge', 'quads', '{glutes,hamstrings}', 'barbell', true),
('Close Grip Bench Press', 'โคลสกริปเบนช์', 'push', 'triceps', '{chest,shoulders}', 'barbell', true),
('Incline Bench Press', 'อินไคลน์เบนช์', 'push', 'chest', '{shoulders,triceps}', 'barbell', true),
('Decline Bench Press', 'ดีไคลน์เบนช์', 'push', 'chest', '{triceps}', 'barbell', true),
('Dumbbell Step-Up', 'สเต็พอัพดัมเบล', 'lunge', 'quads', '{glutes}', 'dumbbell', true),
('Dumbbell Reverse Lunge', 'รีเวิร์สลันจ์ดัมเบล', 'lunge', 'quads', '{glutes,hamstrings}', 'dumbbell', true),
('Dumbbell Walking Lunge', 'วอล์กกิ้งลันจ์', 'lunge', 'quads', '{glutes,hamstrings}', 'dumbbell', true),
('Dumbbell Side Lateral', 'ดัมเบลไซด์เลทเทอรัล', 'push', 'shoulders', '{}', 'dumbbell', false),
('Dumbbell Concentration Curl', 'คอนเซนเทรชันเคิล', 'pull', 'biceps', '{}', 'dumbbell', false),
('Dumbbell Reverse Fly', 'รีเวิร์สฟลาย', 'pull', 'shoulders', '{traps}', 'dumbbell', false),
('Band Pull-Apart', 'แบนด์พูลอะพาร์ท', 'pull', 'shoulders', '{traps}', 'band', false),
('Band Face Pull', 'แบนด์เฟซพูล', 'pull', 'shoulders', '{traps}', 'band', false),
('Band Tricep Pushdown', 'แบนด์ทรายเซ็พ', 'push', 'triceps', '{}', 'band', false),
('Band Bicep Curl', 'แบนด์ไบเซ็พ', 'pull', 'biceps', '{}', 'band', false);

select count(*) as exercise_count from public.exercises;
-- Should be 95
```

- [x] **Step 3: Commit**

```bash
git add supabase/
git commit -m "feat: add Supabase schema and exercise seed data"
```

---

## Task 2: Enums (TDD)

**Files:**
- Create: `GymbrosTests/EnumsTests.swift`
- Create: `Gymbros/Model/Enums/MovementPattern.swift`
- Create: `Gymbros/Model/Enums/MuscleGroup.swift`
- Create: `Gymbros/Model/Enums/Equipment.swift`
- Create: `Gymbros/Model/Enums/ExperienceLevel.swift`
- Create: `Gymbros/Model/Enums/Goal.swift`
- Create: `Gymbros/Model/Enums/WeightUnit.swift`
- Create: `Gymbros/Model/Enums/TrainingPhase.swift`

- [x] **Step 1: Write failing test — `GymbrosTests/EnumsTests.swift`**

```swift
import Testing
@testable import Gymbros

@Suite("Enum Tests")
struct EnumsTests {

    @Test func goalRawValuesMatchDatabase() {
        #expect(Goal.fatLoss.rawValue == "fat_loss")
        #expect(Goal.strength.rawValue == "strength")
        #expect(Goal.muscle.rawValue == "muscle")
        #expect(Goal.general.rawValue == "general")
    }

    @Test func movementPatternRoundTripsJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for pattern in MovementPattern.allCases {
            let data = try encoder.encode(pattern)
            let decoded = try decoder.decode(MovementPattern.self, from: data)
            #expect(pattern == decoded)
        }
    }

    @Test func muscleGroupRoundTripsJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for muscle in MuscleGroup.allCases {
            let data = try encoder.encode(muscle)
            let decoded = try decoder.decode(MuscleGroup.self, from: data)
            #expect(muscle == decoded)
        }
    }

    @Test func equipmentRoundTripsJSON() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for equip in Equipment.allCases {
            let data = try encoder.encode(equip)
            let decoded = try decoder.decode(Equipment.self, from: data)
            #expect(equip == decoded)
        }
    }

    @Test func weightUnitRawValues() {
        #expect(WeightUnit.kg.rawValue == "kg")
        #expect(WeightUnit.lb.rawValue == "lb")
    }
}
```

- [x] **Step 2: Try to build — confirm it fails with "cannot find type 'Goal'"**

```bash
cd /Users/nattapongsawa/Desktop/Gymbros
xcodebuild build -project Gymbros.xcodeproj -scheme Gymbros -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep error: | head -10
```

Expected output: errors about missing types (`Goal`, `MovementPattern`, etc.)

- [x] **Step 3: Create enum files**

Create `Gymbros/Model/Enums/MovementPattern.swift`:
```swift
import Foundation

enum MovementPattern: String, Codable, CaseIterable {
    case push, pull, squat, hinge, lunge, carry, core
}
```

Create `Gymbros/Model/Enums/MuscleGroup.swift`:
```swift
import Foundation

enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves, core
    case forearms, traps
}
```

Create `Gymbros/Model/Enums/Equipment.swift`:
```swift
import Foundation

enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, machine, cable
    case bodyweight, kettlebell, band
}
```

Create `Gymbros/Model/Enums/ExperienceLevel.swift`:
```swift
import Foundation

enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner, intermediate, advanced
}
```

Create `Gymbros/Model/Enums/Goal.swift`:
```swift
import Foundation

enum Goal: String, Codable, CaseIterable {
    case strength, muscle, fatLoss = "fat_loss", general
}
```

Create `Gymbros/Model/Enums/WeightUnit.swift`:
```swift
import Foundation

enum WeightUnit: String, Codable, CaseIterable {
    case kg, lb
}
```

Create `Gymbros/Model/Enums/TrainingPhase.swift`:
```swift
import Foundation

enum TrainingPhase: String, Codable, CaseIterable {
    case bulk, cut, maintain
}
```

- [x] **Step 4: Run tests — confirm they pass**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:GymbrosTests/EnumsTests 2>&1 | grep -E "Test (Suite|Case|session)" | tail -20
```

Expected: All 5 tests pass. No failures.

- [x] **Step 5: Commit**

```bash
git add Gymbros/Model/Enums/ GymbrosTests/EnumsTests.swift
git commit -m "feat: add model enums with JSON round-trip tests"
```

---

## Task 3: Model Structs (TDD)

**Files:**
- Create: `GymbrosTests/CodableTests.swift`
- Create: `Gymbros/Model/Profile.swift`
- Create: `Gymbros/Model/Exercise.swift`
- Create: `Gymbros/Model/Program.swift`
- Create: `Gymbros/Model/ProgramDay.swift`
- Create: `Gymbros/Model/ProgramExercise.swift`
- Create: `Gymbros/Model/WorkoutSession.swift`
- Create: `Gymbros/Model/WorkoutSet.swift`

- [x] **Step 1: Write failing test — `GymbrosTests/CodableTests.swift`**

```swift
import Testing
import Foundation
@testable import Gymbros

@Suite("Codable Tests")
struct CodableTests {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    @Test func exerciseDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "name_en": "Bench Press",
            "name_th": "เบนช์เพรส",
            "movement_pattern": "push",
            "primary_muscle": "chest",
            "secondary_muscles": ["shoulders", "triceps"],
            "equipment": "barbell",
            "is_compound": true,
            "created_at": "2026-05-08T10:00:00Z"
        }
        """.data(using: .utf8)!

        let exercise = try decoder.decode(Exercise.self, from: json)

        #expect(exercise.nameEn == "Bench Press")
        #expect(exercise.nameTh == "เบนช์เพรส")
        #expect(exercise.movementPattern == .push)
        #expect(exercise.primaryMuscle == .chest)
        #expect(exercise.secondaryMuscles == [.shoulders, .triceps])
        #expect(exercise.equipment == .barbell)
        #expect(exercise.isCompound == true)
    }

    @Test func programEncodesWithSnakeCaseKeys() throws {
        let program = Program(
            id: UUID(),
            userId: UUID(),
            name: "My Program",
            description: "Test",
            isActive: true,
            createdAt: Date(),
            updatedAt: Date()
        )

        let data = try encoder.encode(program)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(json["user_id"] != nil)
        #expect(json["is_active"] != nil)
        #expect(json["created_at"] != nil)
        #expect(json["updated_at"] != nil)
        #expect(json["userId"] == nil)
        #expect(json["days"] == nil)   // not in CodingKeys — must not appear
    }

    @Test func workoutSessionIsCompleteFlag() {
        let incomplete = WorkoutSession(
            id: UUID(), userId: UUID(), programDayId: nil,
            startedAt: Date(), endedAt: nil, notes: nil, createdAt: Date()
        )
        let complete = WorkoutSession(
            id: UUID(), userId: UUID(), programDayId: nil,
            startedAt: Date(), endedAt: Date(), notes: nil, createdAt: Date()
        )

        #expect(incomplete.isComplete == false)
        #expect(complete.isComplete == true)
        #expect(complete.duration != nil)
    }

    @Test func workoutSetDecodesFromJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "session_id": "550e8400-e29b-41d4-a716-446655440002",
            "exercise_id": "550e8400-e29b-41d4-a716-446655440003",
            "set_number": 1,
            "weight": 80.0,
            "reps": 8,
            "rpe": 7.5,
            "completed_at": "2026-05-08T10:00:00Z"
        }
        """.data(using: .utf8)!

        let set = try decoder.decode(WorkoutSet.self, from: json)

        #expect(set.setNumber == 1)
        #expect(set.weight == 80.0)
        #expect(set.reps == 8)
        #expect(set.rpe == 7.5)
    }
}
```

- [x] **Step 2: Confirm build fails with "cannot find type 'Exercise'"**

```bash
xcodebuild build -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep error: | head -10
```

Expected: errors about `Exercise`, `Program`, `WorkoutSession`, `WorkoutSet` not found.

- [x] **Step 3: Create model files**

Create `Gymbros/Model/Profile.swift`:
```swift
import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String?
    var experienceLevel: ExperienceLevel?
    var goal: Goal?
    var daysPerWeek: Int?
    var weightUnit: WeightUnit
    var locale: String
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, goal, locale
        case experienceLevel = "experience_level"
        case daysPerWeek = "days_per_week"
        case weightUnit = "weight_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

Create `Gymbros/Model/Exercise.swift`:
```swift
import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    let nameEn: String
    let nameTh: String
    let movementPattern: MovementPattern
    let primaryMuscle: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let equipment: Equipment
    let isCompound: Bool
    let createdAt: Date

    var localizedName: String {
        Locale.current.language.languageCode?.identifier == "th" ? nameTh : nameEn
    }

    enum CodingKeys: String, CodingKey {
        case id, equipment
        case nameEn = "name_en"
        case nameTh = "name_th"
        case movementPattern = "movement_pattern"
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
        case isCompound = "is_compound"
        case createdAt = "created_at"
    }
}
```

Create `Gymbros/Model/Program.swift`:
```swift
import Foundation

struct Program: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var name: String
    var description: String?
    var isActive: Bool
    let createdAt: Date
    var updatedAt: Date

    var days: [ProgramDay] = []

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case userId = "user_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

Create `Gymbros/Model/ProgramDay.swift`:
```swift
import Foundation

struct ProgramDay: Codable, Identifiable, Equatable {
    let id: UUID
    let programId: UUID
    var name: String
    var dayOrder: Int
    let createdAt: Date

    var exercises: [ProgramExercise] = []

    enum CodingKeys: String, CodingKey {
        case id, name
        case programId = "program_id"
        case dayOrder = "day_order"
        case createdAt = "created_at"
    }
}
```

Create `Gymbros/Model/ProgramExercise.swift`:
```swift
import Foundation

struct ProgramExercise: Codable, Identifiable, Equatable {
    let id: UUID
    let programDayId: UUID
    let exerciseId: UUID
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var restSeconds: Int
    var exerciseOrder: Int
    var notes: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, notes
        case programDayId = "program_day_id"
        case exerciseId = "exercise_id"
        case targetSets = "target_sets"
        case targetRepsMin = "target_reps_min"
        case targetRepsMax = "target_reps_max"
        case restSeconds = "rest_seconds"
        case exerciseOrder = "exercise_order"
        case createdAt = "created_at"
    }
}
```

Create `Gymbros/Model/WorkoutSession.swift`:
```swift
import Foundation

struct WorkoutSession: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    var programDayId: UUID?
    var startedAt: Date
    var endedAt: Date?
    var notes: String?
    let createdAt: Date

    var sets: [WorkoutSet] = []

    var isComplete: Bool { endedAt != nil }
    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    enum CodingKeys: String, CodingKey {
        case id, notes
        case userId = "user_id"
        case programDayId = "program_day_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case createdAt = "created_at"
    }
}
```

Create `Gymbros/Model/WorkoutSet.swift`:
```swift
import Foundation

struct WorkoutSet: Codable, Identifiable, Equatable {
    let id: UUID
    let sessionId: UUID
    let exerciseId: UUID
    var setNumber: Int
    var weight: Double
    var reps: Int
    var rpe: Double?
    var completedAt: Date
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, weight, reps, rpe, notes
        case sessionId = "session_id"
        case exerciseId = "exercise_id"
        case setNumber = "set_number"
        case completedAt = "completed_at"
    }
}
```

- [x] **Step 4: Run tests — confirm all pass**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:GymbrosTests/CodableTests 2>&1 | grep -E "(passed|failed|error)" | tail -20
```

Expected: 4 tests pass, 0 fail.

- [x] **Step 5: Commit**

```bash
git add Gymbros/Model/ GymbrosTests/CodableTests.swift
git commit -m "feat: add Codable model structs with Supabase JSON decoding tests"
```

---

## Task 4: Core Layer

**Files:**
- Create: `Gymbros/Core/AppTheme.swift`
- Create: `Gymbros/Core/Constants.swift`
- Create: `Gymbros/Core/Extensions/Date+Extensions.swift`

No tests needed for these — pure extensions and constants.

- [x] **Step 1: Create `Gymbros/Core/AppTheme.swift`**

```swift
import SwiftUI

extension Color {
    /// Primary interactive — electric lime #C8FF00
    static let gymAccent = Color("AccentColor")

    /// Special states — purple #9B7FE8
    static let gymPurple = Color("GymPurple")

    static let gymSurface = Color(.secondarySystemBackground)
    static let gymBackground = Color(.systemBackground)
}

extension Font {
    static func gymNumber(size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
```

- [x] **Step 2: Create `Gymbros/Core/Constants.swift`**

```swift
import Foundation

enum AppConstants {
    enum Supabase {
        // Replace with your actual values from supabase.com → Project Settings → API
        static let url = URL(string: "https://YOUR_PROJECT.supabase.co")!
        static let anonKey = "YOUR_ANON_KEY"
    }

    enum Workout {
        static let smallestPlateKg: Double = 2.5
        static let smallestPlateLb: Double = 5.0
        static let defaultRestSeconds = 90
        static let minRPE: Double = 1.0
        static let maxRPE: Double = 10.0
    }

    enum Storage {
        static let activeSessionKey = "active_session_backup"
    }
}
```

- [x] **Step 3: Create `Gymbros/Core/Extensions/Date+Extensions.swift`**

```swift
import Foundation

extension Date {
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: self, relativeTo: .now)
    }

    var workoutDisplayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}
```

- [x] **Step 4: Build to confirm no errors**

```bash
xcodebuild build -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD" | tail -5
```

Expected: `BUILD SUCCEEDED`

- [x] **Step 5: Commit**

```bash
git add Gymbros/Core/
git commit -m "feat: add AppTheme, Constants, and Date extensions"
```

---

## Task 5: Asset Colors

**Files:**
- Modify: `Gymbros/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `Gymbros/Assets.xcassets/GymPurple.colorset/Contents.json`

- [x] **Step 1: Update AccentColor to electric lime #C8FF00**

Overwrite `Gymbros/Assets.xcassets/AccentColor.colorset/Contents.json`:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.000",
          "green" : "1.000",
          "red" : "0.784"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [x] **Step 2: Create GymPurple color set #9B7FE8**

Create directory `Gymbros/Assets.xcassets/GymPurple.colorset/`, then create `Contents.json`:
```json
{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : {
          "alpha" : "1.000",
          "blue" : "0.910",
          "green" : "0.498",
          "red" : "0.608"
        }
      },
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [x] **Step 3: Commit**

```bash
git add Gymbros/Assets.xcassets/
git commit -m "feat: set AccentColor to lime #C8FF00, add GymPurple #9B7FE8"
```

---

## ⚠️ USER GATE: Add Swift Packages in Xcode

**Before proceeding to Task 6, the user must add packages in Xcode:**

1. Open `Gymbros.xcodeproj` in Xcode
2. **File → Add Package Dependencies…**
3. Add: `https://github.com/supabase/supabase-swift` → select "Up to Next Major Version" from **2.0.0** → add **Supabase** product to the Gymbros target
4. Add: `https://github.com/kishikawakatsumi/KeychainAccess` → select "Up to Next Major Version" from **4.0.0** → add **KeychainAccess** product to the Gymbros target

Files in Tasks 6–9 import `Supabase` and will not compile until this is done.

---

## Task 6: Remote Data Layer

**Files:**
- Create: `Gymbros/Data/Remote/SupabaseClient.swift`
- Create: `Gymbros/Data/Remote/AuthService.swift`

- [x] **Step 1: Create `Gymbros/Data/Remote/SupabaseClient.swift`**

```swift
import Foundation
import Supabase

@MainActor
final class SupabaseClientManager {
    static let shared = SupabaseClientManager()

    let client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: AppConstants.Supabase.url,
            supabaseKey: AppConstants.Supabase.anonKey
        )
    }
}
```

- [x] **Step 2: Create `Gymbros/Data/Remote/AuthService.swift`**

```swift
import Foundation
import Supabase

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private let client = SupabaseClientManager.shared.client

    var currentUser: User?
    var isAuthenticated: Bool { currentUser != nil }

    private init() {
        Task { await loadCurrentSession() }
    }

    func loadCurrentSession() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
        } catch {
            self.currentUser = nil
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        self.currentUser = session.user
    }

    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
    }
}
```

- [x] **Step 3: Build to confirm these files compile with the package**

```bash
xcodebuild build -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD" | tail -5
```

Expected: `BUILD SUCCEEDED`

- [x] **Step 4: Commit**

```bash
git add Gymbros/Data/Remote/
git commit -m "feat: add SupabaseClient singleton and AuthService with Apple Sign-In"
```

---

## Task 7: Repositories

Historical note: this task was completed before the Sprint 1 error standard was finalized. Task 9.5 supersedes the `RepositoryError` parts and deletes `RepositoryError.swift`.

**Files:**
- Create: `Gymbros/Data/Repository/RepositoryError.swift`
- Create: `Gymbros/Data/Repository/ProfileRepository.swift`
- Create: `Gymbros/Data/Repository/ExerciseRepository.swift`
- Create: `Gymbros/Data/Repository/ProgramRepository.swift`
- Create: `Gymbros/Data/Repository/WorkoutRepository.swift`

- [x] **Step 1: Create `Gymbros/Data/Repository/RepositoryError.swift`**

```swift
import Foundation

enum RepositoryError: LocalizedError {
    case notAuthenticated
    case notFound
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "User is not authenticated"
        case .notFound: "Resource not found"
        case .networkError(let error): "Network error: \(error.localizedDescription)"
        }
    }
}
```

- [x] **Step 2: Create `Gymbros/Data/Repository/ProfileRepository.swift`**

```swift
import Foundation
import Supabase

@MainActor
final class ProfileRepository {
    private let client = SupabaseClientManager.shared.client

    func fetchCurrentProfile() async throws -> Profile {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }
        let profile: Profile = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return profile
    }

    func updateProfile(_ profile: Profile) async throws {
        try await client
            .from("profiles")
            .update(profile)
            .eq("id", value: profile.id)
            .execute()
    }
}
```

- [x] **Step 3: Create `Gymbros/Data/Repository/ExerciseRepository.swift`**

```swift
import Foundation
import Supabase

@MainActor
final class ExerciseRepository {
    private let client = SupabaseClientManager.shared.client

    func fetchAll() async throws -> [Exercise] {
        let exercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .order("name_en")
            .execute()
            .value
        return exercises
    }

    func fetch(byMuscle muscle: MuscleGroup) async throws -> [Exercise] {
        let exercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .eq("primary_muscle", value: muscle.rawValue)
            .order("name_en")
            .execute()
            .value
        return exercises
    }

    func fetch(byPattern pattern: MovementPattern) async throws -> [Exercise] {
        let exercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .eq("movement_pattern", value: pattern.rawValue)
            .order("name_en")
            .execute()
            .value
        return exercises
    }
}
```

- [x] **Step 4: Create `Gymbros/Data/Repository/ProgramRepository.swift`**

```swift
import Foundation
import Supabase

@MainActor
final class ProgramRepository {
    private let client = SupabaseClientManager.shared.client

    func fetchAll() async throws -> [Program] {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }
        let programs: [Program] = try await client
            .from("programs")
            .select()
            .eq("user_id", value: userId)
            .order("updated_at", ascending: false)
            .execute()
            .value
        return programs
    }

    func fetchFull(id: UUID) async throws -> Program {
        var program: Program = try await client
            .from("programs")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value

        let days: [ProgramDay] = try await client
            .from("program_days")
            .select()
            .eq("program_id", value: id)
            .order("day_order")
            .execute()
            .value

        let dayIds = days.map { $0.id }
        let exercises: [ProgramExercise] = try await client
            .from("program_exercises")
            .select()
            .in("program_day_id", values: dayIds)
            .order("exercise_order")
            .execute()
            .value

        program.days = days.map { day in
            var d = day
            d.exercises = exercises.filter { $0.programDayId == day.id }
            return d
        }
        return program
    }

    func fetchActive() async throws -> Program? {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }
        let programs: [Program] = try await client
            .from("programs")
            .select()
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .limit(1)
            .execute()
            .value
        guard let program = programs.first else { return nil }
        return try await fetchFull(id: program.id)
    }

    func create(_ program: Program) async throws -> Program {
        let inserted: Program = try await client
            .from("programs")
            .insert(program)
            .select()
            .single()
            .execute()
            .value
        return inserted
    }

    func update(_ program: Program) async throws {
        try await client
            .from("programs")
            .update(program)
            .eq("id", value: program.id)
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client
            .from("programs")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func setActive(programId: UUID) async throws {
        try await client
            .from("programs")
            .update(["is_active": true])
            .eq("id", value: programId)
            .execute()
    }
}
```

- [x] **Step 5: Create `Gymbros/Data/Repository/WorkoutRepository.swift`**

```swift
import Foundation
import Supabase

@MainActor
final class WorkoutRepository {
    private let client = SupabaseClientManager.shared.client

    func createSession(_ session: WorkoutSession) async throws -> WorkoutSession {
        let inserted: WorkoutSession = try await client
            .from("workout_sessions")
            .insert(session)
            .select()
            .single()
            .execute()
            .value
        return inserted
    }

    func uploadSet(_ set: WorkoutSet) async throws {
        try await client
            .from("workout_sets")
            .insert(set)
            .execute()
    }

    func completeSession(_ sessionId: UUID, endedAt: Date) async throws {
        try await client
            .from("workout_sessions")
            .update(["ended_at": endedAt.ISO8601Format()])
            .eq("id", value: sessionId)
            .execute()
    }

    func fetchHistory(limit: Int = 50) async throws -> [WorkoutSession] {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw RepositoryError.notAuthenticated
        }
        let sessions: [WorkoutSession] = try await client
            .from("workout_sessions")
            .select()
            .eq("user_id", value: userId)
            .not("ended_at", operator: .is, value: AnyJSON.null)
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return sessions
    }
}
```

> **Note on `fetchHistory`:** The `.not("ended_at", operator: .is, value: AnyJSON.null)` filter requires `AnyJSON` from the Supabase SDK. If it doesn't compile, try `.not("ended_at", operator: .is, value: "null")` as a fallback.

- [x] **Step 6: Build to confirm all repositories compile**

```bash
xcodebuild build -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD" | tail -5
```

Expected: `BUILD SUCCEEDED`

- [x] **Step 7: Commit**

```bash
git add Gymbros/Data/Repository/
git commit -m "feat: add four Supabase repositories and RepositoryError"
```

---

## ⚠️ USER GATE: Add Capabilities in Xcode

**Before proceeding to Task 8, the user must add capabilities:**

1. Open `Gymbros.xcodeproj` in Xcode
2. Select the **Gymbros** target → **Signing & Capabilities** tab
3. Click **+ Capability** → add **Sign in with Apple**
4. Click **+ Capability** → add **HealthKit**
   - For HealthKit, check "Clinical Health Records" if prompted; for Sprint 1 we just need the capability registered

---

## Task 8: Presentation — Sign-In Screen

**Files:**
- Create: `Gymbros/Presentation/Auth/SignInView.swift`
- Create: `Gymbros/App/RootView.swift`

- [x] **Step 1: Create `Gymbros/Presentation/Auth/SignInView.swift`**

```swift
import SwiftUI
import AuthenticationServices
import CryptoKit

struct SignInView: View {
    @State private var auth = AuthService.shared
    @State private var currentNonce: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.gymAccent)

                Text("GymBros")
                    .font(.largeTitle.bold())

                Text("มาแค่นี้พอ เราจะดูแลส่วนที่เหลือ")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = randomNonceString()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName]
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    Task { await handleAppleSignIn(result) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 56)
                .cornerRadius(12)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(24)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let idTokenData = credential.identityToken,
                  let idToken = String(data: idTokenData, encoding: .utf8),
                  let nonce = currentNonce else {
                errorMessage = "Sign in failed: missing token"
                return
            }
            do {
                try await auth.signInWithApple(idToken: idToken, nonce: nonce)
            } catch {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("SecRandomCopyBytes failed: \(errorCode)")
                }
                return random
            }
            randoms.forEach { random in
                if remainingLength == 0 { return }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }
}
```

- [x] **Step 2: Create `Gymbros/App/RootView.swift`**

```swift
import SwiftUI

struct RootView: View {
    @State private var auth = AuthService.shared

    var body: some View {
        if auth.isAuthenticated {
            Text("Logged in — Sprint 4 adds TodayView here")
                .foregroundStyle(.secondary)
        } else {
            SignInView()
        }
    }
}
```

- [x] **Step 3: Build to confirm no errors**

```bash
xcodebuild build -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "error:|BUILD" | tail -5
```

Expected: `BUILD SUCCEEDED`

- [x] **Step 4: Commit**

```bash
git add Gymbros/Presentation/ Gymbros/App/RootView.swift
git commit -m "feat: add SignInView with Apple Sign-In and RootView auth gate"
```

---

## Task 9: Wire App Entry Point

**Files:**
- Modify: `Gymbros/GymbrosApp.swift`
- Delete: `Gymbros/ContentView.swift`

- [x] **Step 1: Update `Gymbros/GymbrosApp.swift`**

```swift
import SwiftUI

@main
struct GymbrosApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [x] **Step 2: Delete `Gymbros/ContentView.swift`**

```bash
rm /Users/nattapongsawa/Desktop/Gymbros/Gymbros/ContentView.swift
```

(Xcode's file system sync automatically removes it from the project on next build.)

- [x] **Step 3: Final build + run full test suite**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' 2>&1 | grep -E "Test Suite|passed|failed|BUILD" | tail -20
```

Expected: `BUILD SUCCEEDED`, all existing enum and Codable tests pass. Task 9.5 adds error-handling tests before final Sprint 1 verification.

- [x] **Step 4: Commit**

```bash
git add Gymbros/GymbrosApp.swift
git commit -m "feat: wire RootView as app entry point, remove ContentView placeholder"
```

---

## Task 9.5: Standard Result Error Handling + Unit Tests

**Why this task exists:** Task 7 and Task 8 were implemented before the project error-handling standard was finalized. Sprint 1 must now add the shared typed error pipeline before manual Supabase verification so Sprint 2 does not build on raw `localizedDescription` strings or `RepositoryError`.

**Files:**
- Create: `Gymbros/Core/ErrorHandling/AppError.swift`
- Create: `Gymbros/Core/ErrorHandling/ErrorMapper.swift`
- Create: `Gymbros/Core/ErrorHandling/ViewState.swift`
- Create: `GymbrosTests/ErrorHandlingTests.swift`
- Delete: `Gymbros/Data/Repository/RepositoryError.swift`
- Modify: repositories to use `AppError` directly
- Modify: `Gymbros/Presentation/Auth/SignInViewModel.swift`
- Modify: `Gymbros/Resources/Localizable.xcstrings`

**Rules:**
- Use Swift standard `Result<Value, AppError>` from `https://developer.apple.com/documentation/swift/result`.
- Do not create `AppResult`, custom result wrappers, or feature-specific result types.
- Do not show raw `Error.localizedDescription`, Supabase messages, SQL hints, status codes, or debug IDs in user UI.
- Keep raw details only in debug logs with no tokens, API keys, auth headers, Apple identity tokens, or health data.

- [ ] **Step 1: Create shared error types**

Create `AppError`, `AuthFailure`, `NetworkFailure`, `APIErrorCode`, `ValidationFailure`, and `ViewState<Value>` under `Gymbros/Core/ErrorHandling/`.

Expected shape:

```swift
enum AppError: Error, Equatable {
    case auth(AuthFailure)
    case api(APIErrorCode, statusCode: Int?)
    case network(NetworkFailure)
    case decoding
    case validation(ValidationFailure)
    case permissionDenied
    case notFound
    case conflict
    case rateLimited
    case cancelled
    case unknown(debugID: String)
}

enum ViewState<Value> {
    case idle
    case loading
    case success(Value)
    case empty
    case error(AppError)
}
```

- [ ] **Step 2: Create `ErrorMapper`**

`ErrorMapper` is the only place that converts unknown SDK/runtime errors into `AppError`.

Minimum mappings:

```
CancellationError                         -> .cancelled
URLError.notConnectedToInternet           -> .network(.offline)
URLError.timedOut                         -> .network(.timeout)
DecodingError / EncodingError             -> .decoding
401 / missing session                     -> .auth(.sessionMissing)
403 / Postgres 42501 / RLS denied         -> .permissionDenied
404 / PGRST not found                     -> .notFound
409 / Postgres 23505 / 23503              -> .conflict
429                                       -> .rateLimited
500 / 503 / 504                           -> .network(.temporary) or .api(..., statusCode:)
Unknown                                   -> .unknown(debugID:)
```

Expose pure helpers that are easy to unit-test, for example:

```swift
static func map(_ error: Error, context: ErrorContext) -> AppError
static func mapHTTPStatus(_ statusCode: Int, code: String?) -> AppError
static func mapSupabaseCode(_ code: String, statusCode: Int?) -> AppError
```

- [ ] **Step 3: Migrate repositories to typed error boundary**

Replace new repository failure paths with Swift standard `Result<Value, AppError>` or `async throws` where only `AppError` is thrown.

Acceptable signatures:

```swift
func fetchAll() async -> Result<[Exercise], AppError>
func fetchCurrentProfile() async throws -> Profile // may throw only AppError
```

Delete `RepositoryError.swift`. Remove `RepositoryError.networkError(Error)`, `RepositoryError.notAuthenticated`, and any `LocalizedError.errorDescription` that includes `error.localizedDescription`.

- [ ] **Step 4: Migrate `SignInViewModel` state**

Replace `String? errorMessage` with typed state:

```swift
var state: ViewState<Void> = .idle
var error: AppError?
```

Apple Sign-In user cancellation maps to `.cancelled` and should not show an error. Missing identity token maps to `.auth(.appleCredentialMissing)`. Failed Supabase auth maps through `ErrorMapper`.

- [ ] **Step 5: Add localized error copy**

Add English and Thai keys to `Gymbros/Resources/Localizable.xcstrings` for all generic app errors used in Sprint 1:

```
error.auth.sessionMissing.title
error.auth.sessionMissing.message
error.auth.appleCredentialMissing.title
error.auth.appleCredentialMissing.message
error.network.offline.title
error.network.offline.message
error.network.timeout.title
error.network.timeout.message
error.permissionDenied.title
error.permissionDenied.message
error.notFound.title
error.notFound.message
error.conflict.title
error.conflict.message
error.rateLimited.title
error.rateLimited.message
error.decoding.title
error.decoding.message
error.unknown.title
error.unknown.message
error.action.retry
```

- [ ] **Step 6: Add unit tests — `GymbrosTests/ErrorHandlingTests.swift`**

Use Swift Testing (`import Testing`, `#expect(...)`), not XCTest.

Required tests:

```swift
@Test("Cancellation maps to cancelled")
@Test("Offline URL error maps to network offline")
@Test("Timed out URL error maps to timeout")
@Test("Decoding error maps to decoding")
@Test("HTTP status maps to app error")
@Test("Supabase Postgres codes map to app error")
@Test("AppError exposes localization keys without raw messages")
```

Coverage expectations:
- `401` -> `.auth(.sessionMissing)`
- `403` and `42501` -> `.permissionDenied`
- `404` -> `.notFound`
- `409`, `23505`, and `23503` -> `.conflict`
- `429` -> `.rateLimited`
- cancellation does not become a visible error

- [ ] **Step 7: Run focused error tests**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e' \
  -only-testing:GymbrosTests/ErrorHandlingTests
```

Expected: all `ErrorHandlingTests` pass.

- [ ] **Step 8: Run full unit suite**

```bash
xcodebuild test -project Gymbros.xcodeproj -scheme Gymbros \
  -destination 'platform=iOS Simulator,name=iPhone 17e'
```

Expected: all enum, Codable, localization, and error-handling tests pass.

- [ ] **Step 9: Commit**

```bash
git add Gymbros/Core/ErrorHandling Gymbros/Data/Repository Gymbros/Presentation/Auth Gymbros/Resources/Localizable.xcstrings GymbrosTests/ErrorHandlingTests.swift
git commit -m "feat: add standard Result error handling"
```

---

## ⚠️ USER GATE: Supabase Setup

Before manual simulator testing (Task 10):

1. Go to [supabase.com](https://supabase.com) → create a new project (or use existing)
2. **SQL Editor → New Query** → paste and run `supabase/schema.sql`
3. **SQL Editor → New Query** → paste and run `supabase/seed_exercises.sql` → verify output shows `exercise_count = 95`
4. **Project Settings → API** → copy **Project URL** and **anon public** key
5. In `Gymbros/Core/Constants.swift`, replace:
   - `"https://YOUR_PROJECT.supabase.co"` → your actual project URL
   - `"YOUR_ANON_KEY"` → your actual anon key
6. Rebuild the app

---

## Task 10: Simulator Verification

Manual verification — no automation possible for Apple Sign-In on simulator.

- [ ] **Step 1: Run on simulator in Xcode**

In Xcode: Product → Run (⌘R) on iPhone 17e simulator.
Expected: App launches showing the GymBros sign-in screen with Apple Sign-In button and lime dumbbell icon.

- [ ] **Step 2: Test RLS in Supabase SQL Editor**

Run this as `anon` role (no auth) — should return 0 rows:
```sql
select * from public.profiles;
```

- [ ] **Step 3: Verify exercise count**

```sql
select count(*) from public.exercises;
-- Expected: 95
```

- [ ] **Step 4: Test sign-in on physical device** (Apple Sign-In doesn't work on simulator without a workaround)

On a physical iPhone: sign in with Apple → app should show "Logged in" placeholder → force quit + reopen → still shows placeholder (session persisted).

- [ ] **Step 5: Verify Supabase trigger security**

Confirm `public.handle_new_user()` is not directly executable by `anon` or `authenticated`. If Supabase CLI/MCP advisors are available, run database/security advisors and address any high-severity findings before final commit.

- [ ] **Step 6: Final commit**

```bash
git add Gymbros/Core/Constants.swift
git commit -m "feat: connect Supabase credentials — Sprint 1 complete"
```

---

## Verification Checklist

```
☐ xcodebuild test passes — enum, Codable, localization, and error-handling tests all pass
☐ App launches on simulator showing SignInView
☐ AccentColor shows lime (#C8FF00) on simulator
☐ Supabase has 95 exercises
☐ Supabase profiles table empty (no logins yet)
☐ RLS blocks anon queries to profiles
☐ On device: Apple Sign-In creates profile row in Supabase
☐ On device: Force quit + reopen stays authenticated
☐ On device: No way to trigger sign-out yet (Sprint 4 adds Settings)
```
