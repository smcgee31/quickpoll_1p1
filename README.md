# QuickPoll 1.1

A small poll tool for Canvas, written as a hackweek project to learn LTI 1.1. An instructor or a TA creates polls in a course. Everyone in the course votes once per poll. A person sees the counts after voting.

Status: FINAL. Stages 1 to 4 are done (launch check, session, roles, polls, voting) with 154 specs, and a live launch in the local Canvas works. Grade passback and Content-Item were skipped. The 1.3 version lives in its own repo, `quickpoll_1p3`.

## Read this first

- `zscratchpads/quickpoll-1p1-walkthrough.html`: how the app works, from the Canvas click to the saved vote.
- `zscratchpads/lti-1p1-vs-1p3.html`: the differences between a 1.1 tool and a 1.3 tool, with pictures.
- `zscratchpads/TODO.md`: progress and notes.

## Requirements

- Docker, and inst-cli with the local Canvas running (`canvas-web.inseng.test`)
- Traefik from inst-cli. The app answers on http://quickpoll-1p1.inseng.test

## Run it

```
docker compose up -d
docker compose exec -T web bin/rails db:prepare db:seed
curl http://quickpoll-1p1.inseng.test/lti/config
```

The seed makes one consumer (`key` and `secret`). Paste the XML from `/lti/config` into Canvas (Settings, Apps, + App, Paste XML) with that key and secret.

Tests:

```
docker compose run --rm -e RAILS_ENV=test web bundle exec rspec
```

## Configuration

- `PUBLIC_BASE_URL` (set in `docker-compose.yml`): the URL Canvas signs. The signature check builds the URL from it, because behind a proxy `request.url` does not match what Canvas signed.

## Data and privacy

A launch carries names, emails, and user ids. That is student data under FERPA. Use fake users in a test course. Keep real launches out of docs and fixtures. `key` and `secret` are for local use only.
