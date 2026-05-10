# Sprint 1 — Foundation + Data

> Detailed implementation spec for Claude Code.
> Reference: /GYMTRACK.md Section 7 — Phase 1, Sprint 1

---

## Overview

**Goal:** Set up the foundation so Sprint 2 (Custom Program Builder) can be built on top.

**Deliverables:**
1. Xcode project with full folder structure
2. Supabase project with complete schema
3. All Codable model structs
4. SupabaseClient with Apple Sign-In auth
5. Repository interfaces and Supabase implementations
6. Seeded exercise library (~100 exercises)
7. Login screen
8. Standard Swift `Result<Value, AppError>` error-handling foundation with unit tests

**Effort estimate:** Medium (1–2 focused coding sessions)

**Dependencies:** None — this is the first sprint.

---

## 1. Requirements

### Must Have

```
✓ Xcode project compiles and runs on simulator
✓ Tap "Sign in with Apple" → authenticates → creates profile in Supabase
✓ Apple email scope requested; `profiles.email` stores the auth email when Apple provides one
✓ Auth state persists across app launches and is revalidated with Supabase Auth on launch/foreground
✓ Supabase has all tables, indexes, and RLS policies
✓ ~100 system exercises seeded with canonical names
✓ Sign out works correctly
✓ Data errors normalize into `AppError` and repositories/ViewModels never expose raw SDK error text
✓ Error-handling unit tests cover auth, network, cancellation, decoding, HTTP/status, and Supabase code mapping
```

### Out of Scope (Sprint 2+)

```
✗ Program creation UI (Sprint 2)
✗ Workout logger (Sprint 3)
✗ Today screen (Sprint 4)
✗ Onboarding quiz (Sprint 6)
```

---

## 2. Xcode Project Setup

### Project Configuration

```
Product Name:     GymBros
Organization:     com.[your-org]
Bundle ID:        com.[your-org].gymbros
Interface:        SwiftUI
Language:         Swift
Storage:          None (we'll add Supabase)
Minimum iOS:      iOS 17.0
Includes Tests:   Yes (GymBrosTests)
```

### Capabilities to Enable

```
Signing & Capabilities tab:
  ✓ Sign in with Apple
  ✓ HealthKit (configure for Sprint 3, but enable now)
```

### Swift Package Dependencies

Add via File → Add Packages:

```
1. Supabase Swift SDK
   URL: https://github.com/supabase/supabase-swift
   Version: latest stable v2.x

2. KeychainAccess (for secure token storage)
   URL: https://github.com/kishikawakatsumi/KeychainAccess
   Version: latest stable
```

### Folder Structure

Create these groups (folders) inside the GymTrack target:

```
GymTrack/
├── App/
├── Core/
│   ├── Extensions/
│   └── Constants.swift
├── Model/
│   └── Enums/
├── Data/
│   ├── Remote/
│   ├── Repository/
│   └── Services/
├── Presentation/
│   └── Auth/
└── Resources/
```

---

## 3. Supabase Schema

### Setup Steps

1. Create new Supabase project at supabase.com
2. Note: Project URL and anon key (will go into SupabaseClient)
3. Open SQL Editor → run the schema below
4. Run seed script (Section 9) after schema

### schema.sql

