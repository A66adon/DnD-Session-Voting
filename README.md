# DnD Session Voting

Simple voting app for planning the next DnD session.

## What this project includes

- **Backend:** Spring Boot + JPA
- **Frontend:** Flutter Web (`Frontend/frontend`)
- **Databases:**
  - `dev` profile: local H2 file database
  - `prod` profile: PostgreSQL (Railway)

## Core features

- Vote for available time slots of the current week
- Mark preferred slots (tie-breaker support)
- Reuse existing users by exact name match (case-sensitive)
- Automatic weekly reset and cleanup of old data (retention)

## Run locally

### 1) Backend (dev profile)

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev
```

Backend runs on `http://localhost:8080`.

### 2) Frontend (Flutter)

```bash
cd ./DnD-Session-Voting/Frontend/frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

## Production environment variables

Set these for the backend service:

- `DATABASE_URL`
- `PGUSER`
- `PGPASSWORD`
- `APP_VOTING_PASSWORD`
- `JWT_SECRET`
- `JWT_EXPIRATION`

## API overview

### Public endpoints

- `GET /api/voting/current-week`
- `GET /api/voting/current-results`
- `GET /api/voting/current-results-summary`
- `GET /api/voting/week/{weekId}/results`

### Authenticated endpoints

- `POST /api/auth/login`
- `POST /api/voting/vote`
- `POST /api/voting/reset-week`

## Example payloads

### Login request

```json
{
  "username": "Max",
  "password": "your-password"
}
```

### Vote request

```json
{
  "timeSlotIds": [1, 3, 5],
  "preferredTimeSlotIds": [3]
}
```

### Current week response (shortened)

```json
{
  "id": 12,
  "deadline": "2026-03-29",
  "active": true,
  "timeSlots": [
	{ "id": 1, "datetime": "2026-03-30T18:00:00" }
  ]
}
```

