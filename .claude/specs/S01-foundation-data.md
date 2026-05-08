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

**Effort estimate:** Medium (1–2 focused coding sessions)

**Dependencies:** None — this is the first sprint.

---

## 1. Requirements

### Must Have

```
✓ Xcode project compiles and runs on simulator
✓ Tap "Sign in with Apple" → authenticates → creates profile in Supabase
✓ Auth state persists across app launches
✓ Supabase has all tables, indexes, and RLS policies
✓ ~100 exercises seeded in Thai + English
✓ Sign out works correctly
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
   Version: latest stable (1.x)

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
    name_en text not null,
    name_th text not null,
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
    rpe numeric(3,1),                  -- 1.0 to 10.0, nullable
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
create policy "Authenticated users can view exercises" on public.exercises
    for select using (auth.uid() is not null);

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
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, name)
    values (new.id, coalesce(new.raw_user_meta_data->>'full_name', null));
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

-- Auto-update updated_at on profiles + programs
create or replace function public.handle_updated_at()
returns trigger
language plpgsql
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

### Model/Exercise.swift

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
    
    /// Returns localized name based on current locale
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
            let session = try await client.auth.session
            self.currentUser = session.user
        } catch {
            self.currentUser = nil
        }
    }
    
    /// Sign in with Apple — pass the credential from ASAuthorizationAppleIDCredential
    func signInWithApple(idToken: String, nonce: String) async throws {
        let session = try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
        self.currentUser = session.user
    }
    
    /// Sign out
    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
    }
}
```

### Presentation/Auth/SignInView.swift

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
            throw RepositoryError.notAuthenticated
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

### Data/Repository/RepositoryError.swift

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

---

## 9. Seed Exercises

Run this AFTER schema.sql in Supabase SQL Editor.

### seed_exercises.sql

```sql
-- ~100 exercises covering common movement patterns
-- Add more as needed in Sprint 2

insert into public.exercises (name_en, name_th, movement_pattern, primary_muscle, secondary_muscles, equipment, is_compound) values
-- BARBELL COMPOUNDS
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

-- DUMBBELL EXERCISES
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

-- MACHINE EXERCISES
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

-- CABLE EXERCISES
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

-- BODYWEIGHT
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

-- KETTLEBELL
('Kettlebell Swing', 'เคทเทิลเบลสวิง', 'hinge', 'glutes', '{hamstrings,back}', 'kettlebell', true),
('Kettlebell Goblet Squat', 'เคทเทิลกอบเล็ทสควอท', 'squat', 'quads', '{glutes,core}', 'kettlebell', true),
('Kettlebell Clean', 'เคทเทิลคลีน', 'pull', 'back', '{glutes,shoulders}', 'kettlebell', true),
('Kettlebell Press', 'เคทเทิลเพรส', 'push', 'shoulders', '{triceps}', 'kettlebell', true),
('Kettlebell Row', 'เคทเทิลโรว์', 'pull', 'back', '{biceps}', 'kettlebell', true),
('Turkish Get-Up', 'เทอร์กิชเก็ทอัพ', 'core', 'core', '{shoulders}', 'kettlebell', true),

-- BARBELL — additional
('Barbell Curl', 'เคิลบาร์เบล', 'pull', 'biceps', '{}', 'barbell', false),
('Barbell Skull Crusher', 'สกัลครัชเชอร์บาร์เบล', 'push', 'triceps', '{}', 'barbell', false),
('Barbell Shrug', 'ชรักบาร์เบล', 'pull', 'traps', '{}', 'barbell', false),
('Barbell Calf Raise', 'แคล์ฟเรซบาร์เบล', 'core', 'calves', '{}', 'barbell', false),
('Barbell Good Morning', 'กู๊ดมอร์นิ่ง', 'hinge', 'hamstrings', '{back,glutes}', 'barbell', true),
('Barbell Reverse Lunge', 'รีเวิร์สลันจ์', 'lunge', 'quads', '{glutes,hamstrings}', 'barbell', true),
('Close Grip Bench Press', 'โคลสกริปเบนช์', 'push', 'triceps', '{chest,shoulders}', 'barbell', true),
('Incline Bench Press', 'อินไคลน์เบนช์', 'push', 'chest', '{shoulders,triceps}', 'barbell', true),
('Decline Bench Press', 'ดีไคลน์เบนช์', 'push', 'chest', '{triceps}', 'barbell', true),

-- DUMBBELL — additional
('Dumbbell Step-Up', 'สเต็พอัพดัมเบล', 'lunge', 'quads', '{glutes}', 'dumbbell', true),
('Dumbbell Reverse Lunge', 'รีเวิร์สลันจ์ดัมเบล', 'lunge', 'quads', '{glutes,hamstrings}', 'dumbbell', true),
('Dumbbell Walking Lunge', 'วอล์กกิ้งลันจ์', 'lunge', 'quads', '{glutes,hamstrings}', 'dumbbell', true),
('Dumbbell Side Lateral', 'ดัมเบลไซด์เลทเทอรัล', 'push', 'shoulders', '{}', 'dumbbell', false),
('Dumbbell Concentration Curl', 'คอนเซนเทรชันเคิล', 'pull', 'biceps', '{}', 'dumbbell', false),
('Dumbbell Reverse Fly', 'รีเวิร์สฟลาย', 'pull', 'shoulders', '{traps}', 'dumbbell', false),

-- BAND EXERCISES
('Band Pull-Apart', 'แบนด์พูลอะพาร์ท', 'pull', 'shoulders', '{traps}', 'band', false),
('Band Face Pull', 'แบนด์เฟซพูล', 'pull', 'shoulders', '{traps}', 'band', false),
('Band Tricep Pushdown', 'แบนด์ทรายเซ็พ', 'push', 'triceps', '{}', 'band', false),
('Band Bicep Curl', 'แบนด์ไบเซ็พ', 'pull', 'biceps', '{}', 'band', false);

-- Verify count
select count(*) as exercise_count from public.exercises;
-- Should be ~95
```

