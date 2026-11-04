import 'models.dart';

/// 内置种子数据：App 首次启动时写入 SQLite，实现单机离线可用。
class SeedData {
  SeedData._();

  /// 琴曲资料库
  static const List<GuqinPiece> pieces = [
    GuqinPiece(
      slug: 'liushui',
      title: '流水',
      dynasty: '先秦',
      author: '传 伯牙 / 《天闻阁琴谱》',
      mode: '正调',
      difficulty: '精研',
      durationSec: 493,
      intro: '写江流奔涌、洋洋浩荡之势，以「滚拂」摹水，气势磅礴。',
      background:
          '相传为春秋伯牙所作，与《高山》并称，「高山流水」遇知音之典即出于此。'
          '今传谱本出自清代张孔山《天闻阁琴谱》，第七段以「七十二滚拂」摹写流水奔湍，'
          '是琴曲中写水之绝唱。',
      tags: ['写景', '大曲', '滚拂'],
    ),
    GuqinPiece(
      slug: 'shenrenchang',
      title: '神人畅',
      dynasty: '明代',
      author: '《西麓堂琴统》',
      mode: '正调',
      difficulty: '进阶',
      durationSec: 305,
      intro: '写神人相和、天地同畅之象，音节古峭，气象高远。',
      background:
          '最早见于明代《西麓堂琴统》，取《琴操》所载「神人畅游」之意。'
          '全曲散、泛、按交替，音节古朴峭拔，为传世琴曲中较为古远的一支。',
      tags: ['古曲', '泛音'],
    ),
    GuqinPiece(
      slug: 'meihua',
      title: '梅花三弄',
      dynasty: '东晋',
      author: '桓伊（笛曲改编）',
      mode: '正调',
      difficulty: '进阶',
      durationSec: 39,
      intro: '以泛音三段反复「三弄」梅花，赞其傲雪凌霜之品格（试听为泛音段落）。',
      background:
          '原是东晋桓伊所作笛曲，后移植为琴曲。曲中同一主题以泛音在不同徽位出现三次，故名「三弄」，'
          '象征梅花在风雪中次第开放，是琴曲中借物咏志的代表。',
      tags: ['咏物', '泛音', '三弄'],
    ),
    GuqinPiece(
      slug: 'pingsha',
      title: '平沙落雁',
      dynasty: '明代',
      author: '《古音正宗》',
      mode: '正调',
      difficulty: '入门',
      durationSec: 434,
      intro: '写秋江平沙、雁群起落盘旋之景，从容疏朗，为入门首选。',
      background:
          '最早见于明末《古音正宗》（1634 年）。以「按、泛、散」交替描绘雁阵鸣落、'
          '忽起忽落之态，寄寓文人超脱旷达之怀，流传极广，版本众多。',
      tags: ['写景', '入门', '流行'],
    ),
    GuqinPiece(
      slug: 'yangguan',
      title: '阳关三叠',
      dynasty: '唐代',
      author: '王维 词 / 古曲',
      mode: '正调',
      difficulty: '入门',
      durationSec: 350,
      intro: '依王维《送元二使安西》谱曲，一唱三叹，最是离情。',
      background:
          '因诗中有「西出阳关无故人」句，且全曲叠唱三遍，故名《阳关三叠》。'
          '琴歌与器乐两体并行，是流传最广的送别主题琴曲。',
      tags: ['琴歌', '送别', '入门'],
    ),
    GuqinPiece(
      slug: 'peilan',
      title: '佩兰',
      dynasty: '南宋',
      author: '毛敏仲',
      mode: '正调',
      difficulty: '精研',
      durationSec: 490,
      intro: '借兰草自喻高洁，寄怀才不遇之慨，音节幽远，寄兴深长。',
      background:
          '南宋琴家毛敏仲所作。取《离骚》「纫秋兰以为佩」之意，以兰草自况，'
          '抒高洁自守、怀才不遇之志。全曲篇幅宏阔，按音绵密，是南宋浙派琴曲的代表。',
      tags: ['咏物', '抒情', '大曲'],
    ),
    GuqinPiece(
      slug: 'jiukuang',
      title: '酒狂',
      dynasty: '魏晋',
      author: '阮籍',
      mode: '正调',
      difficulty: '入门',
      durationSec: 155,
      intro: '以三拍子摇曳之态写醉者步履，寄竹林名士之孤愤。',
      background:
          '传为「竹林七贤」阮籍所作。乐曲以不稳定的节拍与反复的「仙人吐酒声」段落，'
          '刻画出醉酒佯狂、借酒避世的文人形象。',
      tags: ['抒情', '小品', '入门'],
    ),
    GuqinPiece(
      slug: 'kongziduyi',
      title: '孔子读易',
      dynasty: '清代',
      author: '《天闻阁琴谱》',
      mode: '正调',
      difficulty: '进阶',
      durationSec: 348,
      intro: '写孔子韦编三绝、读《易》不辍之勤，音节典雅，气度从容。',
      background:
          '写孔子晚年读《易》「韦编三绝」之典，谱本见于清代《天闻阁琴谱》。'
          '全曲以散音起调，按音婉转，摹圣人伏案研《易》、不知老之将至之境，'
          '于平淡中见深醇。',
      tags: ['典故', '抒情', '进阶'],
    ),
    GuqinPiece(
      slug: 'zuiyu',
      title: '醉渔唱晚',
      dynasty: '唐代',
      author: '传 陆龟蒙、皮日休',
      mode: '正调',
      difficulty: '进阶',
      durationSec: 287,
      intro: '写渔翁醉歌、笑傲烟云，节奏跌宕，意趣悠然。',
      background:
          '相传唐末陆龟蒙与皮日休泛舟松江，见渔父醉歌而归，遂作此曲。'
          '曲中「唱晚」段落以泼辣跌宕的节奏，写渔人放达不羁之态。',
      tags: ['写景', '跌宕'],
    ),
    GuqinPiece(
      slug: 'qiufengci',
      title: '秋风词',
      dynasty: '唐代',
      author: '李白 词 / 《梅庵琴谱》',
      mode: '正调',
      difficulty: '入门',
      durationSec: 106,
      intro: '依李白《秋风词》谱曲，短小婉转，写秋夜怀人之情。',
      background:
          '琴歌，词取李白《三五七言》「秋风清，秋月明」。'
          '全曲短小，曲调缠绵低回，是琴歌中流传最广的小品之一，最宜初学吟唱。',
      tags: ['琴歌', '怀人', '入门'],
    ),
  ];

