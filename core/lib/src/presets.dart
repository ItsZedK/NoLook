import 'block.dart';
import 'i18n.dart';
import 'state.dart';

class Preset {
  const Preset({
    required this.id,
    required this.name,
    required this.description,
    required this.iconText,
    required this.color,
    required this.keywords,
    this.spoilerWords = const [],
    this.topicWords = const [],
    required this.sites,
    this.sentence = '',
  });

  final String id;
  final String name;
  final String description;
  final String iconText;
  final BlockColor color;
  final List<String> keywords;
  final List<String> spoilerWords;
  final List<String> topicWords;
  final List<String> sites;
  final String sentence;

  int get wordCount => keywords.length + spoilerWords.length + topicWords.length;

  /// what the block is missing
  ({List<String> keywords, List<String> spoilerWords, List<String> topicWords, List<String> sites}) missingFrom(Block b) {
    List<String> missing(List<String> want, List<String> have) {
      final h = {for (final x in have) x.toLowerCase()};
      return [for (final x in want) if (!h.contains(x.toLowerCase())) x];
    }

    return (
      keywords: missing(keywords, b.keywords),
      spoilerWords: missing(spoilerWords, b.spoilerWords),
      topicWords: missing(topicWords, b.topicWords),
      sites: missing(sites, b.sites),
    );
  }

  Block toBlock({DateTime? lockedUntil}) => Block(
        id: newId(),
        name: name,
        color: color,
        iconText: iconText,
        presetId: id,
        keywords: [...keywords],
        spoilerWords: [...spoilerWords],
        topicWords: [...topicWords],
        sites: [...sites],
        lock: lockedUntil == null ? LockKind.none : LockKind.untilDate,
        lockedUntil: lockedUntil,
        sentence: sentence,
      );
}

List<Preset> get presets => [
  Preset(
    id: 'gta6-spoilers',
    name: tr('GTA 6 spoilers', 'GTA 6 spoilerek'),
    description: tr('The game, its characters and places, and spoiler subreddits', 'A játék, a szereplői, a helyszínei és a spoileres subredditek'),
    iconText: 'VI',
    color: BlockColor.teal,
    sentence: tr('I really want to see GTA 6 spoilers right now', 'Most tényleg látni akarok GTA 6 spoilereket'),
    keywords: [
      // the game
      'GTA 6', 'GTA VI', 'Grand Theft Auto 6', 'Grand Theft Auto VI', 'Rockstar Games',
      // names/places
      'Lucia', 'Jason', 'Caminos', 'Duval', 'Leonida', 'Port Gellhorn', 'Ambrosia', 'Grassrivers', 'Mount Kalaga',
      'Cal Hampton', 'Boobie Ike', "Dre'Quan Priest", 'Real Dimez', 'Raul Bautista', 'Brian Heder',
    ],
    spoilerWords: [
      'prologue', 'intro', 'opening', 'ending', 'end', 'final mission', 'cutscene', 'death', 'dies',
      'baby', 'mom', 'leak', 'spoiler',
    ],
    topicWords: ['GTA', 'Rockstar', 'Vice City', 'Liberty City'],
    sites: [
      'reddit.com/r/GTA6', 'reddit.com/r/GTAVI', 'reddit.com/r/GTA', 'reddit.com/r/rockstar',
      'reddit.com/r/GamingLeaksAndRumours', 'gtaforums.com', 'gta.fandom.com', 'gtabase.com',
      'rockstarintel.com', 'rockstargames.com/VI', 'x.com/search?q=gta',
    ],
  ),
];