---

## 10. Acceptance Criteria

```
☐ Build succeeds on iOS 17+ simulator
☐ Tap "Sign in with Apple" → Apple sheet → returns to app authenticated
☐ Profile row created in Supabase with auth user's id
☐ Force quit + reopen app → still authenticated (session persisted)
☐ Tap Sign Out → returns to login screen
☐ Supabase shows ~95 exercises in Thai + English
☐ ProgramRepository.fetchAll() returns empty array (no programs yet)
☐ ExerciseRepository.fetchAll() returns ~95 exercises
☐ All Codable models compile without warnings
☐ RLS works: querying another user's profile from SQL editor returns nothing
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
Apple ID has no email shared           OK — we don't require email
User deletes account in Apple settings Session invalidated on next launch
```

---

## 12. Unit Tests

### GymTrackTests/CodableTests.swift

```swift
import XCTest
@testable import GymBros

final class CodableTests: XCTestCase {
    
    func testExerciseDecodesFromSupabaseJSON() throws {
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
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let exercise = try decoder.decode(Exercise.self, from: json)
        
        XCTAssertEqual(exercise.nameEn, "Bench Press")
        XCTAssertEqual(exercise.nameTh, "เบนช์เพรส")
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
│       ├── WorkoutRepository.swift    ☐
│       └── RepositoryError.swift      ☐
├── Presentation/
│   └── Auth/
│       └── SignInView.swift           ☐
└── Resources/
    └── Assets.xcassets/
        ├── AccentColor.colorset       ☐ (#C8FF00 lime)
        └── GymPurple.colorset         ☐ (#9B7FE8 purple)

GymBrosTests/
├── CodableTests.swift                 ☐
└── EnumsTests.swift                   ☐

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
8. Create RepositoryError.swift
9. Create SupabaseClient.swift
10. Create AuthService.swift
11. Create all Repositories
12. Create SignInView.swift
13. Wire up RootView + GymTrackApp
14. Run unit tests
15. Test sign-in flow on simulator
16. Commit to main → Xcode Cloud builds → TestFlight
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
✅ Supabase shows 95+ exercises
✅ Force quit + reopen → still signed in
✅ Sign out → returns to login
✅ All unit tests pass
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
