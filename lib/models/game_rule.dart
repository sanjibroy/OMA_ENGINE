enum ConditionOp { and, or }

enum TriggerCategory { input, player, enemy, game }
enum ActionCategory { player, enemy, world, game, audio, effects }

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
  onTimer,
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
        TriggerType.onTimer => 'Timer (repeating)',
      };

  TriggerCategory get category => switch (this) {
        TriggerType.keyUpPressed ||
        TriggerType.keyDownPressed ||
        TriggerType.keyLeftPressed ||
        TriggerType.keyRightPressed ||
        TriggerType.keySpacePressed =>
          TriggerCategory.input,
        TriggerType.playerTouchesEnemy ||
        TriggerType.playerTouchesCollectible ||
        TriggerType.playerTouchesDoor ||
        TriggerType.playerTouchesNpc ||
        TriggerType.playerHealthZero =>
          TriggerCategory.player,
        TriggerType.enemyNearPlayer => TriggerCategory.enemy,
        TriggerType.gameStart || TriggerType.onTimer => TriggerCategory.game,
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

class RuleCondition {
  TriggerType trigger;
  bool negate;

  RuleCondition({required this.trigger, this.negate = false});

  Map<String, dynamic> toJson() => {
        'trigger': trigger.index,
        'negate': negate,
      };

  factory RuleCondition.fromJson(Map<String, dynamic> json) => RuleCondition(
        trigger: TriggerType.values[json['trigger'] as int],
        negate: json['negate'] as bool? ?? false,
      );
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
  // Transform
  setScale,
  setRotation,
  adjustRotation,
  flipH,
  flipV,
  // Visibility
  hideObject,
  showObject,
  // Effects
  fadeIn,
  fadeOut,
  setAlpha,
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
        ActionType.setScale => 'Set scale',
        ActionType.setRotation => 'Set rotation',
        ActionType.adjustRotation => 'Adjust rotation (relative)',
        ActionType.flipH => 'Flip horizontally',
        ActionType.flipV => 'Flip vertically',
        ActionType.hideObject => 'Hide object',
        ActionType.showObject => 'Show object',
        ActionType.fadeIn => 'Fade in',
        ActionType.fadeOut => 'Fade out',
        ActionType.setAlpha => 'Set opacity',
      };

  ActionCategory get category => switch (this) {
        ActionType.movePlayer ||
        ActionType.adjustHealth ||
        ActionType.adjustScore =>
          ActionCategory.player,
        ActionType.enemyChasePlayer ||
        ActionType.enemyPatrol ||
        ActionType.enemyStopMoving =>
          ActionCategory.enemy,
        ActionType.destroyTriggerObject ||
        ActionType.showMessage ||
        ActionType.loadMap =>
          ActionCategory.world,
        ActionType.gameOver || ActionType.winGame => ActionCategory.game,
        ActionType.playMusic ||
        ActionType.playSfx ||
        ActionType.stopMusic =>
          ActionCategory.audio,
        ActionType.setScale ||
        ActionType.setRotation ||
        ActionType.adjustRotation ||
        ActionType.flipH ||
        ActionType.flipV ||
        ActionType.hideObject ||
        ActionType.showObject =>
          ActionCategory.world,
        ActionType.fadeIn ||
        ActionType.fadeOut ||
        ActionType.setAlpha =>
          ActionCategory.effects,
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
        ActionType.setScale => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('value', ActionParamType.text, label: 'Scale', hint: '1.5'),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
        ActionType.setRotation => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('angle', ActionParamType.number, label: 'Angle °', hint: '90'),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
        ActionType.adjustRotation => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('angle', ActionParamType.number, label: 'Δ Angle °', hint: '10'),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
        ActionType.flipH => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
        ActionType.flipV => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
        ActionType.hideObject => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
        ActionType.showObject => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
        ActionType.fadeIn => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('duration', ActionParamType.text, label: 'Duration (s)', hint: '1.0'),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
        ActionType.fadeOut => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('duration', ActionParamType.text, label: 'Duration (s)', hint: '1.0'),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
        ActionType.setAlpha => [
          ActionParam('target', ActionParamType.choice, label: 'Target',
              choices: {'player': 'Player', 'trigger': 'Trigger Object', 'enemies': 'All Enemies', 'named': 'Object by Name', 'tag': 'Objects by Tag'}),
          ActionParam('value', ActionParamType.text, label: 'Opacity', hint: '0.5  (0 – 1)'),
          ActionParam('objectName', ActionParamType.text, label: 'Object name', hint: 'myObject'),
          ActionParam('tag', ActionParamType.text, label: 'Tag', hint: 'breakable'),
        ],
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
        ActionType.setScale => () {
            final t = p['target'] as String? ?? 'player';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            return 'Scale ${p['value'] ?? '1.0'}× ($who)';
          }(),
        ActionType.setRotation => () {
            final t = p['target'] as String? ?? 'player';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            return 'Rotate ${p['angle'] ?? 0}° ($who)';
          }(),
        ActionType.adjustRotation => () {
            final t = p['target'] as String? ?? 'player';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            final a = p['angle'] ?? 0;
            return 'Rotate ${a >= 0 ? '+' : ''}$a° ($who)';
          }(),
        ActionType.flipH => () {
            final t = p['target'] as String? ?? 'player';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            return 'Flip H ($who)';
          }(),
        ActionType.flipV => () {
            final t = p['target'] as String? ?? 'player';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            return 'Flip V ($who)';
          }(),
        ActionType.hideObject => () {
            final t = p['target'] as String? ?? 'trigger';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            return 'Hide $who';
          }(),
        ActionType.showObject => () {
            final t = p['target'] as String? ?? 'trigger';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            return 'Show $who';
          }(),
        ActionType.fadeIn => () {
            final t = p['target'] as String? ?? 'trigger';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            return 'Fade in $who (${p['duration'] ?? '1.0'}s)';
          }(),
        ActionType.fadeOut => () {
            final t = p['target'] as String? ?? 'trigger';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            return 'Fade out $who (${p['duration'] ?? '1.0'}s)';
          }(),
        ActionType.setAlpha => () {
            final t = p['target'] as String? ?? 'player';
            final who = t == 'named' ? '"${p['objectName'] ?? ''}"' : t == 'tag' ? '#${p['tag'] ?? ''}' : t;
            return 'Opacity ${p['value'] ?? '1.0'} ($who)';
          }(),
      };
}