```sql
-- ============================================================
-- ENUMS (using text for flexibility)
-- ============================================================

-- ============================================================
-- TABLES
-- ============================================================

-- User profile (extends Supabase auth.users)
create table public.profiles (
    id uuid references auth.users on delete cascade primary key,
    email text,                    -- copied from auth.users.email when Apple provides it
    name text,
    experience_level text,        -- 'beginner' | 'intermediate' | 'advanced'
    goal text,                    -- 'strength' | 'muscle' | 'fat_loss' | 'general'
    days_per_week int,            -- 2..7
    weight_unit text default 'kg' not null,  -- 'kg' | 'lb'
    locale text default 'th' not null,
    created_at timestamptz default now() not null,
    updated_at timestamptz default now() not null
);

-- Master exercise library (shared, read-only for users)
create table public.exercises (
    id uuid primary key default gen_random_uuid(),
    owner_user_id uuid references public.profiles(id) on delete cascade,
    slug text,
    name text not null,
    movement_pattern text not null,    -- 'push' | 'pull' | 'squat' | 'hinge' | 'lunge' | 'carry' | 'core'
    primary_muscle text not null,      -- 'chest' | 'back' | 'quads' | 'hamstrings' | etc.
    secondary_muscles text[] default '{}' not null,
    equipment text not null,            -- 'barbell' | 'dumbbell' | 'machine' | 'cable' | 'bodyweight' | 'kettlebell'
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
    name text not null,                -- 'Upper 1', 'Lower 1', 'Push', etc.
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
    target_rest_seconds int not null default 90,
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
    program_exercise_id uuid references public.program_exercises(id) on delete set null,
    set_number int not null,
    weight numeric(6,2) not null,
    reps int not null,
    rpe numeric(3,1),                  -- 1.0 to 10.0, nullable
    target_rest_seconds int,
    actual_rest_seconds int,
    rest_started_at timestamptz,
    rest_ended_at timestamptz,
    completed_at timestamptz default now() not null,
    notes text
);

-- ============================================================
-- INDEXES
-- ============================================================

create index idx_programs_user on public.programs(user_id);
create index idx_programs_active on public.programs(user_id, is_active) where is_active = true;
create index idx_program_days_program on public.program_days(program_id, day_order);
create index idx_program_exercises_day on public.program_exercises(program_day_id, exercise_order);
create index idx_sessions_user on public.workout_sessions(user_id);
create index idx_sessions_started on public.workout_sessions(started_at desc);
create index idx_sets_session on public.workout_sets(session_id);
create index idx_sets_exercise_user on public.workout_sets(exercise_id, completed_at desc);
create index idx_sets_program_exercise on public.workout_sets(program_exercise_id);
create index idx_exercises_owner on public.exercises(owner_user_id);
create unique index idx_exercises_system_slug on public.exercises(slug)
    where owner_user_id is null and slug is not null;
create index idx_exercises_pattern on public.exercises(movement_pattern);
create index idx_exercises_muscle on public.exercises(primary_muscle);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.profiles enable row level security;
alter table public.exercises enable row level security;
alter table public.programs enable row level security;
alter table public.program_days enable row level security;
alter table public.program_exercises enable row level security;
alter table public.workout_sessions enable row level security;
alter table public.workout_sets enable row level security;

-- Profile policies
create policy "Users can view own profile" on public.profiles
    for select using (auth.uid() = id);

create policy "Users can insert own profile" on public.profiles
    for insert with check (auth.uid() = id);

create policy "Users can update own profile" on public.profiles
    for update using (auth.uid() = id);

-- Exercise policies (everyone authenticated can read)
create policy "Authenticated users can view available exercises" on public.exercises
    for select to authenticated
    using (owner_user_id is null or (select auth.uid()) = owner_user_id);

create policy "Users can create own exercises" on public.exercises
    for insert to authenticated
    with check ((select auth.uid()) = owner_user_id);

create policy "Users can update own exercises" on public.exercises
    for update to authenticated
    using ((select auth.uid()) = owner_user_id)
    with check ((select auth.uid()) = owner_user_id);

create policy "Users can delete own exercises" on public.exercises
    for delete to authenticated
    using ((select auth.uid()) = owner_user_id);

-- Program policies
create policy "Users can view own programs" on public.programs
    for select using (auth.uid() = user_id);

create policy "Users can create own programs" on public.programs
    for insert with check (auth.uid() = user_id);

create policy "Users can update own programs" on public.programs
    for update using (auth.uid() = user_id);

create policy "Users can delete own programs" on public.programs
    for delete using (auth.uid() = user_id);

-- Program days policies (cascading via program ownership)
create policy "Users can manage own program days" on public.program_days
    for all using (
        exists (
            select 1 from public.programs
            where programs.id = program_days.program_id
            and programs.user_id = auth.uid()
        )
    );

-- Program exercises policies (cascading via program ownership)
create policy "Users can manage own program exercises" on public.program_exercises
    for all using (
        exists (
            select 1 from public.program_days
            join public.programs on programs.id = program_days.program_id
            where program_days.id = program_exercises.program_day_id
            and programs.user_id = auth.uid()
        )
    );

-- Workout session policies
create policy "Users can view own sessions" on public.workout_sessions
    for select using (auth.uid() = user_id);

create policy "Users can create own sessions" on public.workout_sessions
    for insert with check (auth.uid() = user_id);

create policy "Users can update own sessions" on public.workout_sessions
    for update using (auth.uid() = user_id);

create policy "Users can delete own sessions" on public.workout_sessions
    for delete using (auth.uid() = user_id);

-- Workout set policies (cascading via session ownership)
create policy "Users can manage own sets" on public.workout_sets
    for all using (
        exists (
            select 1 from public.workout_sessions
            where workout_sessions.id = workout_sets.session_id
            and workout_sessions.user_id = auth.uid()
        )
    );

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Auto-create profile on user signup
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, email, name)
    values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', null));
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure private.handle_new_user();

create or replace function private.sync_profile_email_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    update public.profiles
    set email = new.email
    where id = new.id
      and email is distinct from new.email;
    return new;
end;
$$;

create trigger on_auth_user_email_updated
    after update of email on auth.users
    for each row
    when (old.email is distinct from new.email)
    execute procedure private.sync_profile_email_from_auth();

-- Auto-update updated_at on profiles + programs
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
set search_path = public
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

-- Ensure only one active program per user
create or replace function public.ensure_single_active_program()
returns trigger
language plpgsql
set search_path = public
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

---

## 4. Codable Model Structs

All in `Model/`. Use `snake_case` keys via `CodingKeys` to match Supabase columns.

### Model/Profile.swift

```swift
import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    var email: String?
    var name: String?
    var experienceLevel: ExperienceLevel?
    var goal: Goal?
    var daysPerWeek: Int?
    var weightUnit: WeightUnit
    var locale: String
    let createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, email, name, goal, locale
        case experienceLevel = "experience_level"
        case daysPerWeek = "days_per_week"
        case weightUnit = "weight_unit"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

