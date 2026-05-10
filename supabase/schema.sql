create schema if not exists private;

-- User profile (extends Supabase auth.users)
create table public.profiles (
    id uuid references auth.users on delete cascade primary key,
    email text,
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
create or replace function private.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
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
returns trigger language plpgsql security definer set search_path = public
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

create or replace function public.handle_updated_at()
returns trigger language plpgsql set search_path = public
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
returns trigger language plpgsql set search_path = public
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
