alter table public.program_exercises
    add column if not exists target_weight numeric null;
