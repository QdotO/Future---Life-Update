# Life Updates - Proactive Tracking App

## Project Overview

**Purpose**: A multi-platform Apple app (iOS/macOS) that proactively prompts users to track personal goals through scheduled notifications, solving the common problem of poor self-reporting in traditional tracking apps.

**Core Concept**: Instead of waiting for users to open the app and log data, the app sends timely notifications asking specific questions about their progress, making tracking more conversational and habitual.

## Key Features

### 1. Notification Creation System

- Simple CRUD interface for managing tracking notifications
- AI-powered question generation based on tracking goals
- Customizable scheduling (time, date, intervals)
- Test notification functionality

### 2. Smart Prompting

- Context-aware notifications at optimal times
- Quick-response options directly from notifications
- Conversational tone to encourage engagement

### 3. Data Collection & Visualization

- Simple input methods for various data types
- Progress tracking over time
- Trend analysis and insights

## Progress summary (updated)

- Phase 1 MVP foundation implemented and verified in Simulator
- Core flows working: goal creation (two-step question builder + review), data entry, history, trends
- Notifications functional: per-question scheduling, categories, deep links, quick actions save path
- AppEnvironment added to support background/notification flows with SwiftData main context
- Phase 2 partial: initial Swift Charts (TrendsView) complete; remaining items queued (HealthKit, Focus/Background, AI, Live Activities)
- 2025-09-25: Goal category picker updated to adaptive chip grid with overflow drawer, custom label support, refreshed focus/hover styling, and regression coverage (unit + UI tests)

## User Flow

### 1. Initial Setup Flow

1. **Home Screen**
   - Empty state with "Add Tracking Goal" button
   - List of active tracking notifications (once created)

2. **Create New Tracking Goal**
   - Input: What do you want to track?
   - AI generates relevant questions
   - User selects questions via checkboxes/toggles
   - Schedule configuration:
     - Time and date selection
     - Repeat interval options
     - Category assignment (AI-suggested)

3. **Notification Details Page**
   - Review created notification
   - Test notification button
   - Edit/Delete options

### 2. Notification Response Flow

1. **User receives notification**
   - Shows tracking question
   - Quick action buttons (if applicable)

2. **Landing page on tap**
   - Display tracking goal context
   - Show current progress
   - Input interface for data entry
   - Submit button

3. **Post-submission**
   - Confirmation of data logged
   - Quick view of progress chart
   - Return to app or dismiss

## Technical Architecture

### Platform Requirements

- **Target**: iOS 18+ / macOS 15+ (leveraging latest platform capabilities)
- **UI Framework**: SwiftUI 6.0 with advanced animations and state management
- **Data Persistence**: SwiftData (replacing Core Data for modern Swift-first approach)
- **Notifications**: UserNotifications with Interactive Notifications and Live Activities
- **AI Integration**: Apple Intelligence APIs (on-device), Core ML, or OpenAI API fallback
  - Requires Apple Intelligence-enabled hardware; surfaces availability messaging when the on-device model is disabled or not ready
- **Charts**: Swift Charts for native data visualization
- **Shortcuts**: App Intents framework for Siri and Shortcuts integration
- **Widgets**: WidgetKit with Interactive Widgets (iOS 17+)
- **Background**: Background Tasks for intelligent notification scheduling
- **Extensions**: Notification Service Extensions for rich notifications

### Apple Platform Integration

- **Focus Filters**: Respect user's Focus modes for notification delivery
- **Live Activities**: Real-time progress updates on Lock Screen and Dynamic Island
- **App Shortcuts**: Voice shortcuts for quick data entry via Siri
- **Health Integration**: HealthKit for relevant health metrics (water, exercise, etc.)
- **CloudKit**: Cross-device sync for multi-platform experience
- **Privacy**: Privacy Manifests and on-device processing where possible

### Data Models (SwiftData)

```swift
@Model
class TrackingGoal {
    @Attribute(.unique) var id: UUID
    var title: String
    var goalDescription: String
    var category: TrackingCategory
    var questions: [Question]
    var schedule: Schedule
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Relationships
    @Relationship(deleteRule: .cascade) var dataPoints: [DataPoint]
    
    init(title: String, description: String, category: TrackingCategory) {
        self.id = UUID()
        self.title = title
        self.goalDescription = description
        self.category = category
        self.questions = []
        self.schedule = Schedule()
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
        self.dataPoints = []
    }
}

@Model 
class Question {
    @Attribute(.unique) var id: UUID
    var text: String
    var responseType: ResponseType
    var isActive: Bool
    var options: [String]? // For multiple choice
    var validationRules: ValidationRules?
    
    init(text: String, responseType: ResponseType) {
        self.id = UUID()
        self.text = text
        self.responseType = responseType
        self.isActive = true
    }
}

@Model
class Schedule {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var frequency: Frequency
    var times: [DateComponents] // Using DateComponents for better time handling
    var endDate: Date?
    var timezone: TimeZone
    
    init() {
        self.id = UUID()
        self.startDate = Date()
        self.frequency = .daily
        self.times = []
        self.timezone = TimeZone.current
    }
}

@Model
class DataPoint {
    @Attribute(.unique) var id: UUID
    var goalId: UUID
    var questionId: UUID
    var numericValue: Double?
    var textValue: String?
    var boolValue: Bool?
    var selectedOptions: [String]?
    var timestamp: Date
    var mood: Int? // 1-5 scale for context
    var location: String? // Optional location context
    
    init(goalId: UUID, questionId: UUID, timestamp: Date = Date()) {
        self.id = UUID()
        self.goalId = goalId
        self.questionId = questionId
        self.timestamp = timestamp
    }
}

enum ResponseType: String, CaseIterable, Codable {
    case numeric = "numeric"
    case scale = "scale" // 1-10 rating
    case boolean = "boolean"
    case multipleChoice = "multipleChoice"
    case text = "text"
    case time = "time"
    case slider = "slider"
}

enum Frequency: String, CaseIterable, Codable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case custom = "custom"
}

enum TrackingCategory: String, CaseIterable, Codable {
    case health = "health"
    case fitness = "fitness"
    case productivity = "productivity"
    case habits = "habits"
    case mood = "mood"
    case learning = "learning"
    case social = "social"
    case finance = "finance"
    case custom = "custom"
}
```