enum ActionParamType { number, text, choice }

class ActionParam {
  final String key;
  final ActionParamType type;
  final String label;
  final String hint;
  /// For [ActionParamType.choice]: stored-value → display-label (insertion order preserved).
  final Map<String, String>? choices;
  const ActionParam(this.key, this.type,
      {required this.label, this.hint = '', this.choices});
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
  List<RuleCondition> conditions;
  List<ConditionOp> operators; // length = conditions.length - 1
  List<RuleAction> actions;
  bool enabled;
  Map<String, dynamic> triggerParams; // extra params for the primary trigger (e.g. interval)

  GameRule({
    required this.name,
    required this.conditions,
    List<ConditionOp>? operators,
    List<RuleAction>? actions,
    bool? enabled,
    String? id,
    Map<String, dynamic>? triggerParams,
  })  : id = id ?? 'rule_${DateTime.now().microsecondsSinceEpoch}',
        operators = operators ?? [],
        actions = actions ?? [],
        enabled = enabled ?? true,
        triggerParams = triggerParams ?? {};

  /// Primary trigger — the event that buckets this rule. Backward-compat getter.
  TriggerType get trigger => conditions.first.trigger;

  String get summary {
    if (actions.isEmpty) return 'No actions';
    return actions.map((a) => a.type.summarize(a.params)).join(', ');
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'name': name,
      'conditions': conditions.map((c) => c.toJson()).toList(),
      'operators': operators.map((o) => o.index).toList(),
      'actions': actions.map((a) => a.toJson()).toList(),
      'enabled': enabled,
    };
    if (triggerParams.isNotEmpty) map['triggerParams'] = triggerParams;
    return map;
  }

  factory GameRule.fromJson(Map<String, dynamic> json) {
    // Migrate old single-trigger format
    List<RuleCondition> conditions;
    List<ConditionOp> operators;
    if (json.containsKey('conditions')) {
      conditions = (json['conditions'] as List)
          .map((c) => RuleCondition.fromJson(c as Map<String, dynamic>))
          .toList();
      operators = (json['operators'] as List? ?? [])
          .map((o) => ConditionOp.values[o as int])
          .toList();
    } else {
      conditions = [RuleCondition(trigger: TriggerType.values[json['trigger'] as int])];
      operators = [];
    }
    return GameRule(
      id: json['id'] as String,
      name: json['name'] as String,
      conditions: conditions,
      operators: operators,
      actions: (json['actions'] as List)
          .map((a) => RuleAction.fromJson(a as Map<String, dynamic>))
          .toList(),
      enabled: json['enabled'] as bool? ?? true,
      triggerParams: Map<String, dynamic>.from(json['triggerParams'] as Map? ?? {}),
    );
  }
}
