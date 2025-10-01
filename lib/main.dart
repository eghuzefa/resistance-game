import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(ResistanceApp());
}

class ResistanceApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Resistance - Enhanced',
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.black87,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: GameSetupScreen(),
    );
  }
}

// Game Data Models (like your ML model classes)
enum Role { resistance, spy }
enum GamePhase { setup, roleReveal, missionSelection, voting, missionExecution, gameEnd }

class Player {
  final String name;
  final Role role;
  
  Player({required this.name, required this.role});
}

class GameState {
  List<Player> players = [];
  GamePhase currentPhase = GamePhase.setup;
  int currentMission = 1;
  List<bool> missionResults = []; // true = success, false = fail
  int currentLeader = 0;
  List<Player> selectedTeam = [];
  List<int> usedLeaders = []; // Track who has been leader
  int proposalAttempts = 0; // Track failed proposals
  bool ultimateLeaderMode = false;
  
  // Game configuration based on player count
  Map<int, List<int>> get missionTeamSizes => {
    5: [2, 3, 2, 3, 3],
    6: [2, 3, 4, 3, 4],
    7: [2, 3, 3, 4, 4],
    8: [3, 4, 4, 5, 5],
    9: [3, 4, 4, 5, 5],
    10: [3, 4, 4, 5, 5],
  };
  
  Map<int, int> get spyCount => {
    5: 2, 6: 2, 7: 3, 8: 3, 9: 3, 10: 4
  };
  
  bool get gameEnded => missionResults.length >= 5 || 
    missionResults.where((result) => result).length >= 3 ||
    missionResults.where((result) => !result).length >= 3;
    
  void selectRandomLeader() {
    List<int> availableLeaders = [];
    for (int i = 0; i < players.length; i++) {
      if (!usedLeaders.contains(i)) {
        availableLeaders.add(i);
      }
    }
    
    // If everyone has been leader, reset the list
    if (availableLeaders.isEmpty) {
      usedLeaders.clear();
      availableLeaders = List.generate(players.length, (index) => index);
    }
    
    availableLeaders.shuffle();
    currentLeader = availableLeaders.first;
    usedLeaders.add(currentLeader);
  }
  
  void resetProposalCycle() {
    proposalAttempts = 0;
    ultimateLeaderMode = false;
  }
}

// First Screen: Player Setup
class GameSetupScreen extends StatefulWidget {
  @override
  _GameSetupScreenState createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  final GameState gameState = GameState();
  final TextEditingController nameController = TextEditingController();
  List<String> recentPlayers = [];
  
  @override
  void initState() {
    super.initState();
    loadRecentPlayers();
  }
  
