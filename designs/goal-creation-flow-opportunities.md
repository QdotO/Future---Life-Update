# Goal Creation Flow – UX Opportunities

This document captures refinement ideas surfaced during the September 25, 2025 review of the goal creation wizard. Each opportunity focuses on helping users understand completion state before advancing to the next step.

## 1. Goal Basics Step

- **Inline completion checklist**: Display a small checklist ("Needs title", "Needs description", "Pick a category") that flips to checkmarks as each requirement is satisfied.
- **Category helper text**: When the default category remains selected, surface helper copy beneath the picker (e.g., “Choose a category to keep things organized”).

## 2. Question Composer

- **Dynamic stage status**: Replace the static "Step 1 of 2" label with contextual guidance (e.g., “Pick a prompt and response type to continue”) that switches to a success state once valid.
- **Step-two validation pill**: Show a compact status capsule ("Add at least one option") that turns into “Looks good” when the configuration meets requirements.
- **Summary list affordances**: Prepend each question card with a completion icon (✓ or ⚠️) and highlight missing details in color to draw attention.
- **Quick-start suggestions**: When no questions exist, offer scaffold chips like “Daily reflection” or “Water intake” to orient first-time users.

## 3. Schedule Step

- **Progress badge**: Present a pill such as “2 reminders set” or “No reminders yet” to make completion visible at a glance.
- **Required-field emphasis**: Add a subtle accent (dashed outline or color shift) around the weekday selector or interval picker until the user selects a valid value.

## 4. Navigation & Global Feedback

- **Footer guidance**: Tie the enabled state of the "Next" button to a caption (“Finish the checklist above to continue”) so users know why it’s disabled.
- **Visual stepper**: Add a top-of-screen progress chip (“Step 2 of 4: Questions”) with checkmarks on completed stages.
- **Micro-success moments**: Fire a gentle success haptic and lightweight toast (“Questions ready—nice work!”) when a step crosses the completion threshold.
- **Consistent iconography**: Standardize completion colors and symbols across the wizard to build user trust and recognition.

---

### Next Steps

- These opportunities can be explored independently. For each, define acceptance criteria, assess implementation scope, and validate via quick usability checks before rolling into the production flow.