### Phase 1: MVP Foundation (Weeks 1-3)

- [ ] **SwiftData Setup & Models**
  - [ ] Configure SwiftData container and model context
  - [ ] Implement TrackingGoal, Question, Schedule, DataPoint models
  - [ ] Setup CloudKit sync for cross-device persistence
  
- [ ] **SwiftUI Architecture**
  - [ ] Navigation stack with programmatic routing
  - [ ] MVVM pattern with @Observable view models
  - [ ] Shared state management using @Environment
  
- [ ] **Basic Notification System**
  - [ ] UserNotifications permission handling
  - [ ] Local notification scheduling with UNTimeIntervalNotificationTrigger
  - [ ] Basic notification actions (Mark Complete, Snooze)
  
- [ ] **Core UI Components**
  - [ ] Home feed with SwiftUI List and custom cards
  - [ ] Goal creation flow with form validation
  - [ ] Manual question input with different response types
  
- [ ] **Data Entry & Storage**
  - [ ] Simple numeric/text input interfaces
  - [ ] SwiftData CRUD operations
  - [ ] Basic data validation

*See [Phase 1 Details](phase1-mvp.md) for implementation specifics*

### Phase 2: Enhanced Features (Weeks 4-6)

- [ ] **Apple Intelligence Integration**
  - [ ] On-device natural language processing for question generation
  - [ ] Smart categorization using Core ML
  - [ ] Intelligent notification timing based on user patterns
  
- [ ] **Advanced Notifications**
  - [ ] Interactive notifications with custom UI
  - [ ] Notification Service Extensions for rich content
  - [ ] Live Activities for ongoing tracking
  
- [ ] **Data Visualization**
  - [ ] Swift Charts integration for trend analysis
  - [ ] Interactive charts with gesture support
  - [ ] Export to Health app integration
  
- [ ] **Smart Scheduling**
  - [ ] Focus Filter integration
  - [ ] Background Tasks for intelligent timing
  - [ ] Adaptive scheduling based on response patterns

*See [Phase 2 Details](phase2-enhanced.md) for implementation specifics*

### Phase 3: Platform Integration & Polish (Weeks 7-8)

- [ ] **App Intents & Shortcuts**
  - [ ] Voice shortcuts for quick data entry
  - [ ] Siri integration for hands-free tracking
  - [ ] Shortcuts app automation
  
- [ ] **Widget & Extensions**
  - [ ] Interactive Widgets for quick updates
  - [ ] Control Center integration
  - [ ] Apple Watch companion app basics
  
- [ ] **Platform Optimization**
  - [ ] macOS-specific UI adaptations (toolbars, menus)
  - [ ] iOS-specific features (Dynamic Island, Action Button)
  - [ ] Performance optimization and memory management
  
- [ ] **Advanced Features**
  - [ ] Export capabilities (CSV, Health app)
  - [ ] Settings with Privacy Dashboard
  - [ ] Advanced analytics and insights

*See [Phase 3 Details](phase3-polish.md) for implementation specifics*

## UI/UX Guidelines

### Design Principles

- **Simplicity**: Minimal steps to create and respond to tracking
- **Clarity**: Clear visual hierarchy and intuitive navigation
- **Speed**: Quick data entry with minimal friction
- **Delight**: Encouraging feedback and progress visualization

### Key Screens

1. **Home Feed**

   - Card-based layout for tracking goals
   - Clear add button
   - Status indicators for each goal

2. **Creation Flow**
   - Step-by-step wizard
   - Live preview of notifications
   - Smart defaults

3. **Response Interface**
   - Large, easy-to-tap inputs
   - Contextual information
   - Quick submit action

## Success Metrics

- User engagement rate (responses/notifications sent)
- Tracking consistency over time
- Time to create new tracking goal
- User retention at 30/60/90 days

## Future Considerations

### iOS 18+ Features

- **Apple Intelligence**: On-device AI for smart question generation and insights
- **Control Center Integration**: Quick widgets for immediate data entry
- **Dynamic Island**: Live progress updates during active tracking
- **Interactive Widgets**: Home screen widgets with direct input capabilities
- **Action Button (iPhone 15 Pro)**: Customizable quick-entry shortcut

### macOS 15+ Features  

- **Menu Bar Integration**: Persistent access with native menu bar app
- **Desktop Widgets**: Always-visible progress tracking on desktop
- **Shortcuts Integration**: Deep automation with macOS Shortcuts
- **Stage Manager**: Optimized window management for productivity workflows

### Cross-Platform Continuity

- **Handoff**: Continue tracking session between devices
- **Universal Clipboard**: Copy tracking data between devices  
- **iCloud Sync**: Real-time data synchronization
- **Health App Integration**: Bi-directional sync with HealthKit metrics

### Long-term Vision

- **Apple Watch**: Standalone tracking with Digital Crown input
- **Apple Vision Pro**: Spatial computing interface for data visualization
- **Siri Integration**: Natural language tracking commands
- **Machine Learning**: Predictive suggestions based on patterns
- **Social Features**: Family sharing and accountability partners
- **Third-party Integrations**: API for fitness apps, smart home devices