  /// 古琴文化资料库
  static const List<CultureArticle> articles = [
    CultureArticle(
      slug: 'history-3000',
      category: '历史',
      title: '琴有三千年：从上古到当代',
      summary: '古琴是中国最早的弹弦乐器之一，三千年来始终与文人士大夫的精神世界相连。',
      content:
          '古琴，又称瑶琴、玉琴、七弦琴，是中国最古老的弹弦乐器之一，有文字可考的历史可上溯至三千年前的西周。\n\n'
          '《诗经》中「琴瑟友之」「琴瑟在御」的吟咏，说明先秦时琴已广泛用于祭祀、宴飨与日常生活。'
          '1978 年湖北曾侯乙墓出土的十弦琴，是现存最早的琴类实物之一。\n\n'
          '汉代琴的形制逐渐定型为七弦；魏晋名士以琴寄情，嵇康、阮籍皆为琴家；'
          '唐代减字谱出现，琴乐得以精确记录；宋代琴派渐成，明清琴谱刊印极盛。\n\n'
          '2003 年，古琴艺术被联合国教科文组织列入「人类口头和非物质遗产代表作」，'
          '2006 年列入中国第一批国家级非物质文化遗产名录。',
    ),
    CultureArticle(
      slug: 'structure',
      category: '形制',
      title: '七弦十三徽：一张琴的身体',
      summary: '琴身各部皆有专名，七弦分属宫商角徵羽，十三徽标示泛音节点。',
      content:
          '一张古琴长约三尺六寸五分（约 122 厘米），象征一年三百六十五天；'
          '面板取桐木或杉木，底板取梓木，中空为「槽腹」，是共鸣之本。\n\n'
          '琴身自头至尾依次为：岳山（架弦）、承露、轸池与七个琴轸（调弦）、'
          '七弦（原为五弦，周代增二弦）、十三个徽（音位标记，用螺钿或玉石镶嵌）、'
          '龙龈、雁足（系弦）、龙池与凤沼（两个出音孔）。\n\n'
          '七弦从外至内依次为宫、商、角、徵、羽与少宫、少商，'
          '通常定弦为 C-D-F-G-A-c-d，故又称「正调」。'
          '十三徽中，七徽居中，是泛音取音的关键节点，一至七徽与七至十三徽左右对称。',
    ),
    CultureArticle(
      slug: 'forms',
      category: '形制',
      title: '琴式之美：伏羲、仲尼与落霞',
      summary: '琴的颈部与腰部曲线不同，形成众多琴式，各具气韵。',
      content:
          '古琴的形制差异主要体现在项、腰的曲线与整体比例上，历代流传琴式逾五十种。\n\n'
          '· 伏羲式：相传始于伏羲，颈圆腰阔，古朴厚重，为最古之式。\n'
          '· 仲尼式：又称夫子式，线条简洁含蓄，为历代最流行之式。\n'
          '· 连珠式：项腰作连续弧形，如珠串相连，灵动秀雅。\n'
          '· 落霞式：又称凤势式，腰作波浪，如落霞铺水，极富动感。\n'
          '· 蕉叶式：仿芭蕉叶形，叶脉为边，最为奇巧。\n\n'
          '琴式不仅是造型之别，也影响音色的松透与共鸣，斫琴者往往因材定式。',
    ),
    CultureArticle(
      slug: 'schools',
      category: '琴派',
      title: '琴派源流：浙派、虞山与广陵',
      summary: '地域、师承与审美差异，孕育出风格各异的琴派。',
      content:
          '· 浙派：南宋郭沔（楚望）开创，以《潇湘水云》为代表，讲究气韵绵长、技法繁复。\n'
          '· 虞山派：明末严澂创于常熟，编《松弦馆琴谱》，主张「清微淡远」，'
          '反对滥加繁声，影响后世极深。\n'
          '· 广陵派：清代扬州一带，徐常遇、徐祺等承虞山之余绪，'
          '指法细腻，节奏跌宕，刚柔相济。\n'
          '· 川派：又称蜀派，张孔山《流水》加入「七十二滚拂」，'
          '以激流奔涌之声名动天下。\n'
          '· 梅庵派：近代山东王燕卿所创，旋律流畅、吟猱夸张，颇具民间气息。\n'
          '· 九嶷派：杨宗稷（时百）开派，注重指力与节拍，著《琴学丛书》。\n\n'
          '各派并非壁垒森严，清末以来交流日密，今日习琴者多融会诸家。',
    ),
    CultureArticle(
      slug: 'craft',
      category: '工艺',
      title: '斫琴：一张琴的百道工序',
      summary: '从选材到上弦，古琴制作需历经数年，讲究「九德」兼备。',
      content:
          '「斫」即砍削，斫琴是古琴制作的传统称谓，工序繁复，历时经年。\n\n'
          '一、选材：面板多用百年老杉或梧桐，底板用梓木，讲究纹理匀直、木性稳定。\n'
          '二、制形：依式样开料，挖凿槽腹，槽腹深浅决定音色的松透与空灵。\n'
          '三、裹布：以麻布、生漆包裹琴身，防裂并增共鸣。\n'
          '四、灰胎：刮鹿角霜灰，由粗至细反复多道，是声音醇厚的关键。\n'
          '五、髹漆：以生漆髹涂，打磨推光，历数月而成，琴面温润如玉。\n'
          '六、上弦：系弦于雁足，缠于琴轸，反复调校音准。\n\n'
          '古人以「奇、古、透、静、润、圆、清、匀、芳」为琴之九德，'
          '音色松透、苍古、无煞音者，方为上品。',
    ),
    CultureArticle(
      slug: 'spirit',
      category: '琴道',
      title: '琴者禁也：琴与文人精神',
      summary: '琴不仅是乐器，更是修身养性、寄托怀抱的「道器」。',
      content:
          '《白虎通》云：「琴者，禁也，所以禁止淫邪，正人心也。」'
          '在古代文人的观念中，弹琴首先是修心，其次才是取乐。\n\n'
          '琴位列「琴棋书画」四艺之首，是文人必备的修养。'
          '陶渊明「但识琴中趣，何劳弦上声」，苏轼「琴声在指不在弦」，'
          '皆道出琴超越技巧的精神追求。\n\n'
          '古人弹琴讲究「五不弹」：疾风甚雨不弹、尘市不弹、对俗子不弹、'
          '不坐不弹、不衣冠不弹。焚香、净手、正坐，皆是敬琴、静心之仪。\n\n'
          '琴音「清微淡远」，不取悦于人，故最难在知音。'
          '今日习琴，既是学一门技艺，也是接续一份沉静的生活态度。',
    ),
    CultureArticle(
      slug: 'notation',
      category: '历史',
      title: '减字谱：把琴声写成字',
      summary: '唐代出现的减字谱，以笔画拼合记录指法，是古琴独有的记谱法。',
      content:
          '减字谱由唐代曹柔初创，至宋代定型。它不记音高与节奏，'
          '而专记「哪只手、哪个手指、按第几徽、弹第几弦」，'
          '故又称「指法谱」。\n\n'
          '其法是取汉字的偏旁笔画，拼合成一个新的「减字」。'
          '如「大九勾一」：上左「大」为大指，上右「九」为九徽，'
          '下左「勾」为中指向内弹，下右「一」为第一弦。\n\n'
          '因为只记指法，琴家需依师承口传心授，或参照旁注才能还原本曲，'
          '这既造成了流派的多样，也使得同一乐曲有多种「打谱」版本。\n\n'
          '近代琴家借鉴西方乐理，创制「五线谱 + 减字谱」或「简谱 + 减字谱」'
          '的双行谱式，使古琴教学更为便利。',
    ),
    CultureArticle(
      slug: 'timbre',
      category: '琴道',
      title: '三种音色：散、按、泛',
      summary: '古琴音色分散音、按音、泛音三类，合称「三籁」，各具性情。',
      content:
          '散音：左手不按弦，右手弹弦，全弦振动。音色浑厚宽广，如钟磬之声，'
          '象征「地声」。\n\n'
          '按音：左手按弦于徽位之上，右手弹弦，改变有效弦长而发声。'
          '音色温润近人，可作吟猱绰注之变化，最能传情，象征「人声」。\n\n'
          '泛音：左手轻触徽位而不压弦，右手弹弦，取其分段振动的谐波。'
          '音色空灵清越，如珠落玉盘，象征「天声」。十三徽皆可取泛音。\n\n'
          '散、按、泛三音交相运用，一琴之内可得天地人三籁，'
          '这是古琴有别于其他乐器的重要特质。',
    ),
  ];