### Model/Exercise.swift

```swift
import Foundation

struct Exercise: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerUserId: UUID?
    let slug: String?
    let name: String
    let movementPattern: MovementPattern
    let primaryMuscle: MuscleGroup
    let secondaryMuscles: [MuscleGroup]
    let equipment: Equipment
    let isCompound: Bool
    let createdAt: Date

    var displayName: String { name }

    enum CodingKeys: String, CodingKey {
        case id, slug, name, equipment
        case ownerUserId = "owner_user_id"
        case movementPattern = "movement_pattern"
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
        case isCompound = "is_compound"
        case createdAt = "created_at"
    }
}
```

### Model/Program.swift

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
    
    /// Days populated client-side (not from DB row directly)
    var days: [ProgramDay] = []
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case userId = "user_id"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // `days` is NOT in CodingKeys — populated separately
    }
}
```

### Model/ProgramDay.swift

```swift
import Foundation

struct ProgramDay: Codable, Identifiable, Equatable {
    let id: UUID
    let programId: UUID
    var name: String
    var dayOrder: Int
    let createdAt: Date
    
    /// Exercises populated client-side
    var exercises: [ProgramExercise] = []
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case programId = "program_id"
        case dayOrder = "day_order"
        case createdAt = "created_at"
    }
}
```

### Model/ProgramExercise.swift

```swift
import Foundation

struct ProgramExercise: Codable, Identifiable, Equatable {
    let id: UUID
    let programDayId: UUID
    let exerciseId: UUID
    var targetSets: Int
    var targetRepsMin: Int
    var targetRepsMax: Int
    var targetRestSeconds: Int
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
        case targetRestSeconds = "target_rest_seconds"
        case exerciseOrder = "exercise_order"
        case createdAt = "created_at"
    }
}
```

### Model/WorkoutSession.swift

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
    
    /// Sets populated client-side
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

### Model/WorkoutSet.swift

```swift
import Foundation

struct WorkoutSet: Codable, Identifiable, Equatable {
    let id: UUID
    let sessionId: UUID
    let exerciseId: UUID
    let programExerciseId: UUID?
    var setNumber: Int
    var weight: Double
    var reps: Int
    var rpe: Double?
    var targetRestSeconds: Int?
    var actualRestSeconds: Int?
    var restStartedAt: Date?
    var restEndedAt: Date?
    var completedAt: Date
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, weight, reps, rpe, notes
        case sessionId = "session_id"
        case exerciseId = "exercise_id"
        case programExerciseId = "program_exercise_id"
        case setNumber = "set_number"
        case targetRestSeconds = "target_rest_seconds"
        case actualRestSeconds = "actual_rest_seconds"
        case restStartedAt = "rest_started_at"
        case restEndedAt = "rest_ended_at"
        case completedAt = "completed_at"
    }
}
```

### Model/Enums/

Each enum in its own file. All conform to `String, Codable, CaseIterable`.

```swift
// MovementPattern.swift
enum MovementPattern: String, Codable, CaseIterable {
    case push, pull, squat, hinge, lunge, carry, core
}

// MuscleGroup.swift
enum MuscleGroup: String, Codable, CaseIterable {
    case chest, back, shoulders, biceps, triceps
    case quads, hamstrings, glutes, calves, core
    case forearms, traps
}

