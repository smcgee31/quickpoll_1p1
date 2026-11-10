# QuickPoll 1.1 to 1.3 - progress

Plan: ../../zscratchpads/quickpoll_1p1_to_1p3_plan.md (Developer/zscratchpads)

- [x] Stage 1: see a real 1.1 launch (teacher + student captured, signature verified: ../../zscratchpads/lti11_signature_known_answer.rb)
- [x] Stage 2: scaffold, schema, models, XML config, seed (code done)
- [x] Stage 2: XML installed in Canvas, launch reached the stub
- [ ] Stage 3: Lti1p1::SignatureVerifier  <- NEXT (specs written in spec/services/lti1p1; implement app/services/lti1p1/signature_verifier.rb)
- [ ] Stage 4: session, roles, polls
- [ ] Stage 5: Basic Outcomes
- [ ] Stage 6: Content-Item (optional)
- [ ] Stage 7: migrate to 1.3

## Run it
- `docker compose up -d` then open http://quickpoll-1p1.inseng.test/lti/config
- `docker compose run --rm -e RAILS_ENV=test web bundle exec rspec` (the -e matters: the container defaults to development)
- `docker compose logs -f web`

## Stage 4 notes
- Canvas `roles` comes in two formats. A teacher sends `Instructor`. An account admin with no enrollment sends `urn:lti:instrole:ims/lis/Administrator,urn:lti:sysrole:ims/lis/SysAdmin`, and only `ext_roles` has Instructor. Write LtiRoles to read the part after the last "/" and spec all three cases.
- Stage 3 step 4 (timestamp window + nonce replay via used_nonces) is not in the signature spec. Give it its own class and spec.
