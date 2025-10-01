# The Resistance - Enhanced

A digital implementation of the popular social deduction board game "The Resistance" built with Flutter. This app facilitates gameplay for 5-10 players using a single device that gets passed around.

## About The Resistance

The Resistance is a social deduction game where players are divided into two teams:
- **Resistance Members** (good guys) - Try to complete 3 missions successfully
- **Spies** (bad guys) - Try to sabotage 3 missions to fail

The key challenge is that spies know who each other are, but resistance members don't know who the spies are!

## Game Features

### Core Gameplay
- **Player Management**: Support for 5-10 players with automatic role assignment
- **Secret Role Reveals**: Private role distribution where only you see your role
- **Mission System**: 5 missions with varying team sizes based on player count
- **Team Selection**: Leaders propose teams with group voting
- **Secret Mission Voting**: Team members secretly vote on mission success/failure
- **Ultimate Leader Mode**: Activated after 4 failed team proposals

### Enhanced Features
- **Recent Players**: Automatically saves and suggests recently used player names
- **Visual Progress Tracking**: Clear mission progress indicators
- **Dynamic Leadership**: Random leader selection with tracking to ensure everyone gets a turn
- **Proposal Tracking**: Monitors failed team proposals leading to ultimate leader scenarios
- **Role Verification**: Spies can see other spy names during role reveal

## How to Play

1. **Setup**: Add 5-10 player names and start the game
2. **Role Reveal**: Pass device to each player to privately see their role
3. **Mission Phase**:
   - Current leader selects a team
   - All players vote to approve/reject the team
   - If approved, team members secretly vote on mission outcome
   - Mission succeeds only if all votes are "success"
4. **Repeat**: Continue until one side wins 3 missions

## Technical Details

### Built With
- **Flutter** - Cross-platform mobile framework
- **Dart** - Programming language
- **shared_preferences** - For persistent storage of recent players

### Game Logic
- Automatic spy count calculation based on player count (2-4 spies)
- Team size requirements per mission based on official rules
- Secure role assignment with proper shuffling
- Mission voting validation (spies can vote fail, resistance always succeeds)

### App Structure
- `GameSetupScreen` - Player registration and game initialization
- `RoleRevealScreen` - Secret role distribution
- `MissionScreen` - Team selection and proposal
- `VotingScreen` - Team approval voting
- `MissionExecutionScreen` - Secret mission voting
- `MissionResultScreen` - Mission outcome display
- `GameEndScreen` - Final results and role reveals

## Getting Started

### Prerequisites
- Flutter SDK installed
- Android Studio or VS Code with Flutter extension
- Physical device or emulator

### Installation
1. Clone this repository: `git clone <repository-url>`
2. Navigate to project: `cd resistance_game`
3. Install dependencies: `flutter pub get`
4. Run the app: `flutter run`

### Quick Start
```bash
git clone <repository-url>
cd resistance_game
flutter pub get && flutter run
```

### Dependencies
- `flutter` - SDK framework
- `shared_preferences: ^2.2.2` - Local data persistence
- `cupertino_icons: ^1.0.8` - iOS-style icons

## Game Rules Summary

### Victory Conditions
- **Resistance wins**: Complete 3 missions successfully
- **Spies win**: Cause 3 missions to fail

### Team Sizes (by player count)
- 5 players: [2,3,2,3,3] team sizes, 2 spies
- 6 players: [2,3,4,3,4] team sizes, 2 spies
- 7 players: [2,3,3,4,4] team sizes, 3 spies
- 8-10 players: [3,4,4,5,5] team sizes, 3-4 spies

### Special Rules
- Missions fail if ANY team member votes "fail"
- Only spies can cause missions to fail
- After 4 failed team proposals, current leader becomes "Ultimate Leader" with final say
- Spies know each other's identities, resistance members don't

Perfect for game nights, parties, or any gathering where you want to test your deduction skills!
