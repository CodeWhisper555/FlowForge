# Workflow Manager — Cross-Platform Flutter Application

A production-ready, dependency-driven Workflow Manager built with Flutter, Dart, Riverpod, and Firebase for Android and Web.

---

## 1. Project Overview

Unlike basic to-do applications that maintain flat lists, **Workflow Manager** models real-world projects as Directed Acyclic Graphs (DAGs) of interrelated tasks. The application dynamically evaluates dependencies to determine which steps are actionable and which remain pending prerequisite completion.

### Progression Modes Supported:
1. **Manual Progression:** Users advance actionable tasks across standard lifecycles (`Ready` ➔ `In Progress` ➔ `Completed`, `Blocked`, or `Cancelled`).
2. **Automatic Progression:** The domain engine continuously inspects prerequisite satisfaction and automatically unlocks eligible downstream steps to `Ready` as soon as all prerequisite steps reach `Completed`.

#### Canonical Example: *"Develop a College Project"*
- **Planning** (No prerequisites ➔ automatically `Ready`)
- **Development** (Depends on `Planning` ➔ `Pending`)
- **Documentation** (Depends on `Planning` ➔ `Pending`)
- **Testing** (Depends on both `Development` AND `Documentation` ➔ `Pending`)
- **Final Submission** (Depends on `Testing` ➔ `Pending`)

When `Planning` is marked Completed, both `Development` and `Documentation` unlock simultaneously. `Testing` remains Pending until both branches are finished.

---

## 2. Architecture & Directory Structure

The project adheres to a **Feature-First Layered Architecture**:

```
lib/
├── app/
│   ├── app.dart                   # MaterialApp.router configuration & theme bindings
│   └── router.dart                # GoRouter with authentication route protection
├── bootstrap.dart                 # App initialization, Firebase auto-detection & fallback
├── firebase_options.dart          # FlutterFire configuration entrypoint
├── main.dart                      # App entrypoint
├── core/
│   ├── constants/                 # Status & Priority color palette mappings
│   ├── errors/                    # Domain exceptions (CycleDetectedException, etc.)
│   ├── theme/                     # Material 3 light and dark theme definitions
│   ├── utils/                     # Date formatters (intl)
│   └── validators/                # Form validation helpers
├── shared/
│   ├── layout/
│   │   └── responsive_scaffold.dart # Adaptive NavigationRail (Desktop/Web) & NavigationBar (Mobile)
│   └── widgets/
│       ├── confirmation_dialog.dart
│       ├── empty_state_widget.dart
│       ├── priority_badge.dart
│       ├── progress_bar_card.dart
│       └── status_badge.dart
└── features/
    ├── auth/
    │   ├── domain/ (models, repository interface)
    │   ├── data/ (InMemoryAuthRepository, FirebaseAuthRepository)
    │   └── presentation/ (AuthScreen, Riverpod providers)
    ├── workflows/
    │   ├── domain/ (models, WorkflowEngine, enums, repository interface)
    │   ├── data/ (InMemoryWorkflowRepository, FirestoreWorkflowRepository)
    │   └── presentation/ (Dashboard, List, Create/Edit, Details, StepDialogs, providers)
    ├── templates/
    │   ├── domain/ (models, factory helpers)
    │   ├── data/ (InMemoryTemplateRepository)
    │   └── presentation/ (TemplatesScreen, providers)
    ├── activity/
    │   ├── domain/ (ActivityLog, ActivityType)
    │   ├── data/ (InMemoryActivityRepository)
    │   └── presentation/ (ActivityScreen timeline, providers)
    └── notifications/
        └── domain/services/ (NotificationService abstraction & deadline alerts)
```

---

## 3. Workflow Engine (`WorkflowEngine`)

The workflow engine is an isolated, testable domain class independent of UI and databases:

- **Cycle Detection:** Implements 3-state graph DFS coloring (White/Gray/Black) to detect circular dependencies and report the exact cycle path (`CycleDetectedException`).
- **Data Integrity:** Rejects duplicate step IDs, self-dependencies, duplicate dependencies, and orphaned prerequisite IDs.
- **Status Transitions Matrix:**
  - `Pending`: Automatically becomes `Ready` when all prerequisites are `Completed`.
  - `Ready`: Can transition to `In Progress`, `Completed`, `Blocked`, or `Cancelled`. Automatically reverts to `Pending` if a prerequisite is reopened.
  - `In Progress`: Can transition to `Completed`, `Blocked`, `Cancelled`, or `Ready`.
  - `Blocked`: Explicit user block. Unblocking re-evaluates prerequisites.
  - `Completed`: Reopening is safeguarded: users can choose to retain completed work downstream or reset downstream actionable steps.
  - `Cancelled`: Can be reopened.
- **Safe Step Deletion:** Detects if dependent steps rely on a step slated for deletion. Offers automated prerequisite cascade removal or aborts deletion.
- **Idempotency:** Calling `recalculateWorkflow` repeatedly produces strictly identical state.

---

## 4. Dual Persistence & Firebase Integration

The architecture employs interface-based repositories (`WorkflowRepository`, `AuthRepository`, `ActivityRepository`, `TemplateRepository`):

