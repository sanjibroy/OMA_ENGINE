class ProjectMap {
  final String id;
  String name;
  String fileName; // relative path within project folder, e.g. "maps/level_1.json"

  ProjectMap({required this.id, required this.name, required this.fileName});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'fileName': fileName,
      };

  factory ProjectMap.fromJson(Map<String, dynamic> j) => ProjectMap(
        id: j['id'] as String,
        name: j['name'] as String,
        fileName: j['fileName'] as String,
      );
}

class GameProject {
  String name;
  String startMapId;
  int windowWidth;
  int windowHeight;
  int viewportWidth;   // virtual viewport W (0 = fullscreen)
  int viewportHeight;  // virtual viewport H (0 = fullscreen)
  bool hudAtBottom; // HUD strip position in the exported game + editor preview
  String androidOrientation; // 'landscape' or 'portrait'
  List<ProjectMap> maps;

  // Player settings
  double playerSpeed;
  int playerHealth;
  int playerLives;

  // Reserved for future features — kept as empty maps until editors are built
  Map<String, String> musicPaths; // trackName → relative path
  Map<String, String> sfxPaths;   // sfxName   → relative path
  Map<String, String> fontPaths;  // fontName  → relative path

  GameProject({
    this.name = 'Untitled Game',
    this.startMapId = '',
    this.windowWidth = 1280,
    this.windowHeight = 720,
    this.viewportWidth = 0,
    this.viewportHeight = 0,
    this.hudAtBottom = true,
    this.androidOrientation = 'landscape',
    this.playerSpeed = 4.0,
    this.playerHealth = 6,
    this.playerLives = 3,
    List<ProjectMap>? maps,
    Map<String, String>? musicPaths,
    Map<String, String>? sfxPaths,
    Map<String, String>? fontPaths,
  })  : maps = maps ?? [],
        musicPaths = musicPaths ?? {},
        sfxPaths = sfxPaths ?? {},
        fontPaths = fontPaths ?? {};

  ProjectMap? get startMap => maps.isEmpty
      ? null
      : maps.firstWhere((m) => m.id == startMapId,
          orElse: () => maps.first);

  Map<String, dynamic> toJson() => {
        'name': name,
        'startMapId': startMapId,
        'windowWidth': windowWidth,
        'windowHeight': windowHeight,
        'viewportWidth': viewportWidth,
        'viewportHeight': viewportHeight,
        'hudAtBottom': hudAtBottom,
        'androidOrientation': androidOrientation,
        'playerSpeed': playerSpeed,
        'playerHealth': playerHealth,
        'playerLives': playerLives,
        'maps': maps.map((m) => m.toJson()).toList(),
        'musicPaths': musicPaths,
        'sfxPaths': sfxPaths,
        'fontPaths': fontPaths,
      };

  factory GameProject.fromJson(Map<String, dynamic> j) => GameProject(
        name: j['name'] as String? ?? 'Untitled Game',
        startMapId: j['startMapId'] as String? ?? '',
        windowWidth: j['windowWidth'] as int? ?? 1280,
        windowHeight: j['windowHeight'] as int? ?? 720,
        viewportWidth: j['viewportWidth'] as int? ?? 0,
        viewportHeight: j['viewportHeight'] as int? ?? 0,
        hudAtBottom: j['hudAtBottom'] as bool? ?? true,
        androidOrientation: j['androidOrientation'] as String? ?? 'landscape',
        playerSpeed: (j['playerSpeed'] as num?)?.toDouble() ?? 4.0,
        playerHealth: j['playerHealth'] as int? ?? 6,
        playerLives: j['playerLives'] as int? ?? 3,
        maps: (j['maps'] as List? ?? [])
            .map((m) => ProjectMap.fromJson(m as Map<String, dynamic>))
            .toList(),
        musicPaths:
            Map<String, String>.from(j['musicPaths'] as Map? ?? {}),
        sfxPaths: Map<String, String>.from(j['sfxPaths'] as Map? ?? {}),
        fontPaths: Map<String, String>.from(j['fontPaths'] as Map? ?? {}),
      );
}