  /// 指法动画教学数据
  static const List<Fingering> fingerings = [
    Fingering(
      name: '散音',
      pinyin: 'sàn yīn',
      category: '基本音色',
      desc: '左手不触弦，右手弹弦取全弦振动之声，浑厚如钟。',
      tip: '沉肩坠肘，弹弦用力在指根而非手臂，出音要饱满而不燥。',
      motion: 'pluck_down',
    ),
    Fingering(
      name: '泛音',
      pinyin: 'fàn yīn',
      category: '基本音色',
      desc: '左手轻点徽位（不压弦），右手同时弹弦，得空灵清越之声。',
      tip: '左指「点」要准在徽心，右指弹出后左指立起，如蜻蜓点水。',
      motion: 'harmonic',
    ),
    Fingering(
      name: '按音',
      pinyin: 'àn yīn',
      category: '基本音色',
      desc: '左手按弦于徽位，右手弹弦，音色温润，可作吟猱变化。',
      tip: '按弦要到木而不死，走弦时以腕带指，力透指尖。',
      motion: 'press',
    ),
    Fingering(
      name: '擘',
      pinyin: 'bāi',
      category: '右手指法',
      desc: '大指向外拨弦。',
      tip: '以大指指肉侧锋向外弹出，忌用指甲硬刮。',
      motion: 'pluck_up',
    ),
    Fingering(
      name: '托',
      pinyin: 'tuō',
      category: '右手指法',
      desc: '大指向内弹弦。',
      tip: '大指微屈，指腹向外弹入，与「擘」为一对。',
      motion: 'pluck_down',
    ),
    Fingering(
      name: '抹',
      pinyin: 'mǒ',
      category: '右手指法',
      desc: '食指向内弹弦。',
      tip: '食指轻搭弦上，向内斜下弹出，出音清亮。',
      motion: 'pluck_down',
    ),
    Fingering(
      name: '挑',
      pinyin: 'tiāo',
      category: '右手指法',
      desc: '食指向外弹弦。',
      tip: '以拇指抵食指根节发力，向外斜上挑出。',
      motion: 'pluck_up',
    ),
    Fingering(
      name: '勾',
      pinyin: 'gōu',
      category: '右手指法',
      desc: '中指向内弹弦。',
      tip: '中指自然弯曲，向内勾弹，为最常用之势。',
      motion: 'pluck_down',
    ),
    Fingering(
      name: '剔',
      pinyin: 'tī',
      category: '右手指法',
      desc: '中指向外弹弦。',
      tip: '中指微伸直，向外剔出，与「勾」为一对。',
      motion: 'pluck_up',
    ),
    Fingering(
      name: '打',
      pinyin: 'dǎ',
      category: '右手指法',
      desc: '无名指向内弹弦。',
      tip: '无名指力弱，宜借腕力补助，出音干净。',
      motion: 'pluck_down',
    ),
    Fingering(
      name: '摘',
      pinyin: 'zhāi',
      category: '右手指法',
      desc: '无名指向外弹弦。',
      tip: '与「打」为一对，常用于快速交替的段落。',
      motion: 'pluck_up',
    ),
    Fingering(
      name: '吟',
      pinyin: 'yín',
      category: '左手指法',
      desc: '按弦后横向小幅往复摇动，令音微微波动，如人之吟咏。',
      tip: '以腕带动，幅度小而匀，忌用指节硬压。',
      motion: 'slide',
    ),
    Fingering(
      name: '猱',
      pinyin: 'náo',
      category: '左手指法',
      desc: '按弦后上下（或斜向）较大幅度摇动，音波深而缓。',
      tip: '「吟」细而密，「猱」大而缓，二者常连用。',
      motion: 'slide',
    ),
    Fingering(
      name: '绰',
      pinyin: 'chuò',
      category: '左手指法',
      desc: '自下徽位上游至本位，由低而就高。',
      tip: '上音轻，落点准，「绰」取其滑入之势。',
      motion: 'slide_up',
    ),
    Fingering(
      name: '注',
      pinyin: 'zhù',
      category: '左手指法',
      desc: '自上徽位下游至本位，由高而就低。',
      tip: '与「绰」反向，气息连贯，切忌忽断。',
      motion: 'slide_down',
    ),
  ];

