# QuickPoll 1.1 to 1.3 - progress

Plan: ../../zscratchpads/quickpoll_1p1_to_1p3_plan.md (Developer/zscratchpads)

- [x] Stage 1: see a real 1.1 launch (teacher + student captured, signature verified: ../../zscratchpads/lti11_signature_known_answer.rb)
- [x] Stage 2: scaffold, schema, models, XML config, seed (code done)
- [x] Stage 2: XML installed in Canvas, launch reached the stub
- [x] Stage 3: Lti1p1::SignatureVerifier (19 specs) and Lti1p1::ReplayGuard (15 specs), both in app/services/lti1p1
- [ ] Stage 4: session, roles, polls  <- IN PROGRESS. Done: LaunchController checks + LaunchRecords + session (/lti/me) + Lti1p1::Roles (25 specs) + role in the session (step 5). + poll page (list + create, require_poll_creator, launch redirects to /lti/polls). + voting (step 7, 154 specs). Stage 4 code done after the live check. Not handled: two simultaneous votes from one person can raise RecordNotUnique (500). Next: /doc-maintainer-project, reflection, then Stage 5 (Basic Outcomes)
- [ ] Stage 5: Basic Outcomes
- [ ] Stage 6: Content-Item (optional)
- [ ] Stage 7: migrate to 1.3 (see "Stage 7 plan: keep a working 1.1 copy" below)

## Run it
- `docker compose up -d` then open http://quickpoll-1p1.inseng.test/lti/config
- `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec` (the -e matters: the container defaults to development)
- `docker compose logs -f web`

## Stage 4 notes
- Canvas `roles` comes in two formats. A teacher sends `Instructor`. An account admin with no enrollment sends `urn:lti:instrole:ims/lis/Administrator,urn:lti:sysrole:ims/lis/SysAdmin`, and only `ext_roles` has Instructor. Write LtiRoles to read the part after the last "/" and spec all three cases.
- DONE as Lti1p1::Roles. A real Canvas TA sends roles=`urn:lti:role:ims/lis/TeachingAssistant` and ext_roles=`urn:lti:instrole:ims/lis/Instructor,urn:lti:role:ims/lis/TeachingAssistant,urn:lti:sysrole:ims/lis/User`, so a TA is also `instructor?`. Poll pages ask `can_create_polls?` (instructor or TA). The unenrolled-admin spec shape is hand-built, not captured.

- Session cookie in an iframe: it works locally (canvas-web.inseng.test and quickpoll-1p1.inseng.test share a domain). In production Canvas and the tool are different sites, and browsers block third-party cookies. It needs `same_site: :none` + `secure: true`, and Safari blocks it anyway. Come back to this in Stage 7 (1.3 has the same problem).

## Stage 7 plan: keep a working 1.1 copy
Steve wants the 1.1 app to stay working. The 1.3 app is a copy of this repo, and the copy gets migrated.
1. Finish Stages 4 to 6 here. Run `git tag v1.1-final`.
2. `pg_dump` the 1.1 database. The migration needs real 1.1 users, polls, and votes to find again through the `lti1p1` claim (`lti_users.lti1p1_user_id`).
3. `git clone quickpoll_1p1 quickpoll_1p3`. Do not use `cp -r`. Point `origin` at a NEW GitHub repo.
4. In the copy, change the hostname so both apps run together: `docker-compose.yml` (Traefik rule, router name, both network aliases) and `config.hosts` in `config/environments/development.rb`. Use `quickpoll-1p3.inseng.test`.
5. Restore the dump into the copy's Postgres. Then migrate the code.