// Equipment.swift
enum Equipment: String, Codable, CaseIterable {
    case barbell, dumbbell, machine, cable
    case bodyweight, kettlebell, band
}

// ExperienceLevel.swift
enum ExperienceLevel: String, Codable, CaseIterable {
    case beginner, intermediate, advanced
}

// Goal.swift
enum Goal: String, Codable, CaseIterable {
    case strength, muscle, fatLoss = "fat_loss", general
}

// WeightUnit.swift
enum WeightUnit: String, Codable, CaseIterable {
    case kg, lb
}

// TrainingPhase.swift (for Phase 5, but define enum now)
enum TrainingPhase: String, Codable, CaseIterable {
    case bulk, cut, maintain
}
```

---

## 5. Core Constants

### Core/AppTheme.swift

```swift
import SwiftUI

extension Color {
    /// Primary interactive — electric lime #C8FF00
    /// Use for: buttons, toggles, progress rings, checkmarks, completion
    static let gymAccent = Color("AccentColor")

    /// Special states — purple #9B7FE8
    /// Use for: comeback cards, PR badges, deload indicators, milestones
    static let gymPurple = Color("GymPurple")

    /// Convenience aliases for SwiftUI semantic surfaces
    static let gymSurface = Color(.secondarySystemBackground)
    static let gymBackground = Color(.systemBackground)
}

extension Font {
    /// Chunky rounded numbers for weights and reps
    static func gymNumber(size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }
}
```

In Assets.xcassets, create two color sets:

```
AccentColor.colorset
  Any Appearance: #C8FF00  (electric lime)
  Dark:           #C8FF00

GymPurple.colorset
  Any Appearance: #9B7FE8  (purple/violet)
  Dark:           #9B7FE8
```

---

### Core/Constants.swift

```swift
import Foundation

enum AppConstants {
    enum Supabase {
        // ⚠️ Replace with your actual values from Supabase dashboard
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

---

## 6. SupabaseClient

### Data/Remote/SupabaseClient.swift

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

---

## 7. Auth Flow

### Data/Remote/AuthService.swift

```swift
import Foundation
import Supabase
import AuthenticationServices

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
    
    /// Load existing session on app launch
    func loadCurrentSession() async {
        do {
            self.currentUser = try await client.auth.user()
        } catch {
            try? await client.auth.signOut(scope: .local)
            self.currentUser = nil
        }
    }
    
    /// Sign in with Apple — request email scope and pass ASAuthorizationAppleIDCredential.email when Apple returns it.
    func signInWithApple(idToken: String, nonce: String, email: String?) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        self.currentUser = session.user
        // Best-effort sync for existing users; the signup trigger copies new.email for new users.
        await syncProfileEmail(user: session.user, appleEmail: email)
    }
    
    /// Sign out
    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
    }

    private func syncProfileEmail(user: User, appleEmail: String?) async {
        let email = user.email ?? appleEmail
        guard let email, email.isEmpty == false else { return }

        do {
            try await client
                .from("profiles")
                .update(["email": email])
                .eq("id", value: user.id)
                .execute()
        } catch {
            // Debug-log mapped AppError only; do not show raw SDK details to users.
        }
    }
}
```

### Presentation/Auth/SignInView.swift

Legacy note: this original Sprint 1 sketch is superseded by the Task 8 implementation with `SignInViewModel` and by Section 8.5. New work must not use `String? errorMessage` or show `error.localizedDescription` to users.

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
            
