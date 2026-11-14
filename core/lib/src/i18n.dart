/// en/hu, strings inline: `tr('Blocks', 'Tiltások')`
enum Lang { en, hu }

Lang currentLang = Lang.en;

bool get isHu => currentLang == Lang.hu;

String tr(String en, String hu) => currentLang == Lang.hu ? hu : en;

Lang langForLocale(String locale) => locale.toLowerCase().startsWith('hu') ? Lang.hu : Lang.en;