  Future<void> loadRecentPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      recentPlayers = prefs.getStringList('recent_players') ?? [];
    });
  }
  
  Future<void> saveRecentPlayers() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current player names
    List<String> currentNames = gameState.players.map((p) => p.name).toList();
    
    // Combine with existing recent players, remove duplicates
    Set<String> allNames = {...currentNames, ...recentPlayers};
    
    // Keep only the most recent 20 names, prioritizing current game players
    List<String> updatedRecent = [
      ...currentNames,
      ...recentPlayers.where((name) => !currentNames.contains(name))
    ].take(20).toList();
    
    await prefs.setStringList('recent_players', updatedRecent);
  }
  
  void addPlayerFromRecent(String name) {
    if (gameState.players.length < 10) {
      bool nameExists = gameState.players.any((player) => 
        player.name.toLowerCase() == name.toLowerCase());
      
      if (!nameExists) {
        setState(() {
          gameState.players.add(Player(
            name: name, 
            role: Role.resistance
          ));
        });
      }
    }
  }
  
  void addPlayer() {
    String playerName = nameController.text.trim();
    if (playerName.isNotEmpty && gameState.players.length < 10) {
      // Check for duplicate names
      bool nameExists = gameState.players.any((player) => 
        player.name.toLowerCase() == playerName.toLowerCase());
      
      if (nameExists) {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Player name "$playerName" already exists!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      setState(() {
        gameState.players.add(Player(
          name: playerName, 
          role: Role.resistance
        ));
        nameController.clear();
      });
    }
  }
  
  void startGame() async {
    if (gameState.players.length >= 5) {
      // Save recent players before starting
      await saveRecentPlayers();
      
      // Assign roles randomly
      assignRoles();
      // Select first leader randomly
      gameState.selectRandomLeader();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoleRevealScreen(gameState: gameState),
        ),
      );
    }
  }
  
  void assignRoles() {
    List<Player> shuffledPlayers = List.from(gameState.players);
    shuffledPlayers.shuffle();
    
    int spies = gameState.spyCount[gameState.players.length] ?? 2;
    
    gameState.players.clear();
    for (int i = 0; i < shuffledPlayers.length; i++) {
      gameState.players.add(Player(
        name: shuffledPlayers[i].name,
        role: i < spies ? Role.spy : Role.resistance,
      ));
    }
    
    // CRITICAL: Shuffle again after role assignment so reveal order doesn't correlate with roles
    gameState.players.shuffle();
  }
  
  @override
  Widget build(BuildContext context) {
    // Filter out players already added from recent players
    List<String> availableRecentPlayers = recentPlayers
        .where((name) => !gameState.players.any((player) => 
            player.name.toLowerCase() == name.toLowerCase()))
        .toList();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('The Resistance - Enhanced'),
        backgroundColor: Colors.red[800],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Add Players (5-10)',
              style: TextStyle(fontSize: 24, color: Colors.white),
            ),
            SizedBox(height: 20),
            
            // Recent players section
            if (availableRecentPlayers.isNotEmpty) ...[
              Text(
                'Recent Players (tap to add):',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 10),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: availableRecentPlayers.map((name) => 
                  ActionChip(
                    label: Text(name),
                    backgroundColor: Colors.blue[800],
                    labelStyle: TextStyle(color: Colors.white),
                    onPressed: () => addPlayerFromRecent(name),
                  ),
                ).toList(),
              ),
              SizedBox(height: 20),
            ],
            
            // Manual entry
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: nameController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter new player name',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => addPlayer(),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: addPlayer,
                  child: Text('Add'),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // Current players list
            Expanded(
              child: ListView.builder(
                itemCount: gameState.players.length,
                itemBuilder: (context, index) {
                  return Card(
                    color: Colors.grey[800],
                    child: ListTile(
                      title: Text(
                        gameState.players[index].name,
                        style: TextStyle(color: Colors.white),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            gameState.players.removeAt(index);
                          });
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: gameState.players.length >= 5 ? startGame : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              ),
              child: Text(
                'Start Game (${gameState.players.length}/10)',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Role Reveal Screen - Secret role distribution
class RoleRevealScreen extends StatefulWidget {
  final GameState gameState;
  
  RoleRevealScreen({required this.gameState});
  
  @override
  _RoleRevealScreenState createState() => _RoleRevealScreenState();
}

class _RoleRevealScreenState extends State<RoleRevealScreen> {
  int currentPlayerIndex = 0;
  bool roleRevealed = false;
  
  void nextPlayer() {
    setState(() {
      currentPlayerIndex++;
      roleRevealed = false;
    });
  }
  
  void startMissions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MissionScreen(gameState: widget.gameState),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (currentPlayerIndex >= widget.gameState.players.length) {
      // All players have seen their roles
      return Scaffold(
        appBar: AppBar(
          title: Text('Ready to Begin'),
          backgroundColor: Colors.red[800],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'All players know their roles!',
                style: TextStyle(fontSize: 24, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 30),
              Text(
                'Mission Overview:',
                style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                '• Resistance wins by succeeding 3 missions',
                style: TextStyle(fontSize: 16, color: Colors.green),
              ),
              Text(
                '• Spies win by failing 3 missions',
                style: TextStyle(fontSize: 16, color: Colors.red),
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: startMissions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text(
                  'Begin Missions',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    Player currentPlayer = widget.gameState.players[currentPlayerIndex];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Role Reveal (${currentPlayerIndex + 1}/${widget.gameState.players.length})'),
        backgroundColor: Colors.red[800],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${currentPlayer.name}',
                style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 30),
              Text(
                'Tap below to see your role',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              Text(
                '(Make sure others aren\'t looking!)',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              SizedBox(height: 40),
              GestureDetector(
                onTap: () {
                  setState(() {
                    roleRevealed = !roleRevealed;
                  });
                },
                child: Container(
                  width: 300,
                  height: 200,
                  decoration: BoxDecoration(
                    color: roleRevealed 
                      ? (currentPlayer.role == Role.spy ? Colors.red[800] : Colors.blue[800])
                      : Colors.grey[800],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: roleRevealed 
                        ? (currentPlayer.role == Role.spy ? Colors.red : Colors.blue)
                        : Colors.grey,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child: roleRevealed
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              currentPlayer.role == Role.spy ? Icons.visibility_off : Icons.shield,
                              size: 50,
                              color: Colors.white,
                            ),
                            SizedBox(height: 10),
                            Text(
                              currentPlayer.role == Role.spy ? 'SPY' : 'RESISTANCE',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (currentPlayer.role == Role.spy) ...[
                              SizedBox(height: 10),
                              Text(
                                'Other Spies:',
                                style: TextStyle(fontSize: 14, color: Colors.white70),
                              ),
                              ...widget.gameState.players
                                .where((p) => p.role == Role.spy && p.name != currentPlayer.name)
                                .map((spy) => Text(
                                  spy.name,
                                  style: TextStyle(fontSize: 16, color: Colors.white),
                                )),
                            ],
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.help_outline, size: 50, color: Colors.white),
                            SizedBox(height: 10),
                            Text(
                              'TAP TO REVEAL',
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                          ],
                        ),
                  ),
                ),
              ),
              SizedBox(height: 40),
              if (roleRevealed) ...[
                Text(
                  'Tap the card again to hide, then pass device to next player',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: nextPlayer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text(
                    currentPlayerIndex < widget.gameState.players.length - 1 
                      ? 'Next Player' 
                      : 'All Done',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Mission Screen - Team selection and voting
class MissionScreen extends StatefulWidget {
  final GameState gameState;
  
  MissionScreen({required this.gameState});
  
  @override
  _MissionScreenState createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen> {
  List<Player> selectedTeam = [];
  bool teamLocked = false;
  
  Player get currentLeader => widget.gameState.players[widget.gameState.currentLeader];
  int get requiredTeamSize => widget.gameState.missionTeamSizes[widget.gameState.players.length]![widget.gameState.currentMission - 1];
  
  void togglePlayerSelection(Player player) {
    if (teamLocked) return;
    
    setState(() {
      if (selectedTeam.contains(player)) {
        selectedTeam.remove(player);
      } else if (selectedTeam.length < requiredTeamSize) {
        selectedTeam.add(player);
      }
    });
  }
  
  void proposeTeam() {
    setState(() {
      teamLocked = true;
      widget.gameState.selectedTeam = selectedTeam;
    });
  }
  
  void startVoting() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VotingScreen(gameState: widget.gameState),
      ),
    ).then((_) {
      // Reset when coming back from voting
      setState(() {
        teamLocked = false;
        selectedTeam.clear();
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mission ${widget.gameState.currentMission}'),
        backgroundColor: Colors.red[800],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Mission Progress Indicator
            Card(
              color: Colors.grey[900],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Mission Progress',
                      style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(5, (index) {
                        bool isCompleted = index < widget.gameState.missionResults.length;
                        bool isSuccessful = isCompleted ? widget.gameState.missionResults[index] : false;
                        bool isCurrent = index == widget.gameState.currentMission - 1;
                        
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted 
                              ? (isSuccessful ? Colors.blue[600] : Colors.red[600])
                              : Colors.grey[700],
                            border: Border.all(
                              color: isCurrent ? Colors.yellow : Colors.grey[600]!,
                              width: isCurrent ? 3 : 1,
                            ),
                          ),
                          child: Center(
                            child: isCompleted
                              ? Icon(
                                  isSuccessful ? Icons.check : Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                )
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Mission info
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Mission ${widget.gameState.currentMission}',
                      style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.gameState.ultimateLeaderMode ? Icons.gavel : Icons.star,
                          color: widget.gameState.ultimateLeaderMode ? Colors.purple : Colors.yellow,
                        ),
                        SizedBox(width: 5),
                        Text(
                          '${widget.gameState.ultimateLeaderMode ? "Ultimate " : ""}Leader: ${currentLeader.name}',
                          style: TextStyle(
                            fontSize: 18, 
                            color: widget.gameState.ultimateLeaderMode ? Colors.purple : Colors.yellow,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (widget.gameState.ultimateLeaderMode)
                      Text(
                        'Final decision - no voting needed!',
                        style: TextStyle(fontSize: 14, color: Colors.purple),
                      ),
                    SizedBox(height: 5),
                    Text(
                      'Team Size Required: $requiredTeamSize',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      'Selected: ${selectedTeam.length}/$requiredTeamSize',
                      style: TextStyle(fontSize: 16, color: selectedTeam.length == requiredTeamSize ? Colors.green : Colors.orange),
                    ),
                    if (widget.gameState.proposalAttempts > 0)
                      Text(
                        'Proposal attempts: ${widget.gameState.proposalAttempts}/4',
                        style: TextStyle(fontSize: 14, color: Colors.orange),
                      ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 20),
            
            // Player selection
            Expanded(
              child: ListView.builder(
                itemCount: widget.gameState.players.length,
                itemBuilder: (context, index) {
                  Player player = widget.gameState.players[index];
                  bool isSelected = selectedTeam.contains(player);
                  bool isLeader = player == currentLeader;
                  
                  return Card(
                    color: isSelected ? Colors.green[800] : Colors.grey[800],
                    child: ListTile(
                      leading: Icon(
                        isLeader 
                          ? (widget.gameState.ultimateLeaderMode ? Icons.gavel : Icons.star)
                          : (isSelected ? Icons.check_circle : Icons.person),
                        color: isLeader 
                          ? (widget.gameState.ultimateLeaderMode ? Colors.purple : Colors.yellow)
                          : (isSelected ? Colors.green : Colors.white),
                      ),
                      title: Text(
                        player.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isLeader ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: isLeader 
                        ? Text(
                            widget.gameState.ultimateLeaderMode ? 'Ultimate Leader' : 'Leader', 
                            style: TextStyle(color: widget.gameState.ultimateLeaderMode ? Colors.purple : Colors.yellow)
                          ) 
                        : null,
                      onTap: () => togglePlayerSelection(player),
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: 20),
            
            // Action buttons
            if (!teamLocked) ...[
              ElevatedButton(
                onPressed: selectedTeam.length == requiredTeamSize ? proposeTeam : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text(
                  'Propose Team',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ] else ...[
              Text(
                widget.gameState.ultimateLeaderMode 
                  ? 'Ultimate Leader has decided! Team approved automatically.'
                  : 'Team Proposed! All players now vote.',
                style: TextStyle(
                  fontSize: 18, 
                  color: widget.gameState.ultimateLeaderMode ? Colors.purple : Colors.green
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: widget.gameState.ultimateLeaderMode 
                  ? () {
                      // Skip voting, go straight to mission execution
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MissionExecutionScreen(gameState: widget.gameState),
                        ),
                      );
                    }
                  : startVoting,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.gameState.ultimateLeaderMode ? Colors.purple : Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text(
                  widget.gameState.ultimateLeaderMode ? 'Start Mission' : 'Start Voting',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Simple Voting Screen - Approve/Reject buttons
class VotingScreen extends StatefulWidget {
  final GameState gameState;
  
  VotingScreen({required this.gameState});
  
  @override
  _VotingScreenState createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  bool? teamApproved;
  
  void voteApprove() {
    setState(() {
      teamApproved = true;
    });
  }
  
  void voteReject() {
    setState(() {
      teamApproved = false;
    });
  }
  
  void proceedWithResult() {
    if (teamApproved == true) {
      // Team approved - go to mission execution
      widget.gameState.resetProposalCycle();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MissionExecutionScreen(gameState: widget.gameState),
        ),
      );
    } else {
      // Team rejected - increment attempts and go back
      widget.gameState.proposalAttempts++;
      
      if (widget.gameState.proposalAttempts >= 4) {
        // Activate ultimate leader mode
        widget.gameState.ultimateLeaderMode = true;
      } else {
        // Select new random leader
        widget.gameState.selectRandomLeader();
      }
      
      Navigator.pop(context);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Team Voting'),
        backgroundColor: Colors.blue[800],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Proposed Team:',
              style: TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            
            // Show selected team
            Card(
              color: Colors.grey[800],
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: widget.gameState.selectedTeam.map((player) => 
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Text(
                        player.name,
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    )
                  ).toList(),
                ),
              ),
            ),
            
            SizedBox(height: 40),
            
            Text(
              'Does the group approve this team?',
              style: TextStyle(fontSize: 18, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            Text(
              '(Discuss and decide together)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 40),
            
            // Voting buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: voteReject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teamApproved == false ? Colors.red[600] : Colors.red[800],
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.close, size: 30),
                      Text('REJECT', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: voteApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: teamApproved == true ? Colors.green[600] : Colors.green[800],
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.check, size: 30),
                      Text('APPROVE', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 40),
            
            if (teamApproved != null) ...[
              Text(
                teamApproved! ? 'Team APPROVED!' : 'Team REJECTED!',
                style: TextStyle(
                  fontSize: 20, 
                  color: teamApproved! ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: proceedWithResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text(
                  teamApproved! ? 'Start Mission' : 'Select New Leader',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Mission Execution Screen - Secret voting for mission success/failure
class MissionExecutionScreen extends StatefulWidget {
  final GameState gameState;
  
  MissionExecutionScreen({required this.gameState});
  
  @override
  _MissionExecutionScreenState createState() => _MissionExecutionScreenState();
}

class _MissionExecutionScreenState extends State<MissionExecutionScreen> {
  int currentVoterIndex = 0;
  List<bool> missionVotes = []; // true = success, false = fail
  bool? currentVote;
  bool showPassScreen = true; // Start with pass screen for first voter
  
  Player get currentVoter => widget.gameState.selectedTeam[currentVoterIndex];
  bool get isCurrentVoterSpy => currentVoter.role == Role.spy;
  
  void submitVote(bool vote) {
    // Record the vote (for spies, false means fail; for resistance, always true regardless of button pressed)
    missionVotes.add(vote);
    
    if (currentVoterIndex < widget.gameState.selectedTeam.length - 1) {
      // More voters remaining - show pass screen for next voter
      setState(() {
        currentVoterIndex++;
        showPassScreen = true;
      });
    } else {
      // All votes collected, show results
      showMissionResults();
    }
  }
  
  void proceedToVoting() {
    setState(() {
      showPassScreen = false;
      currentVote = null;
    });
  }
  
  void showMissionResults() {
    bool missionSucceeded = !missionVotes.contains(false); // Mission fails if any false votes
    widget.gameState.missionResults.add(missionSucceeded);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MissionResultScreen(
          gameState: widget.gameState,
          missionSucceeded: missionSucceeded,
          failVotes: missionVotes.where((vote) => !vote).length,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (showPassScreen) {
      // Show pass phone screen
      Player targetPlayer = widget.gameState.selectedTeam[currentVoterIndex];
      
      return Scaffold(
        appBar: AppBar(
          title: Text('Mission ${widget.gameState.currentMission} - Execution'),
          backgroundColor: Colors.green[800],
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.phone_android,
                  size: 80,
                  color: Colors.blue,
                ),
                SizedBox(height: 30),
                
                Text(
                  'Pass the phone to',
                  style: TextStyle(fontSize: 20, color: Colors.grey),
                ),
                SizedBox(height: 10),
                
                Text(
                  targetPlayer.name,
                  style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                
                SizedBox(height: 20),
                
                Text(
                  'Voter ${currentVoterIndex + 1} of ${widget.gameState.selectedTeam.length}',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                
                SizedBox(height: 30),
                
                Text(
                  'Make sure ${targetPlayer.name} is ready to vote privately',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                
                SizedBox(height: 40),
                
                ElevatedButton(
                  onPressed: proceedToVoting,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  ),
                  child: Text(
                    'Ready to Vote',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Regular voting screen
    return Scaffold(
      appBar: AppBar(
        title: Text('Mission ${widget.gameState.currentMission} - Execution'),
        backgroundColor: Colors.green[800],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Progress indicator
              Text(
                'Voter ${currentVoterIndex + 1} of ${widget.gameState.selectedTeam.length}',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 20),
              
              // Current voter name
              Text(
                currentVoter.name,
                style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 30),
              
              Text(
                'Choose your action for this mission',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              Text(
                '(Make sure others aren\'t looking!)',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              SizedBox(height: 40),
              
              // Voting buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Success button (always available)
                  ElevatedButton(
                    onPressed: () => submitVote(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      minimumSize: Size(120, 80),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle, size: 30),
                        SizedBox(height: 5),
                        Text('SUCCESS', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                  
                  // Fail button (always visible, but only works for spies)
                  ElevatedButton(
                    onPressed: () => submitVote(isCurrentVoterSpy ? false : true), // Resistance gets success even if they press fail
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      minimumSize: Size(120, 80),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cancel, size: 30),
                        SizedBox(height: 5),
                        Text('FAIL', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 30),
              
              Text(
                'Choose your action for this mission',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Mission Result Screen
class MissionResultScreen extends StatelessWidget {
  final GameState gameState;
  final bool missionSucceeded;
  final int failVotes;
  
  MissionResultScreen({
    required this.gameState,
    required this.missionSucceeded,
    required this.failVotes,
  });
  
  void nextMission(BuildContext context) {
    if (gameState.gameEnded) {
      // Game over, show final results
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameEndScreen(gameState: gameState),
        ),
      );
    } else {
      // Continue to next mission
      gameState.currentMission++;
      gameState.resetProposalCycle();
      gameState.selectRandomLeader();
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MissionScreen(gameState: gameState),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    int resistanceWins = gameState.missionResults.where((result) => result).length;
    int spyWins = gameState.missionResults.where((result) => !result).length;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Mission ${gameState.currentMission} Results'),
        backgroundColor: missionSucceeded ? Colors.green[800] : Colors.red[800],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mission result
              Icon(
                missionSucceeded ? Icons.check_circle : Icons.cancel,
                size: 100,
                color: missionSucceeded ? Colors.green : Colors.red,
              ),
              SizedBox(height: 20),
              
              Text(
                missionSucceeded ? 'MISSION SUCCESS!' : 'MISSION FAILED!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: missionSucceeded ? Colors.green : Colors.red,
                ),
              ),
              
              SizedBox(height: 20),
              
              if (failVotes > 0)
                Text(
                  '$failVotes FAIL vote(s) submitted',
                  style: TextStyle(fontSize: 16, color: Colors.orange),
                ),
              
              SizedBox(height: 40),
              
              // Mission score board
              Card(
                color: Colors.grey[800],
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Score',
                        style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.shield, color: Colors.blue, size: 30),
                              Text('Resistance', style: TextStyle(color: Colors.blue)),
                              Text('$resistanceWins', style: TextStyle(fontSize: 24, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.visibility_off, color: Colors.red, size: 30),
                              Text('Spies', style: TextStyle(color: Colors.red)),
                              Text('$spyWins', style: TextStyle(fontSize: 24, color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: () => nextMission(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: gameState.gameEnded ? Colors.purple : Colors.blue,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text(
                  gameState.gameEnded ? 'View Final Results' : 'Next Mission',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Game End Screen
class GameEndScreen extends StatelessWidget {
  final GameState gameState;
  
  GameEndScreen({required this.gameState});
  
  @override
  Widget build(BuildContext context) {
    int resistanceWins = gameState.missionResults.where((result) => result).length;
    int spyWins = gameState.missionResults.where((result) => !result).length;
    bool resistanceWon = resistanceWins >= 3;
    
    List<Player> spies = gameState.players.where((player) => player.role == Role.spy).toList();
    List<Player> resistance = gameState.players.where((player) => player.role == Role.resistance).toList();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Game Over'),
        backgroundColor: resistanceWon ? Colors.blue[800] : Colors.red[800],
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                resistanceWon ? Icons.shield : Icons.visibility_off,
                size: 100,
                color: resistanceWon ? Colors.blue : Colors.red,
              ),
              SizedBox(height: 20),
              
              Text(
                resistanceWon ? 'RESISTANCE WINS!' : 'SPIES WIN!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: resistanceWon ? Colors.blue : Colors.red,
                ),
              ),
              
              SizedBox(height: 20),
              
              Text(
                'Final Score: $resistanceWins - $spyWins',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
              
              SizedBox(height: 40),
              
              // Role Reveals
              Card(
                color: Colors.grey[800],
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        'Player Roles Revealed',
                        style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 20),
                      
                      // Resistance Members
                      Row(
                        children: [
                          Icon(Icons.shield, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Resistance:',
                            style: TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ...resistance.map((player) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          player.name,
                          style: TextStyle(fontSize: 16, color: Colors.blue),
                        ),
                      )),
                      
                      SizedBox(height: 20),
                      
                      // Spy Members
                      Row(
                        children: [
                          Icon(Icons.visibility_off, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Spies:',
                            style: TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      ...spies.map((player) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          player.name,
                          style: TextStyle(fontSize: 16, color: Colors.red),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => GameSetupScreen()),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
                child: Text(
                  'New Game',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}