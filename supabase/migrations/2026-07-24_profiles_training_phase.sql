alter table public.profiles
    add column if not exists training_phase text null;
