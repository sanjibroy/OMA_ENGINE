enum TriggerType {
  // Input
  keyUpPressed,
  keyDownPressed,
  keyLeftPressed,
  keyRightPressed,
  keySpacePressed,
  // Proximity / collision
  playerTouchesEnemy,
  playerTouchesCollectible,
  playerTouchesDoor,
  playerTouchesNpc,
  enemyNearPlayer,
  // State
  playerHealthZero,
  gameStart,
}

extension TriggerTypeExtension on TriggerType {
  String get label => switch (this) {
        TriggerType.keyUpPressed => 'Key Up pressed (↑ / W)',
        TriggerType.keyDownPressed => 'Key Down pressed (↓ / S)',
        TriggerType.keyLeftPressed => 'Key Left pressed (← / A)',
        TriggerType.keyRightPressed => 'Key Right pressed (→ / D)',
        TriggerType.keySpacePressed => 'Key Space pressed',
        TriggerType.playerTouchesEnemy => 'Player touches Enemy',
        TriggerType.playerTouchesCollectible => 'Player touches Collectible',
        TriggerType.playerTouchesDoor => 'Player touches Door',
        TriggerType.playerTouchesNpc => 'Player talks to NPC',
        TriggerType.enemyNearPlayer => 'Enemy is near Player',
        TriggerType.playerHealthZero => 'Player health reaches 0',
        TriggerType.gameStart => 'Game starts',
      };

  /// True for triggers that fire every frame (need continuous polling).
  bool get isContinuous => switch (this) {
        TriggerType.keyUpPressed ||
        TriggerType.keyDownPressed ||
        TriggerType.keyLeftPressed ||
        TriggerType.keyRightPressed ||
        TriggerType.keySpacePressed ||
        TriggerType.enemyNearPlayer =>
          true,
        _ => false,
      };
}

enum ActionType {
  // Movement
  movePlayer,
  enemyChasePlayer,
  enemyPatrol,
  enemyStopMoving,
  // Game state
  adjustHealth,
  adjustScore,
  destroyTriggerObject,
  showMessage,
  loadMap,
  gameOver,
  winGame,
  // Audio
  playMusic,
  playSfx,
  stopMusic,
}

extension ActionTypeExtension on ActionType {
  String get label => switch (this) {
        ActionType.movePlayer => 'Move player',
        ActionType.enemyChasePlayer => 'Enemy chases player',
        ActionType.enemyPatrol => 'Enemy patrols (back and forth)',
        ActionType.enemyStopMoving => 'Enemy stops moving',
        ActionType.adjustHealth => 'Adjust player health',
        ActionType.adjustScore => 'Adjust score',
        ActionType.destroyTriggerObject => 'Destroy trigger object',
        ActionType.showMessage => 'Show message',
        ActionType.loadMap => 'Load map',
        ActionType.gameOver => 'Game over',
        ActionType.winGame => 'Win game',
        ActionType.playMusic => 'Play music track',
        ActionType.playSfx => 'Play sound effect',
        ActionType.stopMusic => 'Stop music',
      };

  /// Parameter keys this action expects.
  List<ActionParam> get params => switch (this) {
        ActionType.movePlayer => [
            ActionParam('speed', ActionParamType.number,
                label: 'Speed', hint: '3  (tiles/sec)'),
          ],
        ActionType.enemyChasePlayer => [
            ActionParam('speed', ActionParamType.number,
                label: 'Speed', hint: '2  (tiles/sec)'),
            ActionParam('range', ActionParamType.number,
                label: 'Detect range', hint: '5  (tiles)'),
          ],
        ActionType.enemyPatrol => [
            ActionParam('speed', ActionParamType.number,
                label: 'Speed', hint: '2  (tiles/sec)'),
            ActionParam('distance', ActionParamType.number,
                label: 'Distance', hint: '4  (tiles)'),
          ],
        ActionType.enemyStopMoving => [],
        ActionType.adjustHealth =>
          [ActionParam('value', ActionParamType.number, label: 'Amount', hint: '-10')],
        ActionType.adjustScore =>
          [ActionParam('value', ActionParamType.number, label: 'Amount', hint: '100')],
        ActionType.showMessage =>
          [ActionParam('text', ActionParamType.text, label: 'Message', hint: 'Hello!')],
        ActionType.loadMap =>
          [ActionParam('mapName', ActionParamType.text, label: 'Map name', hint: 'level_2')],
        ActionType.destroyTriggerObject => [],
        ActionType.gameOver => [],
        ActionType.winGame => [],
        ActionType.playMusic =>
          [ActionParam('trackName', ActionParamType.text, label: 'Track name', hint: 'theme')],
        ActionType.playSfx =>
          [ActionParam('sfxName', ActionParamType.text, label: 'Sound name', hint: 'coin')],
        ActionType.stopMusic => [],
      };