### 1. In-Memory Development Mode (Active by default)
- Operates out-of-the-box without requiring Firebase CLI login or project credentials.
- Pre-seeded with:
  - Demo User (`demo@workflowmanager.io` / `password123`).
  - Pre-loaded "Develop a College Project" workflow showcasing branch dependencies.
  - Pre-loaded "Mobile App Store Release" workflow.
  - Reusable industry templates (Software Feature Delivery, Research Paper Publication).
- Clearly flagged in the UI with a top-bar `DEV MOCK MODE` badge.

### 2. Cloud Firestore & Firebase Auth Mode
- Automatically engages when `DefaultFirebaseOptions.currentPlatform` is configured via FlutterFire.
- Implements:
  - Document-embedded workflow steps (Atomic writes, 1-read retrieval, real-time sync).
  - User-scoped queries (`where('userId', isEqualTo: user.id)`).
  - Firestore security rules in `firestore.rules`.
  - Compound indexes in `firestore.indexes.json`.

---

## 5. Security Rules (`firestore.rules`)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /workflows/{workflowId} {
      allow read, update, delete: if request.auth != null && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
    match /templates/{templateId} {
      allow read: if request.auth != null && (resource.data.userId == 'system' || resource.data.userId == request.auth.uid);
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && resource.data.userId == request.auth.uid;
    }
    match /activities/{activityId} {
      allow read: if request.auth != null && resource.data.userId == request.auth.uid;
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## 6. Firebase Cloud Functions (`functions/`)

Located in `functions/`:
- **`onWorkflowWritten`:** Firestore v2 trigger that verifies workflow integrity and synchronizes workflow completion status upon document updates.
- **`checkWorkflowDeadlines`:** Scheduled cron job running every 24 hours to identify overdue and upcoming deadlines and record alerts into the activity timeline.

---

## 7. How to Run the Application

### Prerequisites:
- Flutter SDK 3.32+
- Dart SDK 3.8+
- Google Chrome or Android Emulator

### Run on Web (Development Mode):
```bash
flutter run -d chrome
```

### Run on Android:
```bash
flutter run -d android
```

### Run All Automated Tests:
```bash
flutter test
```

### Run Static Analysis:
```bash
flutter analyze
```

### Build for Production Web:
```bash
flutter build web
```

---

## 8. Connecting Live Firebase Backend

1. Install the Firebase CLI and FlutterFire CLI:
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```
2. Log in to Firebase:
   ```bash
   firebase login
   ```
3. Run the configuration command in the project root:
   ```bash
   flutterfire configure
   ```
   This generates `lib/firebase_options.dart` with platform API keys and project IDs.
4. Deploy Firestore rules and indexes:
   ```bash
   firebase deploy --only firestore
   ```
5. Deploy Cloud Functions:
   ```bash
   cd functions
   npm install
   cd ..
   firebase deploy --only functions
   ```

---

## 9. Verification & Test Results

All test suites and static analysis checks have been executed and verified:

| Test Suite | File | Tests Run | Result |
| :--- | :--- | :---: | :---: |
| WorkflowEngine Unit Tests | `test/unit/workflow_engine_test.dart` | 16 | **PASSED** |
| Auth Screen Widget Tests | `test/widget/auth_screen_test.dart` | 2 | **PASSED** |
| Dashboard Widget Tests | `test/widget/dashboard_screen_test.dart` | 1 | **PASSED** |
| Workflow Details Widget Tests | `test/widget/workflow_details_test.dart` | 1 | **PASSED** |
| App Root Smoke Test | `test/widget_test.dart` | 1 | **PASSED** |
| End-to-End User Journey Test | `test/integration/user_journey_test.dart` | 1 | **PASSED** |
| **Total Automated Tests** | | **22** | **ALL PASSED (100%)** |
| **Static Analysis (`flutter analyze`)** | Project workspace | - | **0 Issues / Clean** |
| **Web Production Build (`flutter build web`)** | `build/web` | - | **Compiled Successfully** |

---

## 10. Completed Feature Checklist

- [x] Multi-platform Flutter architecture (Android, Web, Desktop responsive).
- [x] Feature-first layered architecture with Riverpod state management.
- [x] Type-safe GoRouter navigation with authentication redirection.
- [x] Dedicated `WorkflowEngine` domain class with graph cycle detection.
- [x] Branching and multi-prerequisite dependency evaluation.
- [x] Automatic progression (prerequisite completion unlocking eligible steps).
- [x] Reopening policy handling (protects completed descendant work or optional reset).
- [x] Safe deletion of steps with cascade dependency detachment.
- [x] Dashboard with summary metrics, quick actions, and recent workflows.
- [x] Responsive layout (Side Navigation Rail for desktop/web, NavigationBar for mobile).
- [x] Full workflow CRUD with priority, due date, status, and description.
- [x] Step CRUD and real-time dependency selector dialog.
- [x] Reusable workflow templates (copying with fresh UUIDs and remapped dependency graphs).
- [x] Activity history timeline tracking workflow events.
- [x] Dual persistence architecture (InMemory fallback + official Firebase Auth & Firestore).
- [x] Firestore security rules and compound indexes.
- [x] Cloud Functions backend automation structure.
