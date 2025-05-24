<!-- ---
!-- Timestamp: 2025-05-24 14:33:43
!-- Author: ywatanabe
!-- File: /home/ywatanabe/.dotfiles/.claude/to_claude/guidelines/guidelines-programming-Bug-Report-Rules.md
!-- --- -->

# Local Bug Report Rules

## Locations
- Bug report MUST be written as:
  `./project_management/bug_reports/bug-report-<title>.md`
- Bug report MUST be as much simple as possible
- Once solved, bug reports MUST be moved to:
  `./project_management/bug_reports/solved/bug-report-<title>.md`

## How to solve bug reports
1. Think potential causes and make a plan to troubleshoot
   2. Identify the root cause with simple temporal testing
   3. If route cause is not identified, THINK MORE DEEPLY and restart from step 1.
4. List your opinions, priorities, and reasons
5. Make a plan to fix the problem
6. If fixation will be simple, just fix there
7. Otherwise, create a dedicated `feature/bug-fix-<title>` feature branch from
8. Once bug report is solved, merge the `feature/bug-fix-<title>` branch back to the original branch

## When solving problem is difficult
Consider reverting to the latest commit which did not raise the problem. We sometimes make mistakes but retry with experiences and updated ideas.

## Format
- Add progress section in `./project_management/bug_reports/bug-report-<title>.md` as follows:
  ```
  ## Bug Fix Progress
  - [x] Identify root cause
  - [ ] Fix XXX
  ```


- Once merge succeeded, delete the merged feature branch

<!-- EOF -->