  String summarize(Map<String, dynamic> p) => switch (this) {
        ActionType.movePlayer => () {
            final s = p['speed'] ?? 3;
            return 'Move player (speed $s)';
          }(),
        ActionType.enemyChasePlayer => () {
            final s = p['speed'] ?? 2;
            final r = p['range'] ?? 5;
            return 'Chase player (spd $s, range $r)';
          }(),
        ActionType.enemyPatrol => () {
            final s = p['speed'] ?? 2;
            final d = p['distance'] ?? 4;
            return 'Patrol (spd $s, dist $d)';
          }(),
        ActionType.enemyStopMoving => 'Stop moving',
        ActionType.adjustHealth => () {
            final v = p['value'] ?? 0;
            return 'Health ${v >= 0 ? '+' : ''}$v';
          }(),
        ActionType.adjustScore => () {
            final v = p['value'] ?? 0;
            return 'Score ${v >= 0 ? '+' : ''}$v';
          }(),
        ActionType.showMessage => 'Show: "${p['text'] ?? ''}"',
        ActionType.loadMap => 'Load map: ${p['mapName'] ?? ''}',
        ActionType.destroyTriggerObject => 'Destroy trigger object',
        ActionType.gameOver => 'Game over',
        ActionType.winGame => 'Win game',
        ActionType.playMusic => 'Play music: ${p['trackName'] ?? ''}',
        ActionType.playSfx => 'Play sfx: ${p['sfxName'] ?? ''}',
        ActionType.stopMusic => 'Stop music',
      };
}

enum ActionParamType { number, text }

class ActionParam {
  final String key;
  final ActionParamType type;
  final String label;
  final String hint;
  const ActionParam(this.key, this.type, {required this.label, this.hint = ''});
}

class RuleAction {
  ActionType type;
  Map<String, dynamic> params;

  RuleAction({required this.type, Map<String, dynamic>? params})
      : params = params ?? {};

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'params': params,
      };

  factory RuleAction.fromJson(Map<String, dynamic> json) => RuleAction(
        type: ActionType.values[json['type'] as int],
        params: Map<String, dynamic>.from(json['params'] as Map? ?? {}),
      );
}

class GameRule {
  String id;
  String name;
  TriggerType trigger;
  List<RuleAction> actions;
  bool enabled;

  GameRule({
    required this.name,
    required this.trigger,
    List<RuleAction>? actions,
    bool? enabled,
    String? id,
  })  : id = id ?? 'rule_${DateTime.now().microsecondsSinceEpoch}',
        actions = actions ?? [],
        enabled = enabled ?? true;

  String get summary {
    if (actions.isEmpty) return 'No actions';
    return actions.map((a) => a.type.summarize(a.params)).join(', ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trigger': trigger.index,
        'actions': actions.map((a) => a.toJson()).toList(),
        'enabled': enabled,
      };

  factory GameRule.fromJson(Map<String, dynamic> json) => GameRule(
        id: json['id'] as String,
        name: json['name'] as String,
        trigger: TriggerType.values[json['trigger'] as int],
        actions: (json['actions'] as List)
            .map((a) => RuleAction.fromJson(a as Map<String, dynamic>))
            .toList(),
        enabled: json['enabled'] as bool? ?? true,
      );
}