            SignInWithAppleButton(.signIn) { request in
                let nonce = randomNonceString()
                currentNonce = nonce
                request.requestedScopes = [.email]
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
                try await auth.signInWithApple(idToken: idToken, nonce: nonce, email: credential.email)
            } catch {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
            
        case .failure(let error):
            errorMessage = "Sign in failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Nonce helpers (Apple Sign-In requirement)
    
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
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

---

## 8. Repositories (Interfaces + Supabase Implementations)

### Data/Repository/ProfileRepository.swift

```swift
import Foundation
import Supabase

@MainActor
final class ProfileRepository {
    private let client = SupabaseClientManager.shared.client
    
    func fetchCurrentProfile() async throws -> Profile {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
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

### Data/Repository/ExerciseRepository.swift

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
            .order("name")
            .execute()
            .value
        return exercises
    }
    
    func fetch(byMuscle muscle: MuscleGroup) async throws -> [Exercise] {
        let exercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .eq("primary_muscle", value: muscle.rawValue)
            .order("name")
            .execute()
            .value
        return exercises
    }
    
    func fetch(byPattern pattern: MovementPattern) async throws -> [Exercise] {
        let exercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .eq("movement_pattern", value: pattern.rawValue)
            .order("name")
            .execute()
            .value
        return exercises
    }
}
```

### Data/Repository/ProgramRepository.swift

```swift
import Foundation
import Supabase

@MainActor
final class ProgramRepository {
    private let client = SupabaseClientManager.shared.client
    
    /// Fetch all user's programs (without days/exercises)
    func fetchAll() async throws -> [Program] {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
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
    
    /// Fetch a single program with all days and exercises populated
    func fetchFull(id: UUID) async throws -> Program {
        // Fetch program
        var program: Program = try await client
            .from("programs")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        
        // Fetch days
        let days: [ProgramDay] = try await client
            .from("program_days")
            .select()
            .eq("program_id", value: id)
            .order("day_order")
            .execute()
            .value
        
        // Fetch exercises for all days
        let dayIds = days.map { $0.id }
        let exercises: [ProgramExercise] = try await client
            .from("program_exercises")
            .select()
            .in("program_day_id", values: dayIds)
            .order("exercise_order")
            .execute()
            .value
        
        // Stitch together
        program.days = days.map { day in
            var d = day
            d.exercises = exercises.filter { $0.programDayId == day.id }
            return d
        }
        
        return program
    }
    
    func fetchActive() async throws -> Program? {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
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
        // Trigger handles deactivating others
    }
}
```

### Data/Repository/WorkoutRepository.swift

```swift
import Foundation
import Supabase

@MainActor
final class WorkoutRepository {
    private let client = SupabaseClientManager.shared.client
    
    /// Sprint 1 includes only the basic methods for Sprint 3 to extend
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
            .update(["ended_at": endedAt])
            .eq("id", value: sessionId)
            .execute()
    }
    
    func fetchHistory(limit: Int = 50) async throws -> [WorkoutSession] {
        guard let userId = AuthService.shared.currentUser?.id else {
            throw AppError.auth(.sessionMissing)
        }
        
        let sessions: [WorkoutSession] = try await client
            .from("workout_sessions")
            .select()
            .eq("user_id", value: userId)
            .not("ended_at", operator: .is, value: "null")
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return sessions
    }
}
```

Repositories must use `AppError` directly. Do not create `RepositoryError`.

---

## 8.5 Error Handling Foundation

Use Swift's standard [`Result<Success, Failure>`](https://developer.apple.com/documentation/swift/result). Do not create `AppResult`, custom result wrappers, or feature-specific result types.

### Files

```
Gymbros/Core/ErrorHandling/AppError.swift
Gymbros/Core/ErrorHandling/ErrorMapper.swift
Gymbros/Core/ErrorHandling/ViewState.swift
GymbrosTests/ErrorHandlingTests.swift
```

### Required Flow

```
Supabase / Apple / URLSession / Keychain throws
  -> ErrorMapper.map(error, context:)
  -> Result<Value, AppError>
  -> Repository
  -> ViewModel ViewState<Value>
  -> SwiftUI localized error UI
```

### Core/ErrorHandling/AppError.swift

```swift
import Foundation

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

enum AuthFailure: Equatable {
    case sessionMissing
    case tokenExpired
    case appleCredentialMissing
    case appleSignInFailed
}

enum NetworkFailure: Equatable {
    case offline
    case timeout
    case temporary
}

enum APIErrorCode: Equatable {
    case postgrest(String)
    case postgres(String)
    case storage(String)
    case functions(String)
    case unknown
}

enum ValidationFailure: Equatable {
    case missingRequiredField(String)
    case invalidValue(String)
}
```

### Core/ErrorHandling/ViewState.swift

```swift
enum ViewState<Value> {
    case idle
    case loading
    case success(Value)
    case empty
    case error(AppError)
}
```

### Core/ErrorHandling/ErrorMapper.swift

`ErrorMapper` is the only place that converts unknown errors into `AppError`.

Mapping requirements:

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

Handle these Supabase families explicitly when the SDK exposes their typed errors or response metadata: Auth API errors, PostgREST/Data API errors, Storage errors, Edge Function errors, Realtime errors.

`AppError` should expose localized title/message/recovery keys as computed properties, not literal user-facing text. Add all keys to `Localizable.xcstrings` in English and Thai.

### Repository Requirement

New or migrated repositories must use one of these signatures:

```swift
func fetchAll() async -> Result<[Exercise], AppError>
func fetchCurrentProfile() async throws -> Profile // may throw only AppError
```

Do not return raw `Error`, `RepositoryError`, `LocalizedError.errorDescription`, Supabase message strings, SQL hints, or `error.localizedDescription` to ViewModels.

### ViewModel Requirement

ViewModels must expose request state with `ViewState<Value>` or a feature-specific enum wrapping `AppError`, not `String? errorMessage`.

```swift
@Observable
@MainActor
final class ExerciseListViewModel {
    var state: ViewState<[Exercise]> = .idle

    func load() async {
        state = .loading
        switch await repository.fetchAll() {
        case .success(let exercises):
            state = exercises.isEmpty ? .empty : .success(exercises)
        case .failure(let error):
            state = error == .cancelled ? .idle : .error(error)
        }
    }
}
```

---

## 9. Seed Exercises

Run this AFTER schema.sql in Supabase SQL Editor.

### seed_exercises.sql

```sql
-- ~100 exercises covering common movement patterns
-- Add more as needed in Sprint 2

insert into public.exercises (name, slug, movement_pattern, primary_muscle, secondary_muscles, equipment, is_compound) values
('Barbell Back Squat', 'barbell_back_squat', 'squat', 'quads', '{glutes,hamstrings,core}', 'barbell', true),
('Barbell Bench Press', 'barbell_bench_press', 'push', 'chest', '{shoulders,triceps}', 'barbell', true);

-- Full seed list lives in supabase/seed_exercises.sql.

select count(*) as exercise_count from public.exercises;
-- Should be 98
```

---

## 10. Acceptance Criteria

```
☐ Build succeeds on iOS 17+ simulator
☐ Tap "Sign in with Apple" → Apple sheet → returns to app authenticated
☐ Profile row created in Supabase with auth user's id and email when Apple provides one
☐ Force quit + reopen app → still authenticated when the Supabase Auth user still exists
☐ Delete the Auth user in Supabase → foreground/reopen app → returns to login screen
☐ Tap Sign Out → returns to login screen
☐ Supabase shows ~98 exercises with canonical names
☐ ProgramRepository.fetchAll() returns empty array (no programs yet)
☐ ExerciseRepository.fetchAll() returns ~98 exercises
☐ All Codable models compile without warnings
☐ RLS works: querying another user's profile from SQL editor returns nothing
☐ `private.handle_new_user()` is not in the exposed `public` schema and cannot be directly executed by `anon` or `authenticated`
```

---

## 11. Edge Cases

```
Edge case                              Expected behavior
────────────────────────────────────────────────────────────
First-time user signs in               Profile auto-created via trigger
User cancels Apple Sign-In             Returns to login screen, no error toast
Network offline during sign-in         Show error: "Check your connection"
Session expires (30 days)              Auto sign out, return to login
User signs out then signs back in      Same Profile loaded, no duplicate
Apple ID has no email shared           OK — email remains nil; do not block sign-in
User deletes account in Apple settings Session invalidated on next launch
```

---

## 12. Unit Tests

Use Swift Testing (`import Testing`, `#expect(...)`, `@Suite`, `@Test`) for all new tests. The older XCTest-style examples below describe the assertions only; translate them to Swift Testing in implementation.

### GymTrackTests/CodableTests.swift

```swift
import XCTest
@testable import GymBros

final class CodableTests: XCTestCase {
    
    func testExerciseDecodesFromSupabaseJSON() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "owner_user_id": null,
            "slug": "bench_press",
            "name": "Bench Press",
            "movement_pattern": "push",
            "primary_muscle": "chest",
            "secondary_muscles": ["shoulders", "triceps"],
            "equipment": "barbell",
            "is_compound": true,
            "created_at": "2026-05-08T10:00:00Z"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exercise = try decoder.decode(Exercise.self, from: json)
        
        XCTAssertNil(exercise.ownerUserId)
        XCTAssertEqual(exercise.slug, "bench_press")
        XCTAssertEqual(exercise.name, "Bench Press")
        XCTAssertEqual(exercise.movementPattern, .push)
        XCTAssertEqual(exercise.primaryMuscle, .chest)
        XCTAssertEqual(exercise.secondaryMuscles, [.shoulders, .triceps])
        XCTAssertEqual(exercise.equipment, .barbell)
        XCTAssertTrue(exercise.isCompound)
    }
    
    func testProgramEncodesWithSnakeCase() throws {
        let program = Program(
            id: UUID(),
            userId: UUID(),
            name: "My Program",
            description: "Test",
            isActive: true,
            createdAt: .now,
            updatedAt: .now
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(program)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertNotNil(json["user_id"])
        XCTAssertNotNil(json["is_active"])
        XCTAssertNotNil(json["created_at"])
        XCTAssertNotNil(json["updated_at"])
        XCTAssertNil(json["userId"])  // camelCase should NOT exist
    }
}
```

### GymTrackTests/EnumsTests.swift

```swift
import XCTest
@testable import GymBros

final class EnumsTests: XCTestCase {
    
    func testGoalRawValueMatchesDB() {
        XCTAssertEqual(Goal.fatLoss.rawValue, "fat_loss")
        XCTAssertEqual(Goal.strength.rawValue, "strength")
    }
    
    func testAllEnumsRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for pattern in MovementPattern.allCases {
            let data = try encoder.encode(pattern)
            let decoded = try decoder.decode(MovementPattern.self, from: data)
            XCTAssertEqual(pattern, decoded)
        }
        
        for muscle in MuscleGroup.allCases {
            let data = try encoder.encode(muscle)
            let decoded = try decoder.decode(MuscleGroup.self, from: data)
            XCTAssertEqual(muscle, decoded)
        }
    }
}
```

### GymbrosTests/ErrorHandlingTests.swift

Use Swift Testing (`import Testing`), not XCTest.

```swift
import Foundation
import Testing
@testable import Gymbros

@Suite("Error handling")
struct ErrorHandlingTests {
    @Test("Cancellation maps to cancelled")
    func cancellationMapsToCancelled() {
        #expect(ErrorMapper.map(CancellationError(), context: .init(operation: "test")) == .cancelled)
    }

    @Test("Offline URL error maps to network offline")
    func offlineMapsToNetworkOffline() {
        let error = URLError(.notConnectedToInternet)
        #expect(ErrorMapper.map(error, context: .init(operation: "test")) == .network(.offline))
    }

    @Test("Timed out URL error maps to timeout")
    func timeoutMapsToNetworkTimeout() {
        let error = URLError(.timedOut)
        #expect(ErrorMapper.map(error, context: .init(operation: "test")) == .network(.timeout))
    }

    @Test("Decoding error maps to decoding")
    func decodingMapsToDecoding() {
        let error = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad payload"))
        #expect(ErrorMapper.map(error, context: .init(operation: "test")) == .decoding)
    }

    @Test("HTTP status maps to app error")
    func httpStatusMapsToAppError() {
        #expect(ErrorMapper.mapHTTPStatus(401, code: nil) == .auth(.sessionMissing))
        #expect(ErrorMapper.mapHTTPStatus(403, code: nil) == .permissionDenied)
        #expect(ErrorMapper.mapHTTPStatus(404, code: nil) == .notFound)
        #expect(ErrorMapper.mapHTTPStatus(409, code: nil) == .conflict)
        #expect(ErrorMapper.mapHTTPStatus(429, code: nil) == .rateLimited)
    }

    @Test("Supabase Postgres codes map to app error")
    func supabaseCodesMapToAppError() {
        #expect(ErrorMapper.mapSupabaseCode("42501", statusCode: 403) == .permissionDenied)
        #expect(ErrorMapper.mapSupabaseCode("23505", statusCode: 409) == .conflict)
        #expect(ErrorMapper.mapSupabaseCode("23503", statusCode: 409) == .conflict)
        #expect(ErrorMapper.mapSupabaseCode("PGRST301", statusCode: 401) == .auth(.sessionMissing))
    }

    @Test("AppError exposes localization keys without raw messages")
    func appErrorExposesLocalizationKeys() {
        let content = AppError.permissionDenied.localizedContent
        #expect(content.titleKey.hasPrefix("error."))
        #expect(content.messageKey.hasPrefix("error."))
    }
}
```

---

## 13. File Checklist

When this sprint is complete, these files should exist:

```
GymBros/
├── App/
│   ├── GymBrosApp.swift              ☐
│   └── RootView.swift                 ☐ (shows SignInView or empty home)
├── Core/
│   ├── Constants.swift                ☐
│   ├── Extensions/
│   │   └── Date+Extensions.swift      ☐ (helper methods)
│   ├── ErrorHandling/
│   │   ├── AppError.swift             ☐
│   │   ├── ErrorMapper.swift          ☐
│   │   └── ViewState.swift            ☐
│   └── AppTheme.swift                 ☐ (lime + purple colors)
├── Model/
│   ├── Profile.swift                  ☐
│   ├── Exercise.swift                 ☐
│   ├── Program.swift                  ☐
│   ├── ProgramDay.swift               ☐
│   ├── ProgramExercise.swift          ☐
│   ├── WorkoutSession.swift           ☐
│   ├── WorkoutSet.swift               ☐
│   └── Enums/
│       ├── MovementPattern.swift      ☐
│       ├── MuscleGroup.swift          ☐
│       ├── Equipment.swift            ☐
│       ├── ExperienceLevel.swift      ☐
│       ├── Goal.swift                 ☐
│       ├── WeightUnit.swift           ☐
│       └── TrainingPhase.swift        ☐
├── Data/
│   ├── Remote/
│   │   ├── SupabaseClient.swift       ☐
│   │   └── AuthService.swift          ☐
│   └── Repository/
│       ├── ProfileRepository.swift    ☐
│       ├── ExerciseRepository.swift   ☐
│       ├── ProgramRepository.swift    ☐
│       └── WorkoutRepository.swift    ☐
├── Presentation/
│   └── Auth/
│       └── SignInView.swift           ☐
└── Resources/
    └── Assets.xcassets/
        ├── AccentColor.colorset       ☐ (#C8FF00 lime)
        └── GymPurple.colorset         ☐ (#9B7FE8 purple)

GymBrosTests/
├── CodableTests.swift                 ☐
├── EnumsTests.swift                   ☐
└── ErrorHandlingTests.swift           ☐

supabase/
├── schema.sql                         ☐
└── seed_exercises.sql                 ☐
```

---

## 14. Implementation Order (For Claude Code)

When pasting this spec into Claude Code, build in this order:

```
1. Run schema.sql in Supabase SQL editor
2. Run seed_exercises.sql in Supabase SQL editor
3. Create Xcode project + add SDK packages
4. Build folder structure (empty groups)
5. Create all Enums first (no dependencies)
6. Create all Model structs (depend on enums)
7. Create Constants.swift
8. Create ErrorHandling foundation (`AppError`, `ErrorMapper`, `ViewState`)
9. Create ErrorHandlingTests.swift and make them pass
10. Create SupabaseClient.swift
11. Create AuthService.swift
12. Create all Repositories with `Result<Value, AppError>` or AppError-only throws
13. Create SignInView.swift
14. Wire up RootView + GymTrackApp
15. Run full unit tests
16. Test sign-in flow on simulator/device
17. Commit to main → Xcode Cloud builds → TestFlight
```

---

## 15. Notes for Implementation

### Important Things to Get Right

```
1. Date encoding/decoding strategy
   → All dates use ISO8601
   → Configure JSONEncoder/Decoder once in SupabaseClient

2. Apple Sign-In nonce
   → Must use SHA256 of randomly generated string
   → Pass raw nonce to Supabase, hashed nonce to Apple

3. Auto-profile creation trigger
   → Supabase trigger handles this on auth.users insert
   → Don't create profile manually in app code

4. Single active program enforcement
   → Database trigger handles this
   → App code can just set is_active = true

5. Supabase environment variables
   → Don't hardcode in production builds
   → Use xcconfig files or environment variables for prod
   → For Sprint 1, hardcoded in Constants.swift is fine
```

### What NOT to Build in This Sprint

```
✗ Program creation UI (Sprint 2)
✗ Workout logger UI (Sprint 3)
✗ Exercise picker UI (Sprint 2)
✗ Progressive overload logic (Sprint 5)
✗ Localization (Sprint 6)
✗ TelemetryDeck (Sprint 6)
✗ HealthKit code (Sprint 3)
```

---

## Done When

```
✅ All checklist items complete
✅ App runs on simulator
✅ Can sign in with Apple Sign-In
✅ Supabase shows 98 exercises
✅ Force quit + reopen → still signed in
✅ Sign out → returns to login
✅ All unit tests pass
✅ Error mapper and ViewState behavior covered by unit tests
✅ Supabase trigger security verified
✅ Code committed to main
✅ TestFlight build succeeds (after CI/CD setup in Sprint 4)
```

---

## After Completion

Update `GYMTRACK.md` Section 7 sprint tracking:

```
| 1 | Foundation + Data | ✅ Complete | <date> |
```

Add any decisions or learnings to Section 14 Decision Log.

Then move to Sprint 2 — create `/specs/S02-custom-program-builder.md`.