  /// 减字谱学习：入门常用减字（四要素拆解）。
  static const List<NotationSymbol> symbols = [
    NotationSymbol(
      leftHand: '大',
      hui: '九',
      rightHand: '勾',
      stringNum: '一',
      reading: '大九勾一',
      meaning: '左大指按第一弦九徽，右中指勾入第一弦。属按音，音色温润。',
    ),
    NotationSymbol(
      leftHand: '食',
      hui: '七',
      rightHand: '挑',
      stringNum: '二',
      reading: '食七挑二',
      meaning: '左食指按第二弦七徽，右食指挑出第二弦。七徽居中，取音常用。',
    ),
    NotationSymbol(
      leftHand: '中',
      leftTech: '吟',
      hui: '十',
      rightHand: '勾',
      stringNum: '三',
      reading: '中十吟勾三',
      meaning: '左中指按第三弦十徽并加「吟」法（微颤），右中指勾入第三弦。',
    ),
    NotationSymbol(
      leftHand: '名',
      leftTech: '绰',
      hui: '十',
      rightHand: '抹',
      stringNum: '四',
      reading: '名十绰抹四',
      meaning: '左无名指自低位滑向第四弦十徽（绰），右食指抹入第四弦。',
    ),
    NotationSymbol(
      leftHand: '大',
      hui: '七',
      rightHand: '挑',
      stringNum: '五',
      reading: '大七挑五',
      meaning: '左大指按第五弦七徽，右食指挑出第五弦。',
    ),
    NotationSymbol(
      leftHand: '食',
      hui: '七',
      rightHand: '剔',
      stringNum: '六',
      reading: '食七剔六',
      meaning: '左食指按第六弦七徽，右中指剔出第六弦。',
    ),
    NotationSymbol(
      leftHand: '中',
      hui: '九',
      rightHand: '勾',
      stringNum: '七',
      reading: '中九勾七',
      meaning: '左中指按第七弦九徽，右中指勾入第七弦，为常用低音区。',
    ),
    NotationSymbol(
      leftHand: '大',
      hui: '十',
      rightHand: '打',
      stringNum: '一',
      reading: '大十打一',
      meaning: '左大指按第一弦十徽，右无名指向内打入第一弦。',
    ),
  ];
}
