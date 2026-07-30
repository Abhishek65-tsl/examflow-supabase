-- ExamFlow database. Run the complete file in Supabase SQL Editor.
create extension if not exists pgcrypto;
create type public.user_role as enum ('student','admin');
create type public.test_status as enum ('draft','published','archived');
create type public.attempt_status as enum ('in_progress','submitted');

create table public.profiles(id uuid primary key references auth.users(id) on delete cascade,full_name text not null default '',role public.user_role not null default 'student',created_at timestamptz not null default now());
create table public.tests(id uuid primary key default gen_random_uuid(),title text not null,subject text not null,class_name text not null,duration_minutes int not null check(duration_minutes between 1 and 300),status public.test_status not null default 'draft',starts_at timestamptz,ends_at timestamptz,created_by uuid not null default auth.uid() references public.profiles(id),created_at timestamptz not null default now());
create table public.questions(id uuid primary key default gen_random_uuid(),test_id uuid not null references public.tests(id) on delete cascade,body text not null,option_a text not null,option_b text not null,option_c text not null,option_d text not null,marks numeric(8,2) not null default 1 check(marks>0),display_order int not null default 1,unique(test_id,display_order));
create table public.answer_keys(question_id uuid primary key references public.questions(id) on delete cascade,correct_option text not null check(correct_option in ('A','B','C','D')),explanation text);
create table public.attempts(id uuid primary key default gen_random_uuid(),test_id uuid not null references public.tests(id),student_id uuid not null default auth.uid() references public.profiles(id),status public.attempt_status not null default 'submitted',score numeric(10,2) not null default 0,total_marks numeric(10,2) not null default 0,percentage numeric(5,2) not null default 0,correct_count int not null default 0,total_questions int not null default 0,submitted_at timestamptz not null default now());
create table public.attempt_answers(id uuid primary key default gen_random_uuid(),attempt_id uuid not null references public.attempts(id) on delete cascade,question_id uuid not null references public.questions(id),selected_option text check(selected_option in ('A','B','C','D')),is_correct boolean not null,marks_awarded numeric(8,2) not null default 0,unique(attempt_id,question_id));
create index tests_status_idx on public.tests(status);create index questions_test_idx on public.questions(test_id);create index attempts_student_idx on public.attempts(student_id);create index attempts_test_idx on public.attempts(test_id);

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$begin insert into public.profiles(id,full_name) values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''));return new;end$$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from profiles where id=auth.uid() and role='admin')$$;

-- Atomic server-side grading. Students never receive answer_keys before submission.
create or replace function public.submit_test(p_test_id uuid,p_answers jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare v_attempt uuid;v_score numeric:=0;v_total numeric:=0;v_correct int:=0;v_count int:=0;r record;v_selected text;begin
 if auth.uid() is null then raise exception 'Authentication required';end if;
 if not exists(select 1 from tests where id=p_test_id and status='published' and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now())) then raise exception 'Test is not available';end if;
 select coalesce(sum(marks),0),count(*) into v_total,v_count from questions where test_id=p_test_id;
 insert into attempts(test_id,student_id,total_marks,total_questions) values(p_test_id,auth.uid(),v_total,v_count) returning id into v_attempt;
 for r in select q.id,q.marks,k.correct_option from questions q join answer_keys k on k.question_id=q.id where q.test_id=p_test_id loop
   select value->>'selected_option' into v_selected from jsonb_array_elements(p_answers) where value->>'question_id'=r.id::text limit 1;
   if v_selected=r.correct_option then v_score:=v_score+r.marks;v_correct:=v_correct+1;end if;
   insert into attempt_answers(attempt_id,question_id,selected_option,is_correct,marks_awarded) values(v_attempt,r.id,v_selected,v_selected=r.correct_option,case when v_selected=r.correct_option then r.marks else 0 end);
 end loop;
 update attempts set score=v_score,percentage=case when v_total>0 then round(v_score*100/v_total,2) else 0 end,correct_count=v_correct where id=v_attempt;
 return jsonb_build_object('attempt_id',v_attempt,'score',v_score,'total_marks',v_total,'percentage',case when v_total>0 then round(v_score*100/v_total,2) else 0 end,'correct_count',v_correct,'total_questions',v_count);
end$$;

alter table profiles enable row level security;alter table tests enable row level security;alter table questions enable row level security;alter table answer_keys enable row level security;alter table attempts enable row level security;alter table attempt_answers enable row level security;
create policy profiles_self_or_admin_read on profiles for select to authenticated using(id=auth.uid() or is_admin());
create policy profiles_self_update on profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid() and role=(select role from profiles where id=auth.uid()));
create policy tests_read on tests for select to authenticated using(status='published' or is_admin());
create policy tests_admin_insert on tests for insert to authenticated with check(is_admin());create policy tests_admin_update on tests for update to authenticated using(is_admin()) with check(is_admin());create policy tests_admin_delete on tests for delete to authenticated using(is_admin());
create policy questions_read on questions for select to authenticated using(is_admin() or exists(select 1 from tests t where t.id=test_id and t.status='published'));
create policy questions_admin_all on questions for all to authenticated using(is_admin()) with check(is_admin());
create policy keys_admin_all on answer_keys for all to authenticated using(is_admin()) with check(is_admin());
create policy attempts_own_or_admin_read on attempts for select to authenticated using(student_id=auth.uid() or is_admin());
create policy answers_own_or_admin_read on attempt_answers for select to authenticated using(is_admin() or exists(select 1 from attempts a where a.id=attempt_id and a.student_id=auth.uid()));
grant usage on schema public to authenticated;grant select,insert,update,delete on profiles,tests,questions,answer_keys,attempts,attempt_answers to authenticated;grant execute on function public.submit_test(uuid,jsonb) to authenticated;grant execute on function public.is_admin() to authenticated;
-- After signing up your teacher, promote once in SQL Editor:
-- update public.profiles set role='admin' where id=(select id from auth.users where email='teacher@example.com');